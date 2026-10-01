import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nexecute/services/app_platform_services.dart';
import 'package:nexecute/services/auth.dart';

const googleCalendarReadScopes = <String>[
  'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  'https://www.googleapis.com/auth/calendar.events.readonly',
];

enum GoogleCalendarAuthorizationStatus {
  disconnected,
  checking,
  authorizing,
  connected,
  expired,
  denied,
  unsupported,
  failed,
}

enum GoogleCalendarAuthorizationIssue {
  nexecuteUserMissing,
  nexecuteAccountIsNotGoogle,
  accountMismatch,
  scopesDenied,
  accessTokenUnavailable,
  providerUnavailable,
  unsupported,
}

final class GoogleCalendarAccountIdentity {
  const GoogleCalendarAccountIdentity({required this.id, required this.email});

  final String id;
  final String email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoogleCalendarAccountIdentity &&
          other.id == id &&
          other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

final class GoogleCalendarAuthorizationState {
  const GoogleCalendarAuthorizationState({
    required this.status,
    this.account,
    this.issue,
  });

  static const disconnected = GoogleCalendarAuthorizationState(
    status: GoogleCalendarAuthorizationStatus.disconnected,
  );

  static const unsupported = GoogleCalendarAuthorizationState(
    status: GoogleCalendarAuthorizationStatus.unsupported,
    issue: GoogleCalendarAuthorizationIssue.unsupported,
  );

  final GoogleCalendarAuthorizationStatus status;
  final GoogleCalendarAccountIdentity? account;
  final GoogleCalendarAuthorizationIssue? issue;
}

final class GoogleCalendarAuthorizationException implements Exception {
  const GoogleCalendarAuthorizationException(this.issue);

  final GoogleCalendarAuthorizationIssue issue;

  @override
  String toString() => 'Google Calendar authorization failed: ${issue.name}';
}

final class GoogleCalendarAccessToken {
  const GoogleCalendarAccessToken._(this.value, this._authorizationId);

  final String value;
  final int _authorizationId;

  @override
  String toString() => 'GoogleCalendarAccessToken(<redacted>)';
}

final class GoogleCalendarCacheOwner {
  const GoogleCalendarCacheOwner({
    required this.nexecuteUserId,
    required this.googleAccountId,
  });

  final String nexecuteUserId;
  final String googleAccountId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoogleCalendarCacheOwner &&
          other.nexecuteUserId == nexecuteUserId &&
          other.googleAccountId == googleAccountId;

  @override
  int get hashCode => Object.hash(nexecuteUserId, googleAccountId);
}

abstract interface class GoogleCalendarCacheLifecycle {
  Future<void> clearForAccount(GoogleCalendarCacheOwner owner);
}

final class NoopGoogleCalendarCacheLifecycle
    implements GoogleCalendarCacheLifecycle {
  const NoopGoogleCalendarCacheLifecycle();

  @override
  Future<void> clearForAccount(GoogleCalendarCacheOwner owner) async {}
}

abstract interface class GoogleCalendarAuthClient {
  GoogleCalendarAccountIdentity? get currentAccount;

  Stream<GoogleCalendarAccountIdentity?> get accountChanges;

  Future<GoogleCalendarAccountIdentity?> signInSilently();

  Future<GoogleCalendarAccountIdentity?> signIn();

  Future<bool> requestScopes(List<String> scopes);

  Future<String?> accessToken();

  Future<void> clearAuthCache();

  Future<void> signOut();
}

final class DefaultGoogleCalendarAuthClient
    implements GoogleCalendarAuthClient {
  DefaultGoogleCalendarAuthClient(this._googleSignIn);

  final GoogleSignIn _googleSignIn;

  @override
  GoogleCalendarAccountIdentity? get currentAccount =>
      _identity(_googleSignIn.currentUser);

  @override
  Stream<GoogleCalendarAccountIdentity?> get accountChanges =>
      _googleSignIn.onCurrentUserChanged.map(_identity);

  @override
  Future<GoogleCalendarAccountIdentity?> signInSilently() async => _identity(
    await _googleSignIn.signInSilently(
      suppressErrors: false,
      reAuthenticate: true,
    ),
  );

  @override
  Future<GoogleCalendarAccountIdentity?> signIn() async =>
      _identity(await _googleSignIn.signIn());

  @override
  Future<bool> requestScopes(List<String> scopes) =>
      _googleSignIn.requestScopes(scopes);

  @override
  Future<String?> accessToken() async =>
      (await _currentUser().authentication).accessToken;

  @override
  Future<void> clearAuthCache() => _currentUser().clearAuthCache();

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  GoogleSignInAccount _currentUser() {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    }
    return account;
  }

