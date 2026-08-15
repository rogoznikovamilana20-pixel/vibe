import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';

/// GIF search panel using Tenor API.
/// Returns a file path when a GIF is selected.
class GifSearchPanel extends StatefulWidget {
  const GifSearchPanel({super.key, this.onGifSelected});

  final ValueChanged<String>? onGifSelected;

  @override
  State<GifSearchPanel> createState() => _GifSearchPanelState();
}

class _GifSearchPanelState extends State<GifSearchPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<_GifResult> _results = [];
  bool _loading = false;
  bool _initialLoad = true;
  String? _nextPos;

  // Tenor API key (free tier: 1000 req/day)
  static const _apiKey = 'AIzaSyBBJFS7BYOhPz2G0JmKXEgPCBau2pEkGm8';
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadTrending() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final url = Uri.parse(
        'https://tenor.googleapis.com/v2/featured?key=$_apiKey&limit=$_limit&media_filter=gif,tinygif',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = (data['results'] as List)
            .map((r) => _GifResult.fromTenor(r))
            .toList();
        setState(() {
          _results = results;
          _nextPos = data['next'];
          _initialLoad = false;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() {
      _loading = true;
      _results = [];
      _nextPos = null;
    });
    try {
      final url = Uri.parse(
        'https://tenor.googleapis.com/v2/search?key=$_apiKey&q=${Uri.encodeComponent(query)}&limit=$_limit&media_filter=gif,tinygif',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = (data['results'] as List)
            .map((r) => _GifResult.fromTenor(r))
            .toList();
        setState(() {
          _results = results;
          _nextPos = data['next'];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loading || _nextPos == null) return;
    setState(() => _loading = true);
    try {
      final url = Uri.parse(
        'https://tenor.googleapis.com/v2/$_searchOrTrending?key=$_apiKey&limit=$_limit&pos=$_nextPos&media_filter=gif,tinygif',
        // ignore: avoid_dynamic_calls
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = (data['results'] as List)
            .map((r) => _GifResult.fromTenor(r))
            .toList();
        setState(() {
          _results.addAll(results);
          _nextPos = data['next'];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _searchOrTrending =>
      _controller.text.trim().isEmpty ? 'featured' : 'search';

  Future<void> _selectGif(_GifResult gif) async {
    HapticFeedback.lightImpact();
    final gifUrl = gif.url;
    if (gifUrl == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vibe_gifs/${gif.id}.gif');
      if (!await file.exists()) {
        await file.parent.create(recursive: true);
        final res = await http.get(Uri.parse(gifUrl));
        await file.writeAsBytes(res.bodyBytes);
      }
      widget.onGifSelected?.call(file.path);
      if (mounted) Navigator.of(context).pop(file.path);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: context.vibeSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VibeRadius.bottomSheet),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.vibeTextTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Поиск GIF...',
                prefixIcon: Icon(Icons.search, color: context.vibeTextSecondary),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _loadTrending();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.vibeSurfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: context.vibeTextPrimary),
              onSubmitted: _search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: VibeSpacing.sm),
          Expanded(
            child: _initialLoad
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'Ничего не найдено',
                          style: VibeTypography.body
                              .copyWith(color: context.vibeTextSecondary),
                        ),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(VibeSpacing.sm),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _results.length + (_nextPos != null ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _results.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final gif = _results[i];
                          return GestureDetector(
                            onTap: () => _selectGif(gif),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                gif.tinyUrl ?? gif.url ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: context.vibeSurfaceVariant,
                                  child: Icon(Icons.gif_box_outlined,
                                      color: context.vibeTextTertiary),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _GifResult {
  final String? id;
  final String? url;
  final String? tinyUrl;

  _GifResult({this.id, this.url, this.tinyUrl});

  factory _GifResult.fromTenor(Map<String, dynamic> r) {
    final media = r['media_formats'] as Map<String, dynamic>?;
    final gif = media?['gif'] as Map<String, dynamic>?;
    final tiny = media?['tinygif'] as Map<String, dynamic>?;
    return _GifResult(
      id: r['id'] as String?,
      url: gif?['url'] as String?,
      tinyUrl: tiny?['url'] as String?,
    );
  }
}
