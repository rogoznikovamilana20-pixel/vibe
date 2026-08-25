// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
    SettingsService.instance.setPrivacySyncerForTest(fake);
  });

  test('изменение приватности зеркалится в облако целиком', () async {
    await SettingsService.instance.setPrivacyLastSeen(2);
    await SettingsService.instance.setPrivacyPhoto(1);
    await SettingsService.instance.setPrivacyGroups(2);

    expect(fake.calls.where((c) => c == 'savePrivacy'), hasLength(3));
    final last = fake.savedPrivacy.last;
    expect(last.lastSeen, 2);
    expect(last.photo, 1);
    expect(last.groups, 2);
    expect(last.forward, 0, reason: 'неизменённые поля сохраняются');
  });

  test('loadPrivacyFromServer: облако перезаписывает локальный кеш', () async {
    await SettingsService.instance.setPrivacyLastSeen(0);
    fake.privacySettings = const PrivacySettings(
      lastSeen: 2,
      photo: 2,
      forward: 1,
      calls: 1,
      groups: 2,
    );

    await SettingsService.instance.loadPrivacyFromServer();

    expect(SettingsService.instance.privacyLastSeen, 2);
    expect(SettingsService.instance.privacyPhoto, 2);
    expect(SettingsService.instance.privacyForward, 1);
    expect(SettingsService.instance.privacyCalls, 1);
    expect(SettingsService.instance.privacyGroups, 2);
  });

  test('loadPrivacyFromServer: нет записи — локальные значения остаются',
      () async {
    await SettingsService.instance.setPrivacyLastSeen(1);
    fake.privacySettings = null;

    await SettingsService.instance.loadPrivacyFromServer();

    expect(SettingsService.instance.privacyLastSeen, 1);
    expect(fake.calls, contains('fetchPrivacy'));
  });

  test('сбой зеркала: локальное изменение не теряется', () async {
    fake.throwOnSavePrivacy = true;

    await SettingsService.instance.setPrivacyCalls(2);

    expect(SettingsService.instance.privacyCalls, 2);
    expect(fake.savedPrivacy, isEmpty);
  });

  test('сбой загрузки с сервера: локальные значения не тронуты', () async {
    await SettingsService.instance.setPrivacyPhoto(2);
    fake.throwOnFetchPrivacy = true;

    await SettingsService.instance.loadPrivacyFromServer();

    expect(SettingsService.instance.privacyPhoto, 2);
  });
}