// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/data/passcode_service.dart';

/// 1.6 (MASTER_PLAN): PIN вЂ” С…СЌС€+СЃРѕР»СЊ РІ SecureStorage, Р±Р»РѕРєРёСЂРѕРІРєР° РїРѕСЃР»Рµ 5 РїРѕРїС‹С‚РѕРє.
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
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({});
    await PasscodeService.instance.init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setPasscode С…СЂР°РЅРёС‚ С…СЌС€ СЃ СЃРѕР»СЊСЋ, РЅРµ РїР°СЂРѕР»СЊ', () async {
    await PasscodeService.instance.setPasscode('1234');

    expect(PasscodeService.instance.hasPasscode, isTrue);
    final raw = store['vibe_passcode']!;
    final parts = raw.split(':');
    expect(parts.length, 2);
    expect(parts[0], isNot('1234'), reason: 'СЃРѕР»СЊ РЅРµ СЂР°РІРЅР° РїР°СЂРѕР»СЋ');
    expect(parts[1], isNot('1234'), reason: 'С…СЌС€ РЅРµ СЂР°РІРµРЅ РїР°СЂРѕР»СЋ');
    expect(raw.contains('1234'), isFalse, reason: 'РїР°СЂРѕР»СЊ РЅРёРіРґРµ РЅРµ Р»РµР¶РёС‚ РѕС‚РєСЂС‹С‚Рѕ');
  });

  test('verifyPasscode: РІРµСЂРЅС‹Р№ РєРѕРґ СЃР±СЂР°СЃС‹РІР°РµС‚ РїРѕРїС‹С‚РєРё', () async {
    await PasscodeService.instance.setPasscode('1234');

    expect(await PasscodeService.instance.verifyPasscode('0000'), isFalse);
    expect(PasscodeService.instance.attemptsRemaining, 4);

    expect(await PasscodeService.instance.verifyPasscode('1234'), isTrue);
    expect(PasscodeService.instance.attemptsRemaining, 5);
  });

  test('5 РЅРµСѓРґР°С‡РЅС‹С… РїРѕРїС‹С‚РѕРє в†’ Р±Р»РѕРєРёСЂРѕРІРєР°, verify РІРѕР·РІСЂР°С‰Р°РµС‚ false', () async {
    await PasscodeService.instance.setPasscode('1234');

    for (var i = 0; i < 5; i++) {
      expect(await PasscodeService.instance.verifyPasscode('0000'), isFalse);
    }

    expect(PasscodeService.instance.attemptsRemaining, 0);
    expect(PasscodeService.instance.isLocked, isTrue);
    expect(await PasscodeService.instance.verifyPasscode('1234'), isFalse,
        reason: 'РІРѕ РІСЂРµРјСЏ Р±Р»РѕРєРёСЂРѕРІРєРё РґР°Р¶Рµ РІРµСЂРЅС‹Р№ РєРѕРґ РѕС‚РєР»РѕРЅСЏРµС‚СЃСЏ');

    // РЁРµСЃС‚Р°СЏ РїРѕРїС‹С‚РєР° РЅРµ СѓРІРµР»РёС‡РёРІР°РµС‚ СЃС‡С‘С‚С‡РёРє СЃРІРµСЂС… РјР°РєСЃРёРјСѓРјР°.
    expect(PasscodeService.instance.attemptsRemaining, 0);
  });
}
