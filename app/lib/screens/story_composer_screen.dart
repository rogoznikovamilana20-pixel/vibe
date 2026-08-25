import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/widgets/vibe_button.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Результат композера: фото/видео + подпись как в TG.
class StoryComposerResult {
  const StoryComposerResult(this.bytes, {this.videoFile, this.caption});

  final Uint8List bytes;
  final File? videoFile;
  final String? caption;
}

/// Полноэкранный композер истории как в Telegram:
/// камера с затвором, галерея и переключение камер;
/// после съёмки — превью с «Повторить / Опубликовать».
class StoryComposerScreen extends StatefulWidget {
  const StoryComposerScreen({super.key});

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  CameraController? _cam;
  Uint8List? _captured;
  final TextEditingController _captionCtrl = TextEditingController();
  bool _front = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      CameraDescription? back;
      for (final c in cams) {
        if (c.lensDirection == CameraLensDirection.back) {
          back = c;
          break;
        }
      }
      final cam = CameraController(
        back ?? cams.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _cam = cam;
      await cam.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      // Камера недоступна — остаёмся в тёмном экране с кнопкой галереи.
      if (mounted) setState(() {});
    }
  }

  Future<void> _flip() async {
    if (_cam == null) return;
    try {
      final cams = await availableCameras();
      CameraDescription? next;
      for (final c in cams) {
        final isFront = c.lensDirection == CameraLensDirection.front;
        if (isFront != _front) {
          next = c;
          break;
        }
      }
      if (next == null) return;
      final old = _cam;
      _cam = CameraController(next, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await _cam?.initialize();
      await old?.dispose();
      setState(() => _front = !_front);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await cam.takePicture();
      final bytes = await File(file.path).readAsBytes();
      if (mounted) setState(() => _captured = bytes);
    } catch (_) {
      if (mounted) _snack('Не удалось сделать фото');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  @override
  void dispose() {
    _cam?.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captured = _captured;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (captured != null)
            Image.memory(captured, fit: BoxFit.cover)
          else if (_cam != null && _cam!.value.isInitialized)
            CameraPreview(_cam!)
          else
            const ColoredBox(color: Color(0xFF0A0A12)),
          if (captured != null)
            _buildCapturedOverlay(context, captured)
          else
            _buildCameraOverlay(context),
        ],
      ),
    );
  }

  Widget _buildCameraOverlay(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(VibeSpacing.sm),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(VibeIcons.close),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () async {
                  final bytes = await StoryComposerGallery.pick(context);
                  if (bytes != null && context.mounted) {
                    Navigator.of(context).pop(StoryComposerResult(bytes));
                  }
                },
                icon: const Icon(Icons.photo_library_outlined),
                color: Colors.white,
                iconSize: 30,
                tooltip: 'Из галереи',
              ),
              IconButton(
                onPressed: () async {
                  final file = await StoryComposerGallery.pickVideo(context);
                  if (file != null && context.mounted) {
                    Navigator.of(context).pop(StoryComposerResult(Uint8List(0), videoFile: file));
                  }
                },
                icon: const Icon(Icons.video_library_outlined),
                color: Colors.white,
                iconSize: 30,
                tooltip: 'Видео',
              ),
              GestureDetector(
                onTap: _busy ? null : _capture,
                child: AnimatedScale(
                  scale: _busy ? 0.9 : 1,
                  duration: VibeAnimations.pulse,
                  curve: Curves.easeOut,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 4,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _cam == null ? null : _flip,
                icon: const Icon(Icons.flip_camera_ios_rounded),
                color: Colors.white,
                iconSize: 30,
                tooltip: 'Перевернуть камеру',
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCapturedOverlay(BuildContext context, Uint8List bytes) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(VibeSpacing.sm),
              child: IconButton(
                onPressed: () => setState(() => _captured = null),
                icon: const Icon(VibeIcons.back),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VibeSpacing.lg,
              0,
              VibeSpacing.lg,
              VibeSpacing.sm,
            ),
            child: TextField(
              controller: _captionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Подпись...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black45,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VibeSpacing.lg,
              0,
              VibeSpacing.lg,
              VibeSpacing.xl,
            ),
            child: Row(
              children: [
                Expanded(
                  child: VibeButton(
                    type: VibeButtonType.ghost,
                    label: 'Повторить',
                    onPressed: () => setState(() {
                      _captured = null;
                      _captionCtrl.clear();
                    }),
                  ),
                ),
                const SizedBox(width: VibeSpacing.md),
                Expanded(
                  child: VibeButton(
                    type: VibeButtonType.primary,
                    label: 'Опубликовать',
                    onPressed: () => Navigator.of(context).pop(
                      StoryComposerResult(bytes, caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Галерея для композера: фото/видео из памяти устройства.
class StoryComposerGallery {
  static Future<Uint8List?> pick(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2560,
      );
      if (picked == null) return null;
      try {
        return await picked.readAsBytes();
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<File?> pickVideo(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
      if (picked == null) return null;
      return File(picked.path);
    } catch (_) {
      return null;
    }
  }
}