import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 8.4.4: превью ссылок (LinkPreview).
///
/// Клиентский вариант: при тексте со ссылкой — GET страницы и парсинг
/// OpenGraph (<meta property="og:title|description|image">). Кэш по URL
/// в памяти, один запрос на URL. Внешний fetcher подменяем из тестов
/// (сеть в widget-тестах недоступна).
class VibeLinkPreview extends ChangeNotifier {
  VibeLinkPreview._();

  static final VibeLinkPreview instance = VibeLinkPreview._();

  static final RegExp _urlRe = RegExp(r'https?://\S+');
  static const _trailing = '.,;:!?)]}"\'';

  /// Тестовый fetcher: (uri) -> LinkMeta?. null = не тестировать.
  Future<LinkMeta?> Function(Uri uri)? customFetcher;

  final Map<String, LinkMeta> _cache = {};
  final Set<String> _inFlight = {};

  /// Превью для текста (первая ссылка в нём), если оно уже известно.
  /// Пустой запрос для URL без превью кэшируется как `LinkMeta.empty`.
  LinkMeta? metaFor(String text) {
    final url = firstUrl(text);
    if (url == null) return null;
    final cached = _cache[url];
    if (cached != null) return cached;
    if (_inFlight.contains(url)) return null;
    _inFlight.add(url);
    unawaited(_fetch(url));
    return null;
  }

  String? firstUrl(String text) {
    final m = _urlRe.firstMatch(text);
    if (m == null) return null;
    var url = m[0]!;
    while (url.isNotEmpty && _trailing.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    return url.isEmpty ? null : url;
  }

  Future<void> _fetch(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasAuthority) return fail(url);
      LinkMeta? meta;
      if (customFetcher != null) {
        meta = await customFetcher!(uri);
      } else {
        meta = await _defaultFetch(uri);
      }
      if (meta == null) return fail(url);
      _cache[url] = meta;
      notifyListeners();
    } catch (_) {
      fail(url);
    }
  }

  void fail(String url) {
    _cache[url] = LinkMeta.empty(url, url);
    notifyListeners();
  }

  Future<LinkMeta?> _defaultFetch(Uri uri) async {
    final client = http.Client();
    try {
      final res = await client
          .get(uri, headers: {
            'User-Agent': 'Vibe/1.0 (+https://vibe.messenger)',
          })
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      if ((res.contentLength ?? 0) > 512 * 1024) return null;
      final html = res.body;
      if (!html.contains('<meta') && !html.contains('<title')) return null;
      return parseOg(uri, html);
    } finally {
      client.close();
    }
  }

  /// Примитивный парсер OpenGraph: идём по <meta>-тегам, ищем
  /// property/name = og:title|og:description|og:image.
  static LinkMeta parseOg(Uri base, String html) {
    final metas = RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html);
    String? ogTitle;
    String? ogDescription;
    String? ogImage;
    String? plainTitle;
    String? plainDescription;
    for (final m in metas) {
      final tag = m[0]!;
      final prop = _attr(tag, 'property');
      final name = prop != null ? null : _attr(tag, 'name');
      final key = prop ?? name;
      final content = _attr(tag, 'content');
      if (key == null || content == null) continue;
      final k = key.toLowerCase();
      if (k == 'og:title') ogTitle = content;
      if (k == 'og:description') ogDescription = content;
      if (k == 'og:image') ogImage = content;
      if (k == 'title') plainTitle = content;
      if (k == 'description') plainDescription = content;
    }
    final titleMatch = plainTitle == null
        ? RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false)
            .firstMatch(html)
        : null;
    final title = _clean(ogTitle ?? plainTitle ?? titleMatch?.group(1));
    final description = _clean(ogDescription ?? plainDescription);
    String? image;
    if (ogImage != null) {
      final img = Uri.tryParse(_clean(ogImage)!);
      if (img != null) {
        image = img.hasScheme
            ? img.toString()
            : base.resolve(img.toString()).toString();
      }
    }
    if (title == null && image == null && description == null) {
      // Честный отказ: без данных превью не показываем.
      return LinkMeta.empty(base.toString(), base.host);
    }
    return LinkMeta(
      url: base.toString(),
      domain: base.host,
      title: title,
      description: description,
      imageUrl: image,
    );
  }

  static String? _attr(String tag, String name) {
    final re = RegExp(
      '$name\\s*=\\s*["\'](.*?)["\']',
      caseSensitive: false,
    );
    return re.firstMatch(tag)?.group(1);
  }

  static String? _clean(String? raw) {
    if (raw == null) return null;
    var s = raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    if (s.isEmpty) return null;
    return s;
  }
}

/// Мета превью ссылки. `empty` — URL без данных (не показывать карточку).
class LinkMeta {
  const LinkMeta({
    required this.url,
    required this.domain,
    this.title,
    this.description,
    this.imageUrl,
  });

  const LinkMeta.empty(String url, String domain)
      : this(url: url, domain: domain, title: null, description: null, imageUrl: null);

  final String url;
  final String domain;
  final String? title;
  final String? description;
  final String? imageUrl;

  bool get isEmpty => title == null && description == null && imageUrl == null;
}