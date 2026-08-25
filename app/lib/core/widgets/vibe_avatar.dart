import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/backend.dart';
import '../services/media_cache.dart';
import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_typography.dart';

/// Сетевой виджет приватных медиа: резолвит [source] через
/// edge-функцию media-sign в подписанный URL и грузит картинку
/// через диск-кэш (5.4), с опциональным декодированием в целевом
/// размере [cacheWidth]/[cacheHeight].
class VibeNetImage extends StatefulWidget {
  const VibeNetImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
  });

  /// Резолвер пути в подписанный URL (по умолчанию — живой бэкенд;
  /// в unit-тестах подменяется фейком).
  static Future<String?> Function(String? source) resolveUrl =
      (s) => VibeBackend.instance.mediaUrl(s);

  /// Путь в бакете, старый публичный URL или локальный путь.
  final String? source;
  final BoxFit fit;
  final Widget? placeholder;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Декодирование в целевом разрешении (экономия памяти).
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  State<VibeNetImage> createState() => _VibeNetImageState();
}

class _VibeNetImageState extends State<VibeNetImage> {
  Future<String?>? _future;
  String? _lastSource;
  Future<File?>? _fileFuture;
  String? _lastUrl;

  // Мемоизируем future, чтобы FutureBuilder не сбрасывался в «загрузку»
  // на каждом rebuild (это давало мультяшность при обновлении списка).
  Future<String?> _urlFor(String? source) {
    if (source != _lastSource || _future == null) {
      _lastSource = source;
      _future = VibeNetImage.resolveUrl(source);
    }
    return _future!;
  }

  // Мемоизация загрузки файла по URL (без повторных обращений к диску).
  Future<File?> _fileFor(String url) {
    if (url != _lastUrl || _fileFuture == null) {
      _lastUrl = url;
      _fileFuture = MediaCache.instance.cachedFile(url);
    }
    return _fileFuture!;
  }

  @override
  void didUpdateWidget(covariant VibeNetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _future = null;
      _fileFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    if (source == null || source.isEmpty) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return FutureBuilder<String?>(
      // Не create-каждый-билд: стабильный future до смены source.
      future: _urlFor(source),
      builder: (context, snap) {
        final url = snap.data;
        if (snap.connectionState != ConnectionState.done || url == null) {
          return widget.placeholder ??
              ColoredBox(
                color: VibeColors.textTertiaryDark.withValues(alpha: 0.15),
              );
        }
        return FutureBuilder<File?>(
          future: _fileFor(url),
          builder: (context, fs) {
            final file = fs.data;
            if (fs.connectionState != ConnectionState.done || file == null) {
              return widget.placeholder ??
                  ColoredBox(
                    color: VibeColors.textTertiaryDark.withValues(alpha: 0.15),
                  );
            }
            return Image.file(
              file,
              fit: widget.fit,
              cacheWidth: widget.cacheWidth,
              cacheHeight: widget.cacheHeight,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) =>
                  widget.errorBuilder?.call(context, error, stack) ??
                  (widget.placeholder ??
                      ColoredBox(
                        color: VibeColors.textTertiaryDark.withValues(
                          alpha: 0.15,
                        ),
                      )),
            );
          },
        );
      },
    );
  }
}

/// Аватар Vibe: градиент + инициалы, геометрия — круглая.
/// Поддерживает онлайн-индикатор и «кольцо сториз».
/// Если передан [photo] — отображается фото (круглый кроп) из байтов,
/// если [photoUrl] — фото грузится по сети.
class VibeAvatar extends StatelessWidget {
  const VibeAvatar({
    super.key,
    required this.name,
    required this.size,
    this.online = false,
    this.storyRing = false,
    this.ringColor,
    this.emoji,
    this.photo,
    this.photoUrl,
    this.gradientOverride,
    this.fallbackIcon,
  });

  final String name;
  final double size;
  final bool online;
  final bool storyRing;

  /// Цвет кольца сториз. Если задан — испольается вместо градиента:
  /// [VibeColors.success] = онлайн, серый = давно не был.
  final Color? ringColor;

  /// Ручной градиент аватара вместо автогенерации по имени.
  final List<Color>? gradientOverride;

  final String? emoji;
  final Uint8List? photo;
  final String? photoUrl;

  /// Если фото/эмодзи нет — вместо инициалов показывается эта иконка
  /// (например, силуэт пользователя в навигации).
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final gradient = gradientOverride ?? VibeAvatarGradients.forName(name);
    final image = photo != null
        ? ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: Image.memory(
                photo!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          )
        : photoUrl != null
        ? ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: VibeNetImage(
                source: photoUrl,
                fit: BoxFit.cover,
                // 5.4: декодируем в целевом размере аватара.
                cacheWidth: (size * MediaQuery.of(context).devicePixelRatio)
                    .round(),
                errorBuilder: (_, _, _) => _fallback(gradient),
              ),
            ),
          )
        : _fallback(gradient);

    final wrapped = Padding(
      padding: storyRing ? const EdgeInsets.all(2) : EdgeInsets.zero,
      child: image,
    );

    return SizedBox(
      width: size + (storyRing ? 6 : 0),
      height: size + (storyRing ? 6 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (storyRing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ringColor != null
                      ? null
                      : const LinearGradient(colors: VibeColors.brandGradient),
                  color: ringColor,
                ),
              ),
            ),
          Center(child: wrapped),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.30,
                height: size * 0.30,
                decoration: BoxDecoration(
                  color: VibeColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(List<Color> gradient) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: emoji != null
          ? Text(emoji!, style: TextStyle(fontSize: size * 0.5))
          : fallbackIcon != null
          ? Icon(
              fallbackIcon,
              color: Colors.white.withValues(alpha: 0.85),
              size: size * 0.5,
            )
          : Text(
              _initials(name),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Бейдж непрочитанных сообщений.
class VibeUnreadBadge extends StatelessWidget {
  const VibeUnreadBadge({super.key, required this.count, this.muted = false});

  final int count;

  /// В режиме «не беспокоить» бейдж приглушается.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final bg = muted
        ? VibeColors.textTertiaryDark.withValues(alpha: 0.45)
        : VibeColors.unreadBlue;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(VibeRadius.badge),
        ),
        constraints: const BoxConstraints(minWidth: 20),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Бейдж-метка (для контекстов: Личное/Работа/Бот).
class VibeTag extends StatelessWidget {
  const VibeTag({
    super.key,
    required this.text,
    this.color = VibeColors.primary,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(VibeRadius.badge),
      ),
      child: Text(text, style: VibeTypography.label.copyWith(color: color)),
    );
  }
}
