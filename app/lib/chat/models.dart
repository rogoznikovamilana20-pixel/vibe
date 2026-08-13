import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/backend.dart';
import 'attachments.dart';

export 'attachments.dart';

/// Тип содержимого сообщения.
enum MsgType {
  text,
  photo,
  voice,
  video,

  /// Вложение «файл» (JSON-контент в text).
  file,

  /// Вложение «локация» (JSON-контент в text).
  location,

  /// Вложение «контакт» (JSON-контент в text).
  contact,

  /// Вложение «опрос» (JSON-контент в text).
  poll,

  /// Служебное сообщение «голос в опросе» — в ленте не показывается.
  pollVote,
}

/// Счётчик голосов опроса: [votes][i] — сколько голосов за вариант i.
List<int> computePollVotes(List<ChatMsg> messages, String pollId) {
  final counts = <int>[];
  for (final m in messages) {
    final attach = m.attachment;
    if (m.type != MsgType.pollVote ||
        attach == null ||
        attach.pollId != pollId) {
      continue;
    }
    while (counts.length <= attach.opt) {
      counts.add(0);
    }
    counts[attach.opt]++;
  }
  return counts;
}

/// Вариант, за который проголосовал текущий пользователь (или null).
int? myPollVote(List<ChatMsg> messages, String pollId) {
  for (final m in messages) {
    final attach = m.attachment;
    if (m.type == MsgType.pollVote &&
        !m.incoming &&
        attach != null &&
        attach.pollId == pollId) {
      return attach.opt;
    }
  }
  return null;
}

/// Разбивает текст на спаны, делая URL-ссылки кликабельными (как в TG).
final _urlPattern = RegExp(
  r'(?:(?:https?|ftp)://|www\.)[^\s<>"(){}]+',
  caseSensitive: false,
);

List<InlineSpan> buildLinkSpans(
  String text,
  Color linkColor,
  ValueChanged<String> onTap,
) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in _urlPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    final url = text.substring(match.start, match.end);
    spans.add(
      TextSpan(
        text: url,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor.withValues(alpha: 0.5),
        ),
        recognizer: TapGestureRecognizer()..onTap = () => onTap(url),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

class ChatReaction {
  const ChatReaction(this.emoji, this.count);

  final String emoji;
  final int count;
}

class ChatMsg {
  const ChatMsg({
    required this.type,
    required this.incoming,
    required this.time,
    this.text = '',
    this.photoSeed = 0,
    this.voiceSeconds = 0,
    this.voicePath,
    this.voiceUrl,
    this.photoUrl,
    this.videoPath,
    this.videoUrl,
    this.reactions = const [],
    this.replyText,
    this.replyAuthor,
    this.status = MsgStatus.sent,
    this.localId,
    this.edited = false,
    this.forwardedFrom,
    this.serverId,
    this.stickerEmoji,
    this.date,
    this.attachment,
  });

  final MsgType type;
  final bool incoming;
  final String time;
  final String text;

  /// Разобранное JSON-вложение (файл/локация/контакт/опрос/голос).
  final AttachmentData? attachment;

  /// Полная дата сообщения — для разделителей дат (как в Telegram).
  final DateTime? date;

  /// Сид для демо-превью «фото» (если нет реального фото).
  final int photoSeed;

  /// Длительность голосового, секунды.
  final int voiceSeconds;

  /// Локальный файл записанного голосового.
  final String? voicePath;

  /// Сетевой URL голосового (входящее сообщение).
  final String? voiceUrl;

  /// Сетевой URL фото (входящее сообщение).
  final String? photoUrl;

  /// Локальный файл записанного видеокружка.
  final String? videoPath;

  /// Сетевой URL видеокружка (входящее сообщение).
  final String? videoUrl;

  final List<ChatReaction> reactions;

  // Ответ/цитата.
  final String? replyText;
  final String? replyAuthor;

  /// Галочки: отправлено / доставлено / прочитано (для своих).
  final MsgStatus status;

  /// Ключ «мгновенного» сообщения — по нему заменяем пузырь на ответ сервера.
  final String? localId;

  /// Сообщение изменено автором (метка «изменено»).
  final bool edited;

  /// От кого переслано («Переслано от …»).
  final String? forwardedFrom;

  /// Серверный id — для правок/удалений из realtime-событий.
  final String? serverId;

  /// Стикер-эмодзи (у стикеров нет текста).
  final String? stickerEmoji;

  ChatMsg copyWith({
    List<ChatReaction>? reactions,
    MsgStatus? status,
    String? localId,
    bool? edited,
    String? serverId,
    String? stickerEmoji,
    AttachmentData? attachment,
  }) {
    return ChatMsg(
      type: type,
      incoming: incoming,
      time: time,
      text: text,
      photoSeed: photoSeed,
      voiceSeconds: voiceSeconds,
      voicePath: voicePath,
      voiceUrl: voiceUrl,
      photoUrl: photoUrl,
      videoPath: videoPath,
      videoUrl: videoUrl,
      reactions: reactions ?? this.reactions,
      replyText: replyText,
      replyAuthor: replyAuthor,
      status: status ?? this.status,
      localId: localId ?? this.localId,
      edited: edited ?? this.edited,
      forwardedFrom: forwardedFrom,
      serverId: serverId ?? this.serverId,
      stickerEmoji: stickerEmoji ?? this.stickerEmoji,
      date: date,
      attachment: attachment ?? this.attachment,
    );
  }
}
