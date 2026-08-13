import 'package:flutter_test/flutter_test.dart';

import 'package:vibe_app/core/services/link_preview.dart';

void main() {
  setUp(() {
    VibeLinkPreview.instance.customFetcher = null;
  });

  test('firstUrl: извлекает первую ссылку, режет хвостовую пунктуацию', () {
    final lp = VibeLinkPreview.instance;
    expect(lp.firstUrl('смотри https://a.b/c, дальше'), 'https://a.b/c');
    expect(lp.firstUrl('нет ссылок'), isNull);
    expect(lp.firstUrl('(https://x.y/z).'), 'https://x.y/z');
  });

  test('parseOg: title/description/image из meta-тегов', () {
    final base = Uri.parse('https://example.com/post/1');
    final meta = VibeLinkPreview.parseOg(
      base,
      '<html><head>'
      '<title>Страница</title>'
      '<meta property="og:title" content="Заголовок поста">'
      '<meta name="description" content="Описание &amp; ещё">'
      '<meta property="og:image" content="/img/cover.png">'
      '</head><body></body></html>',
    );
    expect(meta.title, 'Заголовок поста');
    expect(meta.description, 'Описание & ещё');
    expect(meta.imageUrl, 'https://example.com/img/cover.png');
    expect(meta.domain, 'example.com');
  });

  test('parseOg: без меты — пустой результат (честный отказ)', () {
    final meta = VibeLinkPreview.parseOg(
      Uri.parse('https://a.b/'),
      '<html><body>привет</body></html>',
    );
    expect(meta.isEmpty, isTrue);
  });

  test('metaFor: кэширует результат fetcher, повторно не вызывает', () async {
    var calls = 0;
    VibeLinkPreview.instance.customFetcher = (uri) async {
      calls++;
      return LinkMeta(url: uri.toString(), domain: uri.host, title: 'Т');
    };
    var first = VibeLinkPreview.instance.metaFor('https://x.y/1');
    expect(first, isNull, reason: 'первый вызов — превью ещё не готово');
    await Future<void>.delayed(Duration.zero);
    first = VibeLinkPreview.instance.metaFor('https://x.y/1');
    expect(first, isNotNull);
    expect(first!.title, 'Т');
    expect(calls, 1, reason: 'повторный запрос идёт из кэша');
  });
}