  static GoogleCalendarAccountIdentity? _identity(
    GoogleSignInAccount? account,
  ) =>
      account == null
          ? null
          : GoogleCalendarAccountIdentity(id: account.id, email: account.email);
}

abstract interface class GoogleCalendarAuthorizationService {
  GoogleCalendarAuthorizationState get state;

  Stream<GoogleCalendarAuthorizationState> get states;

  Future<void> connect();

  Future<GoogleCalendarAccessToken> accessToken();

  Future<GoogleCalendarAccessToken> refreshAccessTokenAfterUnauthorized(
    GoogleCalendarAccessToken rejectedToken,
  );

  Future<void> markAuthorizationExpired(
    GoogleCalendarAccessToken rejectedToken,
  );

  Future<void> disconnect();

  Future<void> dispose();
}

final class GoogleCalendarAuthorization
    implements GoogleCalendarAuthorizationService {
  GoogleCalendarAuthorization({
    required AuthService authService,
    required GoogleCalendarAuthClient client,
    GoogleCalendarCacheLifecycle cacheLifecycle =
        const NoopGoogleCalendarCacheLifecycle(),
  }) : _authService = authService,
       _client = client,
       _cacheLifecycle = cacheLifecycle {
    _authSubscription = _authService.identityStream.listen(
      (user) => unawaited(_handleFirebaseUserChanged(user)),
      onError: (_) => unawaited(_clearConnection(signOutProvider: false)),
    );
    _googleSubscription = _client.accountChanges.listen(
      (account) => unawaited(_handleGoogleAccountChanged(account)),
      onError: (_) => unawaited(_clearConnection(signOutProvider: false)),
    );
  }

  final AuthService _authService;
  final GoogleCalendarAuthClient _client;
  final GoogleCalendarCacheLifecycle _cacheLifecycle;
  final _stateController =
      StreamController<GoogleCalendarAuthorizationState>.broadcast(sync: true);

  late final StreamSubscription<User?> _authSubscription;
  late final StreamSubscription<GoogleCalendarAccountIdentity?>
  _googleSubscription;
  GoogleCalendarAuthorizationState _state =
      GoogleCalendarAuthorizationState.disconnected;
  GoogleCalendarCacheOwner? _cacheOwner;
  Future<void>? _connectOperation;
  Future<void>? _clearOperation;
  _FirebaseGoogleIdentity? _pendingFirebaseIdentity;
  int? _pendingGeneration;
  bool _clearShouldSignOut = false;
  int _generation = 0;
  int? _authorizationId;
  bool _hasAttemptedRecovery = false;
  bool _disposed = false;

  @override
  GoogleCalendarAuthorizationState get state => _state;

  @override
  Stream<GoogleCalendarAuthorizationState> get states =>
      _stateController.stream;

  @override
  Future<void> connect() {
    if (_disposed) return Future.error(StateError('Service is disposed'));
    final active = _connectOperation;
    if (active != null) return active;

    final generation = ++_generation;
    late final Future<void> operation;
    operation = _connectAfterCleanup(generation).whenComplete(() {
      if (identical(_connectOperation, operation)) _connectOperation = null;
    });
    _connectOperation = operation;
    return operation;
  }

  Future<void> _connectAfterCleanup(int generation) async {
    final cleanup = _clearOperation;
    if (cleanup != null) await cleanup;
    _ensureActive();
    if (!_isCurrent(generation)) return;
    await _connect(generation);
  }

  Future<void> _connect(int generation) async {
    _emitIfCurrent(
      generation,
      const GoogleCalendarAuthorizationState(
        status: GoogleCalendarAuthorizationStatus.checking,
      ),
    );
    final firebaseIdentity = _firebaseIdentity(_authService.user);
    if (firebaseIdentity == null || !_isCurrent(generation)) return;
    _pendingFirebaseIdentity = firebaseIdentity;
    _pendingGeneration = generation;

    try {
      var account = _client.currentAccount;
      account ??= await _client.signInSilently();
      if (!_isCurrent(generation)) return;
      account ??= await _client.signIn();
      if (!_isCurrent(generation)) return;
      if (account == null) {
        _emitIfCurrent(
          generation,
          GoogleCalendarAuthorizationState.disconnected,
        );
        return;
      }
      if (account.id != firebaseIdentity.googleAccountId) {
        await _clearProviderSession();
        if (!_isCurrent(generation)) return;
        _emitIfCurrent(
          generation,
          const GoogleCalendarAuthorizationState(
            status: GoogleCalendarAuthorizationStatus.denied,
            issue: GoogleCalendarAuthorizationIssue.accountMismatch,
          ),
        );
        return;
      }
      if (!_connectionInputsMatch(firebaseIdentity, account)) {
        await _denyMismatchedConnection(generation);
        return;
      }

      _emitIfCurrent(
        generation,
        GoogleCalendarAuthorizationState(
          status: GoogleCalendarAuthorizationStatus.authorizing,
          account: account,
        ),
      );
      if (!await _client.requestScopes(googleCalendarReadScopes)) {
        if (!_isCurrent(generation)) return;
        _emitIfCurrent(
          generation,
          GoogleCalendarAuthorizationState(
            status: GoogleCalendarAuthorizationStatus.denied,
            account: account,
            issue: GoogleCalendarAuthorizationIssue.scopesDenied,
          ),
        );
        return;
      }
      if (!_connectionInputsMatch(firebaseIdentity, account)) {
        await _denyMismatchedConnection(generation);
        return;
      }
      final token = await _client.accessToken();
      if (!_isCurrent(generation) ||
          !_connectionInputsMatch(firebaseIdentity, account)) {
        await _denyMismatchedConnection(generation);
        return;
      }
      if (!_isUsableToken(token)) {
        _emitIfCurrent(
          generation,
          GoogleCalendarAuthorizationState(
            status: GoogleCalendarAuthorizationStatus.expired,
            account: account,
            issue: GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
          ),
        );
        return;
      }
      if (!_stillMatches(firebaseIdentity, account)) {
        await _clearProviderSession();
        if (!_isCurrent(generation)) return;
        _emitIfCurrent(
          generation,
          const GoogleCalendarAuthorizationState(
            status: GoogleCalendarAuthorizationStatus.denied,
            issue: GoogleCalendarAuthorizationIssue.accountMismatch,
          ),
        );
        return;
      }

      _cacheOwner = GoogleCalendarCacheOwner(
        nexecuteUserId: firebaseIdentity.nexecuteUserId,
        googleAccountId: account.id,
      );
      _authorizationId = generation;
      _hasAttemptedRecovery = false;
      _emitIfCurrent(
        generation,
        GoogleCalendarAuthorizationState(
          status: GoogleCalendarAuthorizationStatus.connected,
          account: account,
        ),
      );
    } catch (_) {
      _emitIfCurrent(
        generation,
        const GoogleCalendarAuthorizationState(
          status: GoogleCalendarAuthorizationStatus.failed,
          issue: GoogleCalendarAuthorizationIssue.providerUnavailable,
        ),
      );
    } finally {
      if (_pendingGeneration == generation) {
        _pendingFirebaseIdentity = null;
        _pendingGeneration = null;
      }
    }
  }

  @override
  Future<GoogleCalendarAccessToken> accessToken() async {
    _ensureActive();
    final account = _requireConnectedAccount();
    final owner = _requireCacheOwner();
    final authorizationId = _requireAuthorizationId();
    if (!_authorizationIsCurrent(authorizationId, owner, account)) {
      await _clearConnection(signOutProvider: false);
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accountMismatch,
      );
    }
    try {
      final token = await _client.accessToken();
      if (!_authorizationIsCurrent(authorizationId, owner, account)) {
        if (_generation == authorizationId &&
            _authorizationId == authorizationId) {
          await _clearConnection(signOutProvider: false);
        }
        throw const GoogleCalendarAuthorizationException(
          GoogleCalendarAuthorizationIssue.accountMismatch,
        );
      }
      if (_isUsableToken(token)) {
        return GoogleCalendarAccessToken._(token!, authorizationId);
      }
      await _expireAuthorization(authorizationId, account);
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    } on GoogleCalendarAuthorizationException {
      rethrow;
    } catch (_) {
      if (_authorizationIsCurrent(authorizationId, owner, account)) {
        _emit(
          GoogleCalendarAuthorizationState(
            status: GoogleCalendarAuthorizationStatus.failed,
            account: account,
            issue: GoogleCalendarAuthorizationIssue.providerUnavailable,
          ),
        );
      }
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.providerUnavailable,
      );
    }
  }

  @override
  Future<GoogleCalendarAccessToken> refreshAccessTokenAfterUnauthorized(
    GoogleCalendarAccessToken rejectedToken,
  ) async {
    _ensureActive();
    final account = _requireConnectedAccount();
    final owner = _requireCacheOwner();
    final authorizationId = _requireAuthorizationId();
    if (rejectedToken._authorizationId != authorizationId ||
        !_authorizationIsCurrent(authorizationId, owner, account)) {
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    }
    if (_hasAttemptedRecovery) {
      await _expireAuthorization(authorizationId, account);
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    }
    _hasAttemptedRecovery = true;
    try {
      await _client.clearAuthCache();
      if (!_authorizationIsCurrent(authorizationId, owner, account)) {
        throw const GoogleCalendarAuthorizationException(
          GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
        );
      }
      final token = await _client.accessToken();
      if (_authorizationIsCurrent(authorizationId, owner, account) &&
          _isUsableToken(token)) {
        return GoogleCalendarAccessToken._(token!, authorizationId);
      }
    } catch (_) {
      // Expiration below is intentionally provider-neutral and token-free.
    }
    await _expireAuthorization(authorizationId, account);
    throw const GoogleCalendarAuthorizationException(
      GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
    );
  }

  @override
  Future<void> markAuthorizationExpired(
    GoogleCalendarAccessToken rejectedToken,
  ) => _expireAuthorization(rejectedToken._authorizationId, _state.account);

  @override
  Future<void> disconnect() {
    _ensureActive();
    return _clearConnection(signOutProvider: true);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _connectOperation = null;
    await _authSubscription.cancel();
    await _googleSubscription.cancel();
    await _clearOperation;
    final owner = _cacheOwner;
    _cacheOwner = null;
    _authorizationId = null;
    if (owner != null) {
      try {
        await _cacheLifecycle.clearForAccount(owner);
      } catch (_) {
        // Disposal remains safe when optional cache cleanup fails.
      }
    }
    _state = GoogleCalendarAuthorizationState.disconnected;
    await _stateController.close();
  }

  Future<void> _handleFirebaseUserChanged(User? user) async {
    final pendingIdentity = _pendingFirebaseIdentity;
    if (pendingIdentity != null) {
      final identity = _firebaseIdentity(user, emitFailure: false);
      if (identity != pendingIdentity) {
        await _clearConnection(signOutProvider: false);
      }
      return;
    }
    if (_state.status != GoogleCalendarAuthorizationStatus.connected &&
        _cacheOwner == null) {
      return;
    }
    final identity = _firebaseIdentity(user, emitFailure: false);
    final owner = _cacheOwner;
    if (identity == null ||
        owner == null ||
        identity.nexecuteUserId != owner.nexecuteUserId ||
        identity.googleAccountId != owner.googleAccountId) {
      await _clearConnection(signOutProvider: false);
    }
  }

  Future<void> _handleGoogleAccountChanged(
    GoogleCalendarAccountIdentity? account,
  ) async {
    final pendingIdentity = _pendingFirebaseIdentity;
    if (pendingIdentity != null &&
        account != null &&
        account.id != pendingIdentity.googleAccountId) {
      await _clearConnection(signOutProvider: false);
      return;
    }
    final owner = _cacheOwner;
    if (owner == null ||
        (account != null && account.id == owner.googleAccountId)) {
      return;
    }
    await _clearConnection(signOutProvider: false);
  }

  Future<void> _clearConnection({required bool signOutProvider}) async {
    _generation += 1;
    _connectOperation = null;
    _pendingFirebaseIdentity = null;
    _pendingGeneration = null;
    _clearShouldSignOut = _clearShouldSignOut || signOutProvider;
    final active = _clearOperation;
    if (active != null) return active;

    late final Future<void> operation;
    operation = _performClearConnection().whenComplete(() {
      if (identical(_clearOperation, operation)) _clearOperation = null;
    });
    _clearOperation = operation;
    return operation;
  }

  Future<void> _performClearConnection() async {
    final owner = _cacheOwner;
    _cacheOwner = null;
    _authorizationId = null;
    _hasAttemptedRecovery = false;
    _emit(GoogleCalendarAuthorizationState.disconnected);
    if (owner != null) {
      try {
        await _cacheLifecycle.clearForAccount(owner);
      } catch (_) {
        // Cache cleanup cannot block account isolation or application use.
      }
    }
    if (_clearShouldSignOut) await _clearProviderSession();
    _clearShouldSignOut = false;
  }

  Future<void> _clearProviderSession() async {
    try {
      await _client.signOut();
    } catch (_) {
      // Local authorization state remains disconnected if the session is stale.
    }
  }

  _FirebaseGoogleIdentity? _firebaseIdentity(
    User? user, {
    bool emitFailure = true,
  }) {
    if (user == null) {
      if (emitFailure) {
        _emit(
          const GoogleCalendarAuthorizationState(
            status: GoogleCalendarAuthorizationStatus.denied,
            issue: GoogleCalendarAuthorizationIssue.nexecuteUserMissing,
          ),
        );
      }
      return null;
    }
    for (final provider in user.providerData) {
      final providerUid = provider.uid;
      if (provider.providerId == GoogleAuthProvider.PROVIDER_ID &&
          providerUid != null &&
          providerUid.isNotEmpty) {
        return _FirebaseGoogleIdentity(
          nexecuteUserId: user.uid,
          googleAccountId: providerUid,
        );
      }
    }
    if (emitFailure) {
      _emit(
        const GoogleCalendarAuthorizationState(
          status: GoogleCalendarAuthorizationStatus.denied,
          issue: GoogleCalendarAuthorizationIssue.nexecuteAccountIsNotGoogle,
        ),
      );
    }
    return null;
  }

  bool _stillMatches(
    _FirebaseGoogleIdentity expected,
    GoogleCalendarAccountIdentity account,
  ) {
    final current = _firebaseIdentity(_authService.user, emitFailure: false);
    final currentProviderAccount = _client.currentAccount;
    return current != null &&
        current == expected &&
        current.googleAccountId == account.id &&
        currentProviderAccount?.id == account.id;
  }

  bool _connectionInputsMatch(
    _FirebaseGoogleIdentity expected,
    GoogleCalendarAccountIdentity account,
  ) => _stillMatches(expected, account);

  bool _authorizationIsCurrent(
    int authorizationId,
    GoogleCalendarCacheOwner owner,
    GoogleCalendarAccountIdentity account,
  ) {
    final current = _firebaseIdentity(_authService.user, emitFailure: false);
    return !_disposed &&
        _generation == authorizationId &&
        _authorizationId == authorizationId &&
        _cacheOwner == owner &&
        _state.status == GoogleCalendarAuthorizationStatus.connected &&
        _state.account == account &&
        current?.nexecuteUserId == owner.nexecuteUserId &&
        current?.googleAccountId == owner.googleAccountId &&
        _client.currentAccount?.id == owner.googleAccountId;
  }

  Future<void> _denyMismatchedConnection(int generation) async {
    if (!_isCurrent(generation)) return;
    await _clearProviderSession();
    _emitIfCurrent(
      generation,
      const GoogleCalendarAuthorizationState(
        status: GoogleCalendarAuthorizationStatus.denied,
        issue: GoogleCalendarAuthorizationIssue.accountMismatch,
      ),
    );
  }

  Future<void> _expireAuthorization(
    int authorizationId,
    GoogleCalendarAccountIdentity? account,
  ) async {
    if (_disposed ||
        _authorizationId != authorizationId ||
        _generation != authorizationId) {
      return;
    }
    _emit(
      GoogleCalendarAuthorizationState(
        status: GoogleCalendarAuthorizationStatus.expired,
        account: account,
        issue: GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      ),
    );
  }

  bool _isCurrent(int generation) => !_disposed && _generation == generation;

  void _emitIfCurrent(int generation, GoogleCalendarAuthorizationState state) {
    if (_isCurrent(generation)) _emit(state);
  }

  void _ensureActive() {
    if (_disposed) throw StateError('Service is disposed');
  }

  GoogleCalendarAccountIdentity _requireConnectedAccount() {
    final account = _state.account;
    if (_state.status != GoogleCalendarAuthorizationStatus.connected ||
        account == null) {
      throw GoogleCalendarAuthorizationException(
        _state.issue ?? GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    }
    return account;
  }

  GoogleCalendarCacheOwner _requireCacheOwner() {
    final owner = _cacheOwner;
    if (owner == null) {
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    }
    return owner;
  }

  int _requireAuthorizationId() {
    final authorizationId = _authorizationId;
    if (authorizationId == null) {
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    }
    return authorizationId;
  }

  bool _isUsableToken(String? token) =>
      token != null && token.trim().isNotEmpty;

  void _emit(GoogleCalendarAuthorizationState state) {
    if (_disposed) return;
    _state = state;
    _stateController.add(state);
  }
}

final class UnsupportedGoogleCalendarAuthorization
    implements GoogleCalendarAuthorizationService {
  const UnsupportedGoogleCalendarAuthorization();

  @override
  GoogleCalendarAuthorizationState get state =>
      GoogleCalendarAuthorizationState.unsupported;

  @override
  Stream<GoogleCalendarAuthorizationState> get states =>
      Stream.value(GoogleCalendarAuthorizationState.unsupported);

  @override
  Future<void> connect() async {}

  @override
  Future<GoogleCalendarAccessToken> accessToken() => Future.error(
    const GoogleCalendarAuthorizationException(
      GoogleCalendarAuthorizationIssue.unsupported,
    ),
  );

  @override
  Future<GoogleCalendarAccessToken> refreshAccessTokenAfterUnauthorized(
    GoogleCalendarAccessToken rejectedToken,
  ) => Future.error(
    const GoogleCalendarAuthorizationException(
      GoogleCalendarAuthorizationIssue.unsupported,
    ),
  );

  @override
  Future<void> markAuthorizationExpired(
    GoogleCalendarAccessToken rejectedToken,
  ) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}

GoogleCalendarAuthorizationService createGoogleCalendarAuthorizationService({
  required AppRuntimePlatform platform,
  required AuthService authService,
  required GoogleCalendarAuthClient client,
  GoogleCalendarCacheLifecycle cacheLifecycle =
      const NoopGoogleCalendarCacheLifecycle(),
}) {
  return switch (platform) {
    AppRuntimePlatform.android ||
    AppRuntimePlatform.macOS => GoogleCalendarAuthorization(
      authService: authService,
      client: client,
      cacheLifecycle: cacheLifecycle,
    ),
    AppRuntimePlatform.web || AppRuntimePlatform.unsupported =>
      const UnsupportedGoogleCalendarAuthorization(),
  };
}

final class _FirebaseGoogleIdentity {
  const _FirebaseGoogleIdentity({
    required this.nexecuteUserId,
    required this.googleAccountId,
  });

  final String nexecuteUserId;
  final String googleAccountId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FirebaseGoogleIdentity &&
          other.nexecuteUserId == nexecuteUserId &&
          other.googleAccountId == googleAccountId;

  @override
  int get hashCode => Object.hash(nexecuteUserId, googleAccountId);
}
