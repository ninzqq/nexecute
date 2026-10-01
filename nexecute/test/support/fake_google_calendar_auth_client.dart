import 'dart:async';

import 'package:nexecute/services/google_calendar_authorization.dart';

class FakeGoogleCalendarAuthClient implements GoogleCalendarAuthClient {
  final accountChangesController =
      StreamController<GoogleCalendarAccountIdentity?>.broadcast(sync: true);

  GoogleCalendarAccountIdentity? currentAccountValue;
  GoogleCalendarAccountIdentity? silentResult;
  GoogleCalendarAccountIdentity? interactiveResult;
  bool scopesResult = true;
  String? tokenResult = 'access-token';

  Future<GoogleCalendarAccountIdentity?> Function()? onSignInSilently;
  Future<GoogleCalendarAccountIdentity?> Function()? onSignIn;
  Future<bool> Function(List<String> scopes)? onRequestScopes;
  Future<String?> Function()? onAccessToken;
  Future<void> Function()? onClearAuthCache;
  Future<void> Function()? onSignOut;

  int currentAccountReadCount = 0;
  int silentSignInCount = 0;
  int interactiveSignInCount = 0;
  int requestScopesCount = 0;
  int accessTokenCount = 0;
  int clearAuthCacheCount = 0;
  int signOutCount = 0;
  List<String>? lastRequestedScopes;

  @override
  GoogleCalendarAccountIdentity? get currentAccount {
    currentAccountReadCount += 1;
    return currentAccountValue;
  }

  @override
  Stream<GoogleCalendarAccountIdentity?> get accountChanges =>
      accountChangesController.stream;

  @override
  Future<GoogleCalendarAccountIdentity?> signInSilently() async {
    silentSignInCount += 1;
    final result =
        onSignInSilently == null
            ? silentResult
            : await onSignInSilently!.call();
    currentAccountValue = result;
    return result;
  }

  @override
  Future<GoogleCalendarAccountIdentity?> signIn() async {
    interactiveSignInCount += 1;
    final result =
        onSignIn == null ? interactiveResult : await onSignIn!.call();
    currentAccountValue = result;
    return result;
  }

  @override
  Future<bool> requestScopes(List<String> scopes) async {
    requestScopesCount += 1;
    lastRequestedScopes = List.unmodifiable(scopes);
    return await onRequestScopes?.call(scopes) ?? scopesResult;
  }

  @override
  Future<String?> accessToken() async {
    accessTokenCount += 1;
    return await onAccessToken?.call() ?? tokenResult;
  }

  @override
  Future<void> clearAuthCache() async {
    clearAuthCacheCount += 1;
    await onClearAuthCache?.call();
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    await onSignOut?.call();
    currentAccountValue = null;
  }

  void emitAccount(GoogleCalendarAccountIdentity? account) {
    currentAccountValue = account;
    accountChangesController.add(account);
  }

  Future<void> close() => accountChangesController.close();
}

class FakeGoogleCalendarCacheLifecycle implements GoogleCalendarCacheLifecycle {
  final clearedOwners = <GoogleCalendarCacheOwner>[];
  Future<void> Function(GoogleCalendarCacheOwner owner)? onClear;

  @override
  Future<void> clearForAccount(GoogleCalendarCacheOwner owner) async {
    clearedOwners.add(owner);
    await onClear?.call(owner);
  }
}
