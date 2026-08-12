import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'aurion_provider.dart';

/// GigaChat Provider (Sber GigaChat API).
///
/// Токены выписываются OAuth 2.0 client-credentials (personal key из
/// GigaChat Studio) → `chat/completions` с Bearer-токеном. Ключ никогда
/// не логируется; провайдер получает его от [AurionService] в рантайме.
class GigaChatProvider implements AurionProvider {
  GigaChatProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Personal API key (GigaChat Studio). Устанавливается через
  /// [configure], никогда не логируется и не попадает в код.
  String apiKey = '';

  @override
  void configure(String apiKey) => this.apiKey = apiKey.trim();

  static const _oauthUrl =
      'https://ngw.devices.sberbank.ru:9443/api/v2/oauth';
  static const _chatUrl =
      'https://gigachat.devices.sberbank.ru/api/v1/chat/completions';
  static const _model = 'GigaChat-Max';

  @override
  String get name => 'GigaChat';

  @override
  Set<AurionCapability> get capabilities => {
        AurionCapability.textGeneration,
        AurionCapability.streaming,
      };

  String _uuid() {
    final rand = Random();
    final hex = List.generate(32, (_) => rand.nextInt(16).toRadixString(16));
    return '${hex.sublist(0, 8).join()}-${hex.sublist(8, 12).join()}-'
        '${hex.sublist(12, 16).join()}-${hex.sublist(16, 20).join()}-'
        '${hex.sublist(20).join()}';
  }

  /// OAuth 2.0 client-credentials: `client_secret` → access_token.
  Future<String> _fetchToken() async {
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse(_oauthUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'RqUID': _uuid(),
          'Authorization': 'Basic ${base64Encode(utf8.encode(apiKey))}',
        },
        body: 'scope=GIGACHAT_API_PERS',
      );
    } catch (e) {
      throw AurionException('Aurion временно недоступен.', e);
    }
    if (res.statusCode == 401) {
      throw const AurionException(
        'Не удалось подключиться: проверьте ключ доступа.',
      );
    }
    if (res.statusCode != 200) {
      throw const AurionException('Aurion временно недоступен.');
    }
    final data = _json(res.body);
    final token = data['access_token'];
    if (token is! String || token.isEmpty) {
      throw const AurionException(
        'Не удалось подключиться: проверьте ключ доступа.',
      );
    }
    return token;
  }

  @override
  Future<String> complete(AurionRequest request) async {
    final token = await _fetchToken();
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse(_chatUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            if (request.systemPrompt != null)
              {'role': 'system', 'content': request.systemPrompt},
            {'role': 'user', 'content': request.prompt},
          ],
          'temperature': 0.7,
        }),
      ).timeout(request.timeout);
    } catch (e) {
      throw AurionException('Aurion временно недоступен.', e);
    }
    if (res.statusCode != 200) {
      throw const AurionException('Aurion временно недоступен.');
    }
    final data = _json(res.body);
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AurionException('Aurion временно недоступен.');
    }
    final content = (choices.first as Map)['message']?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AurionException('Aurion временно недоступен.');
    }
    return content.trim();
  }

  @override
  Future<bool> ping() async {
    try {
      await _fetchToken();
      return true;
    } on AurionException catch (e) {
      if (e.userMessage.contains('ключ')) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _json(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw AurionException('Aurion временно недоступен.', e);
    }
  }
}