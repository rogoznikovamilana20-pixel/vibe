import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/services/scheduled_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;
  final errors = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScheduledService.instance.debugReset();
    ScheduledService.instance.backendProvider = () {
      errors.add('scheduled service used wrong backend');
      throw StateError('wrong backend');
    };
    fake = FakeVibeBackend();
    ScheduledService.instance.backendProvider = () => fake;
    errors.clear();
  });

  tearDown(() {
    ScheduledService.instance.debugReset();
    fake.close();
  });

  test('schedule: появляется в очереди и персистится', () async {
    final when = DateTime.now().add(const Duration(hours: 1));
    await ScheduledService.instance.schedule('c1', 'позже', when);

    final pending = ScheduledService.instance.pendingFor('c1');
    expect(pending, hasLength(1));
    expect(pending.first.text, 'позже');
    expect(pending.first.when, when);
    expect(ScheduledService.instance.pendingFor('c2'), isEmpty);
  });

  test('init: восстанавливает очередь и заводит таймеры', () async {
    final when = DateTime.now().add(const Duration(hours: 2));
    SharedPreferences.setMockInitialValues({
      'vibe_scheduled_c1': jsonEncode([
        {
          'localId': 'sched_1',
          'chatId': 'c1',
          'text': 'восстановленное',
          'when': when.toIso8601String(),
        },
      ]),
    });

    await ScheduledService.instance.init();

    final pending = ScheduledService.instance.pendingFor('c1');
    expect(pending, hasLength(1));
    expect(pending.first.text, 'восстановленное');
  });

  test('cancel: сообщение удаляется, отправка не происходит', () async {
    await ScheduledService.instance
        .schedule('c1', 'не отправим', DateTime.now().add(const Duration(hours: 1)));

    await ScheduledService.instance.cancel('c1', 'x');
    expect(ScheduledService.instance.pendingFor('c1'), hasLength(1),
        reason: 'чужой id не удаляет');

    final localId =
        ScheduledService.instance.pendingFor('c1').first.localId;
    await ScheduledService.instance.cancel('c1', localId);

    expect(ScheduledService.instance.pendingFor('c1'), isEmpty);
    expect(fake.calls.where((c) => c.startsWith('sendText')), isEmpty);
  });

  test('таймер: по наступлению времени отправляет и очищает очередь',
      () {
    fakeAsync((async) {
      var done = false;
      ScheduledService.instance
          .schedule('c1', 'по расписанию',
              DateTime.now().add(const Duration(hours: 1)))
          .then((_) => done = true);
      async.flushMicrotasks();
      expect(done, isTrue);
      expect(fake.calls.where((c) => c.startsWith('sendText')), isEmpty);

      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();

      expect(fake.calls, contains('sendText(c1)'));
      expect(fake.lastTextSent, 'по расписанию');
      expect(ScheduledService.instance.pendingFor('c1'), isEmpty);
    });
  });

  test('сетевой сбой: повторная попытка через минуту', () {
    fakeAsync((async) {
      fake.throwOnSendText = true;
      ScheduledService.instance
          .schedule('c1', 'упорный',
              DateTime.now().add(const Duration(hours: 1)));
      async.flushMicrotasks();

      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();
      expect(ScheduledService.instance.pendingFor('c1'), hasLength(1),
          reason: 'при сбое сообщение остаётся в очереди');
      expect(
        fake.calls.where((c) => c.startsWith('sendText')).toList(),
        hasLength(1),
        reason: 'первая попытка была и упала',
      );

      fake.throwOnSendText = false;
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();

      expect(
        fake.calls.where((c) => c.startsWith('sendText')).toList(),
        hasLength(2),
        reason: 'повторная попытка через минуту',
      );
      expect(ScheduledService.instance.pendingFor('c1'), isEmpty);
    });
  });
}