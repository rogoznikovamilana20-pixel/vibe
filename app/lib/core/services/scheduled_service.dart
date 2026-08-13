import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backend_api.dart';

/// Отложенное текстовое сообщение (3.9).
class ScheduledMessage {
  const ScheduledMessage({
    required this.localId,
    required this.chatId,
    required this.text,
    required this.when,
  });

  final String localId;
  final String chatId;
  final String text;
  final DateTime when;

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'chatId': chatId,
        'text': text,
        'when': when.toIso8601String(),
      };

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) =>
      ScheduledMessage(
        localId: json['localId'] as String,
        chatId: json['chatId'] as String,
        text: json['text'] as String,
        when: DateTime.parse(json['when'] as String),
      );
}

/// Очередь отложенных сообщений: хранится локально (SharedPreferences),
/// отправляется по таймеру, пока приложение живо. После перезапуска
/// очередь восстанавливается и таймеры заводятся заново (3.9, без фейков:
/// в облако отложенную отправку не выносим — это честное локальное
/// планирование с повтором через минуту при сетевом сбое).
class ScheduledService {
  ScheduledService._();

  static final ScheduledService instance = ScheduledService._();

  /// Подмена бэкенда для тестов; по умолчанию — продакшен-синглтон.
  VibeBackendApi Function() backendProvider = () => LiveVibeBackend();

  static const _keyPrefix = 'vibe_scheduled_';

  /// Инкремент при любой мутации очереди — для чипа над композером.
  final ValueNotifier<int> version = ValueNotifier(0);

  final Map<String, List<ScheduledMessage>> _byChat = {};
  final Map<String, Timer> _timers = {};

  bool _inited = false;

  @visibleForTesting
  void debugReset() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _byChat.clear();
    _inited = false;
  }

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in prefs.getKeys()) {
      if (!entry.startsWith(_keyPrefix)) continue;
      final raw = prefs.getString(entry);
      if (raw == null) continue;
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => ScheduledMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        _byChat[entry.substring(_keyPrefix.length)] = list;
        for (final m in list) {
          _arm(m);
        }
      } catch (_) {
        // Повреждённая запись — игнорируем.
      }
    }
  }

  /// Отсортированные по времени отложенные сообщения чата.
  List<ScheduledMessage> pendingFor(String chatId) {
    final list = List<ScheduledMessage>.of(_byChat[chatId] ?? const [])
      ..sort((a, b) => a.when.compareTo(b.when));
    return list;
  }

  Future<void> schedule(
    String chatId,
    String text,
    DateTime when, {
    String? localId,
  }) async {
    final m = ScheduledMessage(
      localId: localId ?? 'sched_${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      text: text,
      when: when,
    );
    (_byChat[chatId] ??= []).add(m);
    _arm(m);
    await _persist(chatId);
    version.value++;
  }

  Future<void> cancel(String chatId, String localId) async {
    final list = _byChat[chatId];
    if (list == null) return;
    list.removeWhere((m) => m.localId == localId);
    _timers.remove(localId)?.cancel();
    await _persist(chatId);
    version.value++;
  }

  Future<void> _persist(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _byChat[chatId] ?? const <ScheduledMessage>[];
    if (list.isEmpty) {
      await prefs.remove('$_keyPrefix$chatId');
      return;
    }
    await prefs.setString(
      '$_keyPrefix$chatId',
      jsonEncode(list.map((m) => m.toJson()).toList()),
    );
  }

  void _arm(ScheduledMessage m) {
    _timers[m.localId]?.cancel();
    final delay = m.when.difference(DateTime.now());
    _timers[m.localId] = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => _fire(m),
    );
  }

  Future<void> _fire(ScheduledMessage m) async {
    _timers.remove(m.localId);
    try {
      await backendProvider().sendText(m.chatId, m.text, localId: m.localId);
    } catch (_) {
      // Сетевой сбой — честная деградация: повторим через минуту.
      final retry = ScheduledMessage(
        localId: m.localId,
        chatId: m.chatId,
        text: m.text,
        when: DateTime.now().add(const Duration(minutes: 1)),
      );
      final list = _byChat[m.chatId];
      if (list != null) {
        final idx = list.indexWhere((e) => e.localId == m.localId);
        if (idx >= 0) list[idx] = retry;
      }
      _arm(retry);
      return;
    }
    await cancel(m.chatId, m.localId);
  }
}