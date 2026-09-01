import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS uses only the required network and Keychain entitlements', () {
    final debug =
        File('macos/Runner/DebugProfile.entitlements').readAsStringSync();
    final release =
        File('macos/Runner/Release.entitlements').readAsStringSync();
    final info = File('macos/Runner/Info.plist').readAsStringSync();

    for (final entitlements in [debug, release]) {
      expect(entitlements, contains('com.apple.security.app-sandbox'));
      expect(entitlements, contains('com.apple.security.network.client'));
      expect(
        entitlements,
        contains(r'$(AppIdentifierPrefix)com.jndevworks.nexecute'),
      );
      expect(
        entitlements,
        contains(r'$(AppIdentifierPrefix)com.google.GIDSignIn'),
      );
    }

    expect(debug, contains('com.apple.security.network.server'));
    expect(debug, contains('com.apple.security.cs.allow-jit'));
    expect(release, isNot(contains('com.apple.security.network.server')));
    expect(release, isNot(contains('com.apple.security.cs.allow-jit')));
    expect(info, isNot(contains('NSAllowsArbitraryLoads')));
    expect(info, isNot(contains('NSExceptionDomains')));
    expect(info, contains('NSLocalNetworkUsageDescription'));
    expect(info, isNot(contains('NSBonjourServices')));
  });
}
