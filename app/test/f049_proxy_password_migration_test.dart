// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/data/settings_service.dart';

/// F-049: Proxy password migration from SharedPreferences to SecureStorage.
///
/// Tests that:
/// 1. Legacy password in SharedPreferences is migrated to SecureStorage on init
/// 2. After migration, password is removed from SharedPreferences
/// 3. Password is readable from SecureStorage after migration
/// 4. Empty/no password in SharedPreferences results in no migration
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};

  setUp(() async {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'read':
          return store[call.arguments['key']];
        case 'write':
          store[call.arguments['key']] = call.arguments['value'] as String;
          return null;
        case 'delete':
          store.remove(call.arguments['key']);
          return null;
        case 'readAll':
          return store;
        case 'deleteAll':
          store.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('F-049: Proxy password migration', () {
    test('legacy password migrated from SharedPreferences to SecureStorage', () async {
      SharedPreferences.setMockInitialValues({
        'vibe_proxy_password': 'secret123',
      });

      final service = SettingsService.instance;
      await service.init();

      // Password should be readable
      final password = await service.proxyPassword();
      expect(password, 'secret123');

      // Password should be removed from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vibe_proxy_password'), isNull);
    });

    test('no migration when SharedPreferences has no password', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService.instance;
      await service.init();

      final password = await service.proxyPassword();
      expect(password, '');
    });

    test('empty password in SharedPreferences is not migrated', () async {
      SharedPreferences.setMockInitialValues({
        'vibe_proxy_password': '',
      });

      final service = SettingsService.instance;
      await service.init();

      final password = await service.proxyPassword();
      expect(password, '');
    });

    test('setProxyPassword writes to SecureStorage, not SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final service = SettingsService.instance;
      await service.init();

      await service.setProxyPassword('newpass');

      // Should be in SecureStorage
      final password = await service.proxyPassword();
      expect(password, 'newpass');

      // Should NOT be in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vibe_proxy_password'), isNull);
    });
  });
}
