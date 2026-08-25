import 'dart:convert';

/// Типы JSON-вложений сообщений (8.3.3): хранятся в столбце text как
/// `{"v":1,"kind":"file",…}` — серверная схема не меняется.
enum AttachmentKind { file, location, contact, poll, pollVote, gif }

/// Разобранное JSON-вложение.
class AttachmentData {
  const AttachmentData({
    required this.kind,
    this.name,
    this.size = 0,
    this.mime,
    this.url,
    this.lat = 0,
    this.lng = 0,
    this.label,
    this.uid,
    this.contactName,
    this.nick,
    this.question,
    this.options = const [],
    this.anonymous = true,
    this.multiple = false,
    this.quiz = false,
    this.correctOption,
    this.pollId,
    this.opt = 0,
  });

  final AttachmentKind kind;

  // file
  final String? name;
  final int size;
  final String? mime;
  final String? url;

  // location
  final double lat;
  final double lng;
  final String? label;

  // contact
  final String? uid;
  final String? contactName;
  final String? nick;

  // poll
  final String? question;
  final List<String> options;
  final bool anonymous;
  final bool multiple;
  final bool quiz;
  final int? correctOption;

  // pollVote
  final String? pollId;
  final int opt;

  static String encode({
    required AttachmentKind kind,
    String? name,
    int size = 0,
    String? mime,
    String? url,
    double lat = 0,
    double lng = 0,
    String? label,
    String? uid,
    String? contactName,
    String? nick,
    String? question,
    List<String> options = const [],
    bool anonymous = true,
    bool multiple = false,
    bool quiz = false,
    int? correctOption,
    String? pollId,
    int opt = 0,
  }) {
    return jsonEncode({
      'v': 1,
      'kind': kind.name,
      'name': name,
      'size': size,
      'mime': mime,
      'url': url,
      'lat': lat,
      'lng': lng,
      'label': label,
      'uid': uid,
      'contactName': contactName,
      'nick': nick,
      'q': question,
      'opts': options,
      'anon': anonymous,
      'multiple': multiple,
      'quiz': quiz,
      'correct': correctOption,
      'poll': pollId,
      'opt': opt,
    });
  }

  static AttachmentData? tryParse(String? text) {
    if (text == null || text.isEmpty || !text.startsWith('{')) return null;
    try {
      final map = jsonDecode(text);
      if (map is! Map<String, dynamic>) return null;
      final kindName = map['kind'];
      final kind = AttachmentKind.values.asNameMap()[kindName];
      if (kind == null || map['v'] != 1) return null;
      return AttachmentData(
        kind: kind,
        name: map['name'] as String?,
        size: (map['size'] as num?)?.toInt() ?? 0,
        mime: map['mime'] as String?,
        url: map['url'] as String?,
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        label: map['label'] as String?,
        uid: map['uid'] as String?,
        contactName: map['contactName'] as String?,
        nick: map['nick'] as String?,
        question: map['q'] as String?,
        options: (map['opts'] as List?)?.cast<String>() ?? const [],
        anonymous: map['anon'] as bool? ?? true,
        multiple: map['multiple'] as bool? ?? false,
        quiz: map['quiz'] as bool? ?? false,
        correctOption: (map['correct'] as num?)?.toInt(),
        pollId: map['poll'] as String?,
        opt: (map['opt'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
