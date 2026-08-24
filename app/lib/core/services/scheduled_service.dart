import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/backend_api.dart';

/// Отложенное текстовое сообщение (3.9) + silent как в TG.
class ScheduledMessage {
  const ScheduledMessage({
    required this.localId,
    required this.chatId,
    required this.text,
    required this.when,
    this.silent = false,
  });

  final String localId;
  final String chatId;
  final String text;
  final DateTime when;
  final bool silent;

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'chatId': chatId,
        'text': text,
        'when': when.toIso8601String(),
        'silent': silent,
      };

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) =>
      ScheduledMessage(
        localId: json['localId'] as String,
        chatId: json['chatId'] as String,
        text: json['text'] as String,
        when: DateTime.parse(json['when'] as String),
        silent: json['silent'] as bool? ?? false,
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
    bool silent = false,
  }) async {
    final m = ScheduledMessage(
      localId: localId ?? 'sched_${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      text: text,
      when: when,
      silent: silent,
    );
    (_byChat[chatId] ??= []).add(m);
    _arm(m);
    await _persist(chatId);
    version.value++;
    // Серверное зеркало как в TG (best-effort) — cron доставит даже если приложение убито.
    try {
      final uid = VibeBackend.instance.myProfileId;
      if (uid != null) {
        await Supabase.instance.client.from('scheduled_messages').insert({
          'chat_id': chatId,
          'sender_id': uid,
          'text': text,
          'schedule_at': when.toUtc().toIso8601String(),
          'silent': silent,
        });
      }
    } catch (_) {}
  }

  Future<void> cancel(String chatId, String localId) async {
    final list = _byChat[chatId];
    final removed = list?.where((m) => m.localId == localId).toList() ?? const [];
    if (list == null) return;
    list.removeWhere((m) => m.localId == localId);
    _timers.remove(localId)?.cancel();
    await _persist(chatId);
    version.value++;
    // Удалить серверное зеркало, чтобы pg_cron не доставил дубль
    for (final m in removed) {
      try {
        final uid = VibeBackend.instance.myProfileId;
        if (uid != null) {
          await Supabase.instance.client
              .from('scheduled_messages')
              .delete()
              .eq('chat_id', chatId)
              .eq('sender_id', uid)
              .eq('text', m.text)
              .eq('schedule_at', m.when.toUtc().toIso8601String());
        }
      } catch (_) {}
    }
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
      await backendProvider().sendText(m.chatId, m.text, localId: m.localId, silent: m.silent);
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