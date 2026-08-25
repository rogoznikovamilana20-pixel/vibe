import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_top_bar.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Простой редактор фото перед отправкой как в TG: рисование + подпись.
/// Возвращает `PhotoEditResult` с байтами (скриншот) и подписью.
class PhotoEditResult {
  const PhotoEditResult({required this.bytes, this.caption});

  final Uint8List bytes;
  final String? caption;
}

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key, required this.file, this.initialCaption});

  final File file;
  final String? initialCaption;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final GlobalKey _paintKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  _Stroke? _current;
  Color _color = VibeColors.primary;
  double _strokeWidth = 4;
  final TextEditingController _caption = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCaption != null) _caption.text = widget.initialCaption!;
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    final box = _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.globalToLocal(d.globalPosition);
    setState(() {
      _current = _Stroke(color: _color, width: _strokeWidth, points: [pos]);
      _strokes.add(_current!);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _current == null) return;
    final pos = box.globalToLocal(d.globalPosition);
    setState(() => _current!.points.add(pos));
  }

  void _onPanEnd(DragEndDetails _) {
    _current = null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final boundary = _paintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      Uint8List bytes;
      if (_strokes.isEmpty) {
        bytes = await widget.file.readAsBytes();
      } else if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = byteData!.buffer.asUint8List();
        image.dispose();
      } else {
        bytes = await widget.file.readAsBytes();
      }
      if (!mounted) return;
      Navigator.of(context).pop(PhotoEditResult(bytes: bytes, caption: _caption.text.trim().isEmpty ? null : _caption.text.trim()));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(PhotoEditResult(bytes: await widget.file.readAsBytes(), caption: _caption.text.trim().isEmpty ? null : _caption.text.trim()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    HapticFeedback.selectionClick();
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.clear());
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: IconButton(
            icon: const Icon(VibeIcons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: VibeTopBarTitle('Редактировать', style: const TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded, color: Colors.white),
              onPressed: _strokes.isEmpty ? null : _undo,
              tooltip: 'Отменить',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              onPressed: _strokes.isEmpty ? null : _clear,
              tooltip: 'Очистить',
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Готово', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _paintKey,
                child: Stack(
                  children: [
                    Image.file(widget.file, fit: BoxFit.contain),
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: _DrawingPainter(_strokes),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            padding: EdgeInsets.fromLTRB(VibeSpacing.lg, VibeSpacing.sm, VibeSpacing.lg, MediaQuery.of(context).viewPadding.bottom + VibeSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in [VibeColors.primary, Colors.white, Colors.redAccent, Colors.greenAccent, Colors.yellowAccent, Colors.cyanAccent])
                        GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: _color == c ? Colors.white : Colors.white24, width: _color == c ? 3 : 1),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 3, label: Text('S')),
                          ButtonSegment(value: 6, label: Text('M')),
                          ButtonSegment(value: 10, label: Text('L')),
                        ],
                        selected: {_strokeWidth > 8 ? 10.0 : _strokeWidth > 4 ? 6.0 : 3.0},
                        onSelectionChanged: (s) => setState(() => _strokeWidth = s.first),
                        style: ButtonStyle(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: VibeSpacing.sm),
                TextField(
                  controller: _caption,
                  style: VibeTypography.body.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Подпись...',
                    hintStyle: VibeTypography.body.copyWith(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stroke {
  _Stroke({required this.color, required this.width, required this.points});
  final Color color;
  final double width;
  final List<Offset> points;
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter(this.strokes);
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.length < 2) {
        if (s.points.isNotEmpty) {
          canvas.drawCircle(s.points.first, s.width / 2, Paint()..color = s.color..style = PaintingStyle.fill);
        }
        continue;
      }
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (var i = 1; i < s.points.length; i++) {
        final p0 = s.points[i - 1];
        final p1 = s.points[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
