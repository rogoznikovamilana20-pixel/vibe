import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Результат записи видеокружка.
class VideoRoundResult {
  const VideoRoundResult(this.file, this.seconds);

  final File file;
  final int seconds;
}

/// Экран записи видеокружка — как в Telegram:
/// круглый предпросмотр камеры, удержание = запись,
/// отпускание = автоотправка, свайп вверх = фиксация с панелью отмены/отправки.
class VideoRoundRecorderScreen extends StatefulWidget {
  const VideoRoundRecorderScreen({super.key});

  @override
  State<VideoRoundRecorderScreen> createState() =>
      _VideoRoundRecorderScreenState();
}

class _VideoRoundRecorderScreenState extends State<VideoRoundRecorderScreen> {
  CameraController? _cam;
  bool _recording = false;
  bool _locked = false;
  int _seconds = 0;
  bool _initFailed = false;

  Timer? _timer;
  Timer? _holdTimer;
  double _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final c = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await c.initialize();
      if (!mounted) return;
      setState(() => _cam = c);
    } catch (e) {
      if (mounted) setState(() => _initFailed = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _holdTimer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final cam = _cam;
    if (cam == null || _recording) return;
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    await cam.startVideoRecording();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _seconds++);
      if (_seconds >= 60) {
        _finish();
      }
    });
  }

  Future<File?> _stopRecording() async {
    final cam = _cam;
    if (cam == null || !_recording) return null;
    _timer?.cancel();
    final xfile = await cam.stopVideoRecording();
    setState(() {
      _recording = false;
      _locked = false;
    });
    return File(xfile.path);
  }

  Future<void> _finish() async {
    final f = await _stopRecording();
    if (!mounted) return;
    if (f == null || _seconds < 1) {
      if (f != null && _seconds < 1) {
        try {
          f.delete();
        } catch (_) {}
      }
      _snack('Запись слишком короткая');
      return;
    }
    Navigator.of(context).pop(VideoRoundResult(f, _seconds));
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (_recording) {
      final f = await _stopRecording();
      if (f != null) {
        try {
          f.delete();
        } catch (_) {}
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  void _onTapDown(TapDownDetails d) {
    if (_cam == null || _initFailed || _recording || _locked) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(
      const Duration(milliseconds: 220),
      () {
        if (mounted && !_recording) _startRecording();
      },
    );
  }

  void _onTapUp(TapUpDetails d) {
    _holdTimer?.cancel();
    if (_recording && !_locked) _finish();
  }

  void _onTapCancel() {
    _holdTimer?.cancel();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragDy += d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final dy = _dragDy;
    setState(() => _dragDy = 0);
    if (!_recording) return;
    if (dy < -40) {
      HapticFeedback.selectionClick();
      setState(() => _locked = true);
    } else if (dy > 56 && _locked) {
      HapticFeedback.selectionClick();
      setState(() => _locked = false);
    } else if (!_locked) {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Scaffold(
      backgroundColor: VibeColors.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Круглый предпросмотр камеры (без растягивания: кривой аспект
          // камеры компенсируется масштабом, лишнее обрезается кругом).
          Center(
            child: SizedBox(
              width: 340,
              height: 340,
              child: ClipOval(
                child: cam != null && cam.value.isInitialized
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scaleByDouble(
                              cam.value.aspectRatio, cam.value.aspectRatio, 1, 1),
                        child: Center(
                          child: CameraPreview(cam),
                        ),
                      )
                    : Center(
                        child: CircularProgressIndicator(
                          color: context.vibePrimary,
                        ),
                      ),
              ),
            ),
          ),
          if (_initFailed)
            const Center(
              child: Text(
                'Камера недоступна',
                style: TextStyle(color: VibeColors.textSecondaryDark),
              ),
            ),
          // Верхняя кнопка закрытия.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(VibeSpacing.md),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _recording ? null : _cancel,
                      icon: const Icon(VibeIcons.close),
                      color: Colors.white,
                    ),
                    const Spacer(),
                    if (_recording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VibeSpacing.md,
                          vertical: VibeSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: VibeColors.bgAltDark.withValues(alpha: 0.6),
                          borderRadius:
                              BorderRadius.circular(VibeRadius.badge),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle_rounded,
                              size: 8,
                              color: context.vibeError,
                            ),
                            const SizedBox(width: VibeSpacing.sm),
                            Text(
                              '0:${_seconds.toString().padLeft(2, '0')}',
                              style: VibeTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Нижняя панель управления.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                VibeSpacing.xl,
                0,
                VibeSpacing.xl,
                VibeSpacing.xl,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_recording && _locked)
                    IconButton(
                      onPressed: _cancel,
                      icon: const Icon(VibeIcons.close, size: 26),
                      color: context.vibeError,
                      tooltip: 'Отмена',
                    ),
                  const SizedBox(width: VibeSpacing.xl),
                  GestureDetector(
                    onTapDown: _onTapDown,
                    onTapUp: _onTapUp,
                    onTapCancel: _onTapCancel,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: AnimatedContainer(
                      duration: VibeAnimations.pulse,
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _recording
                            ? context.vibeError.withValues(alpha: 0.85)
                            : context.vibePrimary.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _recording
                            ? Icons.stop_rounded
                            : VibeIcons.video,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.xl),
                  if (_recording && _locked)
                    IconButton(
                      onPressed: _finish,
                      icon: const Icon(VibeIcons.send, size: 24),
                      color: context.vibePrimary,
                      tooltip: 'Отправить',
                    ),
                ],
              ),
            ),
          ),
          if (_recording && !_locked)
            Positioned(
              left: 0,
              right: 0,
              bottom: 130,
              child: Center(
                child: Text(
                  'Свайп вверх — зафиксировать',
                  style: VibeTypography.caption.copyWith(
                    color: VibeColors.textSecondaryDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}