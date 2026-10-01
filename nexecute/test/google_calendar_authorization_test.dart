import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/services/app_platform_services.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';

import 'support/fake_auth_clients.dart';
import 'support/fake_google_calendar_auth_client.dart';

void main() {
  const googleId = 'stable-google-provider-uid';
  const account = GoogleCalendarAccountIdentity(
    id: googleId,
    email: 'provider@example.com',
  );

  late StreamController<User?> firebaseUsers;
  late FakeFirebaseAuthClient firebase;
  late FakeGoogleAuthClient loginGoogle;
  late AuthService auth;
  late FakeGoogleCalendarAuthClient provider;
  late FakeGoogleCalendarCacheLifecycle cache;
  late GoogleCalendarAuthorization service;

  FakeUser googleUser({
    String uid = 'firebase-uid-not-google-id',
    String email = 'firebase@example.com',
    String providerUid = googleId,
  }) => FakeUser(
    uid: uid,
    email: email,
    providerData: [
      FakeUserInfo(
        uid: providerUid,
        providerId: GoogleAuthProvider.PROVIDER_ID,
        email: email,
      ),
    ],
  );

  Future<void> connect() async {
    firebase.currentUserValue = googleUser();
    provider.silentResult = account;
    await service.connect();
  }

  setUp(() {
    firebaseUsers = StreamController<User?>.broadcast(sync: true);
    firebase =
        FakeFirebaseAuthClient()..authenticationStream = firebaseUsers.stream;
    loginGoogle = FakeGoogleAuthClient();
    auth = AuthService(
      firebaseAuthClient: firebase,
      googleAuthClient: loginGoogle,
    );
    provider = FakeGoogleCalendarAuthClient();
    cache = FakeGoogleCalendarCacheLifecycle();
    service = GoogleCalendarAuthorization(
      authService: auth,
      client: provider,
      cacheLifecycle: cache,
    );
  });

  tearDown(() async {
    await service.dispose();
    await firebaseUsers.close();
    await provider.close();
  });

  test('does not call the provider during startup', () {
    expect(provider.currentAccountReadCount, 0);
    expect(provider.silentSignInCount, 0);
    expect(provider.interactiveSignInCount, 0);
    expect(provider.requestScopesCount, 0);
    expect(provider.accessTokenCount, 0);
    expect(provider.signOutCount, 0);
    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
  });

  test(
    'matches the stable Google provider uid, not Firebase uid or email',
    () async {
      firebase.currentUserValue = googleUser(
        uid: 'different-firebase-uid',
        email: 'different-firebase-email@example.com',
      );
      provider.silentResult = account;

      await service.connect();

      expect(service.state.status, GoogleCalendarAuthorizationStatus.connected);
      expect(service.state.account, account);
      expect(provider.signOutCount, 0);
    },
  );

  test('tries silent sign-in before interactive sign-in', () async {
    firebase.currentUserValue = googleUser();
    provider.interactiveResult = account;

    await service.connect();

    expect(provider.silentSignInCount, 1);
    expect(provider.interactiveSignInCount, 1);
    expect(service.state.status, GoogleCalendarAuthorizationStatus.connected);
  });

  test('treats interactive cancellation as disconnected', () async {
    firebase.currentUserValue = googleUser();

    await service.connect();

    expect(provider.silentSignInCount, 1);
    expect(provider.interactiveSignInCount, 1);
    expect(provider.requestScopesCount, 0);
    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
  });

  test('denies a missing Firebase user before calling the provider', () async {
    await service.connect();

    expect(service.state.status, GoogleCalendarAuthorizationStatus.denied);
    expect(
      service.state.issue,
      GoogleCalendarAuthorizationIssue.nexecuteUserMissing,
    );
    expect(provider.currentAccountReadCount, 0);
  });

  test(
    'denies anonymous and non-Google users before calling the provider',
    () async {
      for (final user in [
        FakeUser(uid: 'anonymous', isAnonymous: true),
        FakeUser(
          uid: 'password-user',
          providerData: [
            FakeUserInfo(uid: 'password-user', providerId: 'password'),
          ],
        ),
      ]) {
        firebase.currentUserValue = user;

        await service.connect();

        expect(service.state.status, GoogleCalendarAuthorizationStatus.denied);
        expect(
          service.state.issue,
          GoogleCalendarAuthorizationIssue.nexecuteAccountIsNotGoogle,
        );
      }
      expect(provider.currentAccountReadCount, 0);
    },
  );

  test(
    'signs out a mismatched provider account without requesting scopes',
    () async {
      firebase.currentUserValue = googleUser();
      provider.currentAccountValue = const GoogleCalendarAccountIdentity(
        id: 'other-google-id',
        email: 'same-email-is-irrelevant@example.com',
      );

      await service.connect();

      expect(provider.signOutCount, 1);
      expect(provider.requestScopesCount, 0);
      expect(provider.accessTokenCount, 0);
      expect(service.state.status, GoogleCalendarAuthorizationStatus.denied);
      expect(
        service.state.issue,
        GoogleCalendarAuthorizationIssue.accountMismatch,
      );
    },
  );

  test('requests exactly the two read-only Calendar scopes', () async {
    await connect();

    expect(provider.requestScopesCount, 1);
    expect(provider.lastRequestedScopes, googleCalendarReadScopes);
    expect(provider.lastRequestedScopes, hasLength(2));
  });

  test('reports scope denial without requesting a token', () async {
    firebase.currentUserValue = googleUser();
    provider.silentResult = account;
    provider.scopesResult = false;

    await service.connect();

    expect(provider.accessTokenCount, 0);
    expect(service.state.status, GoogleCalendarAuthorizationStatus.denied);
    expect(service.state.issue, GoogleCalendarAuthorizationIssue.scopesDenied);
  });

  test('reports a missing initial token as expired', () async {
    firebase.currentUserValue = googleUser();
    provider.silentResult = account;
    provider.tokenResult = null;

    await service.connect();

    expect(service.state.status, GoogleCalendarAuthorizationStatus.expired);
    expect(
      service.state.issue,
      GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
    );
  });

  test(
    'emits deterministic checking, authorizing, and connected states',
    () async {
      firebase.currentUserValue = googleUser();
      provider.silentResult = account;
      final states = <GoogleCalendarAuthorizationState>[];
      final subscription = service.states.listen(states.add);

      await service.connect();

      expect(states.map((state) => state.status), [
        GoogleCalendarAuthorizationStatus.checking,
        GoogleCalendarAuthorizationStatus.authorizing,
        GoogleCalendarAuthorizationStatus.connected,
      ]);
      expect(states[0].account, isNull);
      expect(states[1].account, account);
      expect(states[2].account, account);
      await subscription.cancel();
    },
  );

  test('retrieves a token only while the same account is connected', () async {
    await connect();
    provider.tokenResult = 'fresh-token';

    expect((await service.accessToken()).value, 'fresh-token');
    expect(provider.accessTokenCount, 2);
  });

  test('performs one clear-cache recovery attempt and does not loop', () async {
    await connect();
    final rejectedToken = await service.accessToken();
    provider.tokenResult = 'recovered-token';

    expect(
      (await service.refreshAccessTokenAfterUnauthorized(rejectedToken)).value,
      'recovered-token',
    );
    await expectLater(
      service.refreshAccessTokenAfterUnauthorized(rejectedToken),
      throwsA(
        isA<GoogleCalendarAuthorizationException>().having(
          (error) => error.issue,
          'issue',
          GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
        ),
      ),
    );
    expect(provider.clearAuthCacheCount, 1);
    expect(service.state.status, GoogleCalendarAuthorizationStatus.expired);
  });

  test(
    'disconnect signs out only the provider and clears owned cache',
    () async {
      await connect();

      await service.disconnect();

      expect(provider.signOutCount, 1);
      expect(firebase.signOutCount, 0);
      expect(loginGoogle.signOutCount, 0);
      expect(cache.clearedOwners, [
        const GoogleCalendarCacheOwner(
          nexecuteUserId: 'firebase-uid-not-google-id',
          googleAccountId: googleId,
        ),
      ]);
      expect(
        service.state.status,
        GoogleCalendarAuthorizationStatus.disconnected,
      );
    },
  );

  test(
    'Firebase logout clears cache without signing out the provider',
    () async {
      await connect();
      firebase.currentUserValue = null;

      firebaseUsers.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(cache.clearedOwners, hasLength(1));
      expect(provider.signOutCount, 0);
      expect(
        service.state.status,
        GoogleCalendarAuthorizationStatus.disconnected,
      );
    },
  );

  test('Firebase account change clears the previous account cache', () async {
    await connect();
    final replacement = googleUser(
      uid: 'replacement-firebase-uid',
      providerUid: 'replacement-google-id',
    );
    firebase.currentUserValue = replacement;

    firebaseUsers.add(replacement);
    await Future<void>.delayed(Duration.zero);

    expect(cache.clearedOwners, hasLength(1));
    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
  });

  test('concurrent connect calls share one provider operation', () async {
    firebase.currentUserValue = googleUser();
    final silentResult = Completer<GoogleCalendarAccountIdentity?>();
    provider.onSignInSilently = () => silentResult.future;

    final first = service.connect();
    final second = service.connect();
    expect(identical(first, second), isTrue);
    expect(provider.silentSignInCount, 1);

    silentResult.complete(account);
    await Future.wait([first, second]);

    expect(provider.silentSignInCount, 1);
    expect(provider.requestScopesCount, 1);
  });

  test('disconnect invalidates a pending connect operation', () async {
    firebase.currentUserValue = googleUser();
    final silentResult = Completer<GoogleCalendarAccountIdentity?>();
    provider.onSignInSilently = () => silentResult.future;

    final pendingConnect = service.connect();
    await service.disconnect();
    silentResult.complete(account);
    await pendingConnect;

    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
    expect(provider.requestScopesCount, 0);
  });

  test('Firebase account change prevents a pending scope request', () async {
    firebase.currentUserValue = googleUser();
    final silentResult = Completer<GoogleCalendarAccountIdentity?>();
    provider.onSignInSilently = () => silentResult.future;

    final pendingConnect = service.connect();
    final replacement = googleUser(
      uid: 'replacement-firebase-uid',
      providerUid: 'replacement-google-id',
    );
    firebase.currentUserValue = replacement;
    firebaseUsers.add(replacement);
    silentResult.complete(account);
    await pendingConnect;

    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
    expect(provider.requestScopesCount, 0);
  });

  test(
    'reconnect waits for disconnect cleanup and provider sign-out',
    () async {
      await connect();
      final cacheClear = Completer<void>();
      cache.onClear = (_) => cacheClear.future;

      final pendingDisconnect = service.disconnect();
      final pendingReconnect = service.connect();
      await Future<void>.delayed(Duration.zero);

      expect(provider.silentSignInCount, 1);
      expect(provider.signOutCount, 0);

      cacheClear.complete();
      await pendingDisconnect;
      await pendingReconnect;

      expect(provider.signOutCount, 1);
      expect(provider.silentSignInCount, 2);
      expect(service.state.status, GoogleCalendarAuthorizationStatus.connected);
    },
  );

  test(
    'a second disconnect cancels a reconnect queued during cleanup',
    () async {
      await connect();
      final cacheClear = Completer<void>();
      cache.onClear = (_) => cacheClear.future;

      final firstDisconnect = service.disconnect();
      final pendingReconnect = service.connect();
      final secondDisconnect = service.disconnect();
      cacheClear.complete();
      await Future.wait([firstDisconnect, pendingReconnect, secondDisconnect]);

      expect(provider.silentSignInCount, 1);
      expect(
        service.state.status,
        GoogleCalendarAuthorizationStatus.disconnected,
      );
    },
  );

  test(
    'Firebase account change during token acquisition cannot connect',
    () async {
      firebase.currentUserValue = googleUser();
      provider.silentResult = account;
      final tokenResult = Completer<String?>();
      provider.onAccessToken = () => tokenResult.future;

      final pendingConnect = service.connect();
      await Future<void>.delayed(Duration.zero);
      expect(provider.accessTokenCount, 1);
      final replacement = googleUser(
        uid: 'replacement-firebase-uid',
        providerUid: 'replacement-google-id',
      );
      firebase.currentUserValue = replacement;
      firebaseUsers.add(replacement);
      tokenResult.complete('stale-token');
      await pendingConnect;

      expect(
        service.state.status,
        GoogleCalendarAuthorizationStatus.disconnected,
      );
      expect(provider.signOutCount, 0);
    },
  );

  test(
    'provider account change during token acquisition cannot connect',
    () async {
      firebase.currentUserValue = googleUser();
      provider.silentResult = account;
      final tokenResult = Completer<String?>();
      provider.onAccessToken = () => tokenResult.future;

      final pendingConnect = service.connect();
      await Future<void>.delayed(Duration.zero);
      expect(provider.accessTokenCount, 1);
      provider.emitAccount(
        const GoogleCalendarAccountIdentity(
          id: 'replacement-google-id',
          email: 'replacement@example.com',
        ),
      );
      tokenResult.complete('stale-token');
      await pendingConnect;

      expect(
        service.state.status,
        GoogleCalendarAuthorizationStatus.disconnected,
      );
      expect(provider.signOutCount, 0);
    },
  );

  test('token acquisition racing disconnect never returns a token', () async {
    await connect();
    final tokenResult = Completer<String?>();
    provider.onAccessToken = () => tokenResult.future;

    final pendingToken = service.accessToken();
    await service.disconnect();
    tokenResult.complete('stale-token');

    await expectLater(
      pendingToken,
      throwsA(isA<GoogleCalendarAuthorizationException>()),
    );
    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
  });

  test('an old unauthorized token cannot expire a new connection', () async {
    await connect();
    final oldToken = await service.accessToken();
    await service.disconnect();
    provider.silentResult = account;
    await service.connect();

    await expectLater(
      service.refreshAccessTokenAfterUnauthorized(oldToken),
      throwsA(
        isA<GoogleCalendarAuthorizationException>().having(
          (error) => error.issue,
          'issue',
          GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
        ),
      ),
    );

    expect(service.state.status, GoogleCalendarAuthorizationStatus.connected);
    expect(provider.clearAuthCacheCount, 0);
  });

  test('unlinking the Firebase Google provider clears authorization', () async {
    await connect();
    final unlinkedUser = FakeUser(
      uid: 'firebase-uid-not-google-id',
      providerData: [
        FakeUserInfo(uid: 'password-user', providerId: 'password'),
      ],
    );
    firebase.currentUserValue = unlinkedUser;

    firebaseUsers.add(unlinkedUser);
    await Future<void>.delayed(Duration.zero);

    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
    expect(cache.clearedOwners, hasLength(1));
  });

  test('dispose invalidates a pending connect operation', () async {
    firebase.currentUserValue = googleUser();
    final silentResult = Completer<GoogleCalendarAccountIdentity?>();
    provider.onSignInSilently = () => silentResult.future;

    final pendingConnect = service.connect();
    await service.dispose();
    silentResult.complete(account);
    await pendingConnect;

    expect(
      service.state.status,
      GoogleCalendarAuthorizationStatus.disconnected,
    );
    expect(provider.requestScopesCount, 0);
  });

  test(
    'provider failures leave a safe state and do not leak secrets',
    () async {
      const secret = 'super-secret-provider-token';
      firebase.currentUserValue = googleUser();
      provider.onSignInSilently = () => Future.error(StateError(secret));

      await service.connect();

      expect(service.state.status, GoogleCalendarAuthorizationStatus.failed);
      expect(
        service.state.issue,
        GoogleCalendarAuthorizationIssue.providerUnavailable,
      );
      expect(service.state.account, isNull);
      expect(service.state.toString(), isNot(contains(secret)));

      provider.onSignInSilently = null;
      provider.silentResult = account;
      await service.connect();
      provider.onAccessToken = () => Future.error(StateError(secret));

      await expectLater(
        service.accessToken(),
        throwsA(
          isA<GoogleCalendarAuthorizationException>()
              .having(
                (error) => error.issue,
                'issue',
                GoogleCalendarAuthorizationIssue.providerUnavailable,
              )
              .having(
                (error) => error.toString(),
                'message',
                isNot(contains(secret)),
              ),
        ),
      );
      expect(service.state.status, GoogleCalendarAuthorizationStatus.failed);
    },
  );

  test('unsupported service is inert and rejects token access', () async {
    const unsupported = UnsupportedGoogleCalendarAuthorization();

    expect(
      unsupported.state.status,
      GoogleCalendarAuthorizationStatus.unsupported,
    );
    await unsupported.connect();
    await unsupported.disconnect();
    await expectLater(
      unsupported.accessToken(),
      throwsA(
        isA<GoogleCalendarAuthorizationException>().having(
          (error) => error.issue,
          'issue',
          GoogleCalendarAuthorizationIssue.unsupported,
        ),
      ),
    );
    expect(
      (await unsupported.states.first).status,
      GoogleCalendarAuthorizationStatus.unsupported,
    );
  });

  test('factory selects unsupported for web and unsupported platforms', () {
    for (final platform in [
      AppRuntimePlatform.web,
      AppRuntimePlatform.unsupported,
    ]) {
      expect(
        createGoogleCalendarAuthorizationService(
          platform: platform,
          authService: auth,
          client: provider,
        ),
        isA<UnsupportedGoogleCalendarAuthorization>(),
      );
    }
  });

  test('factory selects the real service for Android and macOS', () async {
    final created = <GoogleCalendarAuthorizationService>[];
    for (final platform in [
      AppRuntimePlatform.android,
      AppRuntimePlatform.macOS,
    ]) {
      final result = createGoogleCalendarAuthorizationService(
        platform: platform,
        authService: auth,
        client: provider,
      );
      created.add(result);
      expect(result, isA<GoogleCalendarAuthorization>());
    }
    for (final result in created) {
      await result.dispose();
    }
  });
}

class FakeUser extends Fake implements User {
  FakeUser({
    required this.uid,
    this.email,
    this.isAnonymous = false,
    this.providerData = const [],
  });

  @override
  final String uid;

  @override
  final String? email;

  @override
  final bool isAnonymous;

  @override
  final List<UserInfo> providerData;
}

class FakeUserInfo extends Fake implements UserInfo {
  FakeUserInfo({required this.uid, required this.providerId, this.email});

  @override
  final String uid;

  @override
  final String providerId;

  @override
  final String? email;
}
