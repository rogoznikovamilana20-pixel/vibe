import 'dart:async';

import 'package:supabase/supabase.dart';

/// Инструмент валидации realtime-доставки.
/// modes: listen | send
/// listen — подписывается и ждёт 12с, печатает полученные события.
/// send — шлёт broadcast new_message (как приложение-отправитель).
Future<void> main(List<String> args) async {
  final mode = args.isNotEmpty ? args[0] : 'listen';
  final url = 'https://rgdwfoicidnamejluxfx.supabase.co';
  final key =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJnZHdmb2ljaWRuYW1lamx1eGZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyNTQ3MDUsImV4cCI6MjEwMDgzMDcwNX0.TKIgRjK5pQh2_2beTSlPXzPlDuN781-h1LHH0uJyHMA';
  final chatId = args.length > 1 ? args[1] : 'de9dd7ae-78a3-4e78-bd45-891042c457f2';
  final senderId = args.length > 2 ? args[2] : '22222222-2222-4222-8222-222222222222';
  final text = args.length > 3 ? args[3] : 'Мгновенная доставка (probe)';

  final client = SupabaseClient(url, key);
  final ch = client.channel('dm')
    ..onBroadcast(event: 'new_message', callback: (p) {
      print('PROBE GOT new_message: ${p['id']} sender=${p['sender_id']}');
    })
    ..onBroadcast(event: 'new_chat', callback: (p) {
      print('PROBE GOT new_chat: $p');
    });

  await ch.subscribe();
  print('PROBE[$mode] subscribed to dm');

  if (mode == 'send') {
    await ch.sendBroadcastMessage(event: 'new_message', payload: {
      'id': 'probe-${DateTime.now().millisecondsSinceEpoch}',
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'photo_url': null,
      'voice_url': null,
      'video_url': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    print('PROBE[$mode] sent new_message -> $chatId ($text)');
    await Future<void>.delayed(const Duration(seconds: 3));
  } else {
    await Future<void>.delayed(const Duration(seconds: 12));
  }

  await client.dispose();
  print('PROBE[$mode] done');
}