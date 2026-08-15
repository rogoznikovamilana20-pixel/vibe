import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

/// Chat export service — exports chat history as a text file.
/// Similar to Telegram's "Export Chat History" feature.
class ChatExportService {
  ChatExportService._();
  static final instance = ChatExportService._();

  /// Export chat messages to a text file and return the file path.
  Future<String?> exportChat({
    required String chatId,
    required String chatTitle,
    required List<ChatMsg> messages,
  }) async {
    if (messages.isEmpty) return null;

    try {
      final content = _formatMessages(messages, chatTitle);
      final file = await _writeToFile(content, chatTitle);
      if (file == null) return null;

      // Open file with system default app.
      await launchUrl(Uri.file(file.path));

      return file.path;
    } catch (_) {
      return null;
    }
  }

  String _formatMessages(List<ChatMsg> messages, String chatTitle) {
    final buffer = StringBuffer();
    buffer.writeln('Chat: $chatTitle');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Messages: ${messages.length}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final msg in messages) {
      final sender = msg.incoming ? 'Peer' : 'Me';
      final time = msg.time;
      final text = msg.text.isNotEmpty ? msg.text : '[${msg.type.name}]';
      buffer.writeln('[$time] $sender: $text');
    }

    return buffer.toString();
  }

  Future<File?> _writeToFile(String content, String chatTitle) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = chatTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final file = File('${dir.path}/vibe_export_${safeName}_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(content);
      return file;
    } catch (_) {
      return null;
    }
  }
}
