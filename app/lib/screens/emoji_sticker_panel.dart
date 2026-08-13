import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../data/backend.dart';
import '../data/backend_api.dart';

/// Панель ввода: вкладки «Эмодзи» (вставка в поле), «Стикеры»
/// и «Гифки» (мгновенная отправка анимированным медиа) — как в Telegram.
class EmojiStickerPanel extends StatefulWidget {
  const EmojiStickerPanel({
    super.key,
    required this.onEmoji,
    required this.onSticker,
    required this.onGif,
    this.backend,
  });

  /// Эмодзи выбран — дописать к тексту сообщения.
  final ValueChanged<String> onEmoji;

  /// Стикер выбран — отправить сразу.
  final ValueChanged<String> onSticker;

  /// Гифка выбрана — отправить сразу (аргумент — имя файла в assets).
  final ValueChanged<String> onGif;

  /// Источник стикер-паков (в тестах — фейк; по умолчанию — живой бэкенд).
  final VibeBackendApi? backend;

  @override
  State<EmojiStickerPanel> createState() => _EmojiStickerPanelState();
}

/// Встроенные анимированные гифки (локальный набор, без серверной схемы).
const kGifAssets = [
  'assets/gifs/gif1.gif',
  'assets/gifs/gif2.gif',
  'assets/gifs/gif3.gif',
  'assets/gifs/gif4.gif',
  'assets/gifs/gif5.gif',
  'assets/gifs/gif6.gif',
  'assets/gifs/gif7.gif',
  'assets/gifs/gif8.gif',
  'assets/gifs/gif9.gif',
  'assets/gifs/gif10.gif',
];

class _EmojiStickerPanelState extends State<EmojiStickerPanel> {
  Future<List<VibeStickerPack>>? _packsFuture;
  int _packIndex = 0;

  @override
  void initState() {
    super.initState();
    final VibeBackendApi backend =
        widget.backend ?? LiveVibeBackend(VibeBackend.instance);
    _packsFuture = backend.listStickerPacks();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(top: VibeSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.sm,
        vertical: VibeSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.vibeSurface,
        borderRadius: BorderRadius.circular(VibeRadius.card),
        border: Border.all(color: context.vibeDivider),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              indicatorColor: context.vibePrimary,
              labelColor: context.vibePrimary,
              unselectedLabelColor: context.vibeTextTertiary,
              labelStyle: VibeTypography.bodyMedium,
              tabs: const [
                Tab(text: 'Эмодзи'),
                Tab(text: 'Стикеры'),
                Tab(text: 'Гифки'),
              ],
            ),
            const SizedBox(height: VibeSpacing.sm),
            Expanded(
              child: TabBarView(
                children: [
                  EmojiPicker(
                    onEmojiSelected: (_, emoji) =>
                        widget.onEmoji(emoji.emoji),
                    config: Config(
                      height: 256,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: const EmojiViewConfig(
                        backgroundColor: Colors.transparent,
                      ),
                      categoryViewConfig: const CategoryViewConfig(
                        backgroundColor: Colors.transparent,
                        initCategory: Category.SMILEYS,
                        recentTabBehavior: RecentTabBehavior.NONE,
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        showBackspaceButton: true,
                        backgroundColor: Colors.transparent,
                        buttonColor: Colors.transparent,
                      ),
                    ),
                  ),
                  _buildStickers(context),
                  _buildGifs(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickers(BuildContext context) {
    return FutureBuilder<List<VibeStickerPack>>(
      future: _packsFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final packs = snap.data ?? const [];
        if (packs.isEmpty) {
          return Center(
            child: Text(
              'Стикеры скоро появятся',
              style: VibeTypography.bodyMedium.copyWith(
                color: context.vibeTextTertiary,
              ),
            ),
          );
        }
        final index = _packIndex.clamp(0, packs.length - 1);
        final pack = packs[index];
        return Column(
          children: [
            if (packs.length > 1)
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: packs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: VibeSpacing.sm),
                  itemBuilder: (context, i) => ChoiceChip(
                    label: Text(packs[i].title),
                    selected: i == index,
                    onSelected: (_) => setState(() => _packIndex = i),
                    selectedColor: context.vibePrimary,
                    labelStyle: VibeTypography.caption.copyWith(
                      color: i == index
                          ? Colors.white
                          : context.vibeTextSecondary,
                    ),
                    backgroundColor: context.vibeSurfaceVariant,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                ),
              ),
            const SizedBox(height: VibeSpacing.sm),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: VibeSpacing.xs,
                  crossAxisSpacing: VibeSpacing.xs,
                ),
                itemCount: pack.stickers.length,
                itemBuilder: (context, i) {
                  final sticker = pack.stickers[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(VibeRadius.md),
                    onTap: () => widget.onSticker(sticker.emoji),
                    child: Center(
                      child: Text(
                        sticker.emoji,
                        style: const TextStyle(fontSize: 34),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGifs(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: VibeSpacing.sm,
        crossAxisSpacing: VibeSpacing.sm,
      ),
      itemCount: kGifAssets.length,
      itemBuilder: (context, i) {
        final asset = kGifAssets[i];
        final name = asset.split('/').last;
        return InkWell(
          borderRadius: BorderRadius.circular(VibeRadius.md),
          onTap: () => widget.onGif(name),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VibeRadius.md),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}