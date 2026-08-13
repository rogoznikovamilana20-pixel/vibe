import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_button.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Редактор аватарки: круг как в Telegram, зум/сдвиг/поворот,
/// сохранение круглого PNG (прозрачные углы).
class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({super.key, required this.image});

  final XFile image;

  /// Выбрать фото из галереи и (если выбрано) открыть редактор.
  /// Возвращает байты готового круглого аватара или null.
  static Future<Uint8List?> pickAndEdit(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 96,
    );
    if (picked == null || !context.mounted) return null;
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => AvatarEditorScreen(image: picked)),
    );
    return bytes;
  }

  /// Взять фото с камеры и открыть редактор.
  static Future<Uint8List?> takeAndEdit(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 96,
    );
    if (picked == null || !context.mounted) return null;
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => AvatarEditorScreen(image: picked)),
    );
    return bytes;
  }

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  final _boundary = GlobalKey();
  double _angle = 0;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.image.readAsBytes();
    if (!mounted) return;
    setState(() => _bytes = data);
  }

  void _rotate() {
    setState(() => _angle += 3.14159265358979 / 12); // 15°
  }

  Future<void> _save() async {
    final boundary =
        _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      final outSize = 640.0;
      final ratio = outSize / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: ratio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final bytes = byteData?.buffer.asUint8List();
      if (!mounted || bytes == null) return;
      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Scaffold(
      backgroundColor: VibeColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.md,
                vertical: VibeSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(VibeIcons.close, color: Colors.white),
                    tooltip: 'Отмена',
                  ),
                  const Expanded(
                    child: Text(
                      'Новое фото профиля',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  VibeButton(
                    expand: false,
                    height: 40,
                    label: 'Готово',
                    onPressed: bytes == null ? null : _save,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: RepaintBoundary(
                      key: _boundary,
                      child: Container(
                        color: VibeColors.bgDark,
                        child: Center(
                          child: ClipOval(
                            child: SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: bytes == null
                                  ? const ColoredBox(color: Colors.black12)
                                  : Transform.rotate(
                                      angle: _angle,
                                      child: InteractiveViewer(
                                        maxScale: 6,
                                        minScale: 1,
                                        boundaryMargin:
                                            const EdgeInsets.all(400),
                                        child: Image.memory(
                                          bytes,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: VibeSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundTool(
                        icon: Icons.rotate_right_rounded,
                        tooltip: 'Поворот',
                        onTap: _rotate,
                      ),
                      const SizedBox(width: VibeSpacing.lg),
                      _RoundTool(
                        icon: Icons.open_in_full_rounded,
                        tooltip: 'Масштаб: пинч',
                        onTap: () {},
                      ),
                      const SizedBox(width: VibeSpacing.lg),
                      _RoundTool(
                        icon: Icons.arrow_outward_rounded,
                        tooltip: 'Перенос: свайп',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: VibeSpacing.lg),
                  Text(
                    'Поверни пальцем фото и подгони размер\nкруга — так будет видно всем',
                    textAlign: TextAlign.center,
                    style: VibeTypography.caption.copyWith(
                      color: VibeColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: VibeSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundTool extends StatelessWidget {
  const _RoundTool({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}