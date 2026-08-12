import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/aurion/aurion_provider.dart';
import 'package:vibe_app/core/aurion/aurion_service.dart';
import 'package:vibe_app/core/aurion/gigachat_provider.dart';

class FakeAurionProvider implements AurionProvider {
  FakeAurionProvider({this.fail = false, this.answer = 'Ответ Aurion'});

  bool fail;
  String answer;
  String? configuredKey;
  String? lastPrompt;

  @override
  String get name => 'Fake';

  @override
  Set<AurionCapability> get capabilities =>
      {AurionCapability.textGeneration};

  @override
  void configure(String apiKey) => configuredKey = apiKey;

  @override
  Future<String> complete(AurionRequest request) async {
    lastPrompt = request.prompt;
    if (fail) throw const AurionException('Aurion временно недоступен.');
    return answer;
  }

  @override
  Future<bool> ping() async => !fail;
}

class InMemorySecretStorage implements SecretStorage {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySecretStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = InMemorySecretStorage();
    AurionService.instance.secretStorage = storage;
    AurionService.instance.providerFactory = () => FakeAurionProvider();
    await AurionService.instance.init();
  });

  group('GigaChatProvider', () {
    test('complete: oauth + chat/completions, возвращает текст', () async {
      var oauthCalled = 0;
      var chatCalled = 0;
      final client = MockClient((request) async {
        if (request.url.toString().contains('/oauth')) {
          oauthCalled++;
          expect(request.headers['Authorization'], startsWith('Basic '));
          return http.Response(
            jsonEncode({'access_token': 'tok-123', 'expires_at': 999}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        chatCalled++;
        expect(request.url.toString(), contains('/chat/completions'));
        expect(request.headers['Authorization'], 'Bearer tok-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'GigaChat-Max');
        expect(
          (body['messages'] as List).last['content'],
          'Перескажи чат',
        );
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': ' Краткий пересказ '},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GigaChatProvider(client: client)
        ..configure('sec-42');
      final answer = await provider.complete(
        const AurionRequest(prompt: 'Перескажи чат'),
      );

      expect(answer, 'Краткий пересказ');
      expect(oauthCalled, 1);
      expect(chatCalled, 1);
    });

    test('complete: 401 на oauth → понятная ошибка про ключ', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":"forbidden"}', 401),
      );
      final provider = GigaChatProvider(client: client)..configure('bad');

      expect(
        () => provider.complete(const AurionRequest(prompt: 'x')),
        throwsA(isA<AurionException>().having(
          (e) => e.userMessage,
          'userMessage',
          contains('ключ'),
        )),
      );
    });

    test('complete: сетевой сбой → «Aurion временно недоступен»',
        () async {
      final client = MockClient(
        (_) async => throw http.ClientException('boom'),
      );
      final provider = GigaChatProvider(client: client)..configure('k');

      expect(
        () => provider.complete(const AurionRequest(prompt: 'x')),
        throwsA(isA<AurionException>().having(
          (e) => e.userMessage,
          'userMessage',
          'Aurion временно недоступен.',
        )),
      );
    });

    test('ping: валидный ключ → true, 401 → false', () async {
      var fail = false;
      final client = MockClient((request) async {
        if (fail) return http.Response('no', 401);
        return http.Response(
          jsonEncode({'access_token': 't'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final provider = GigaChatProvider(client: client)..configure('k');

      expect(await provider.ping(), isTrue);
      fail = true;
      expect(await provider.ping(), isFalse);
    });
  });

  group('AurionService', () {
    test('init без ключа → disabled', () async {
      expect(AurionService.instance.status, AurionStatus.disabled);
    });

    test('enable с валидным ключом → enabled и ключ у провайдера',
        () async {
      final fake = FakeAurionProvider();
      AurionService.instance.providerFactory = () => fake;

      await AurionService.instance.enable('good-key');

      expect(AurionService.instance.status, AurionStatus.enabled);
      expect(fake.configuredKey, 'good-key');
    });

    test('enable с невалидным ключом → disabled', () async {
      AurionService.instance.providerFactory =
          () => FakeAurionProvider(fail: true);

      await AurionService.instance.enable('bad-key');

      expect(AurionService.instance.status, AurionStatus.disabled);
    });

    test('complete при enabled возвращает ответ и не трогает статус',
        () async {
      final fake = FakeAurionProvider(answer: 'Готово');
      AurionService.instance.providerFactory = () => fake;
      await AurionService.instance.enable('k');

      final answer = await AurionService.instance.complete('Переведи');

      expect(answer, 'Готово');
      expect(fake.lastPrompt, 'Переведи');
      expect(AurionService.instance.status, AurionStatus.enabled);
    });

    test('complete при сбое → degraded + исключение, потом recovery',
        () async {
      final fake = FakeAurionProvider();
      AurionService.instance.providerFactory = () => fake;
      await AurionService.instance.enable('k');

      fake.fail = true;
      await expectLater(
        AurionService.instance.complete('x'),
        throwsA(isA<AurionException>()),
      );
      expect(AurionService.instance.status, AurionStatus.degraded);

      fake.fail = false;
      await AurionService.instance.complete('y');
      expect(AurionService.instance.status, AurionStatus.enabled);
    });

    test('disable стирает статус и ключ (повторный init → disabled)',
        () async {
      AurionService.instance.providerFactory = () => FakeAurionProvider();
      await AurionService.instance.enable('k');
      expect(AurionService.instance.status, AurionStatus.enabled);

      await AurionService.instance.disable();
      expect(AurionService.instance.status, AurionStatus.disabled);

      await AurionService.instance.init();
      expect(AurionService.instance.status, AurionStatus.disabled);
    });
  });
}