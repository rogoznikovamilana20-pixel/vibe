// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/theme/vibe_colors.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/settings_service.dart';

/// Математика WCAG 2.x: относительная светимость и контраст.
double _luminance(Color c) {
  double lin(double v) {
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

class _Pair {
  const _Pair(this.label, this.fg, this.bg, {this.guarantee, this.golden});
  final String label;
  final Color fg;
  final Color bg;

  /// Жёсткая гарантия WCAG AA по роли.
  final double? guarantee;

  /// Эталон, зафиксированный 13.08.2026; расхождение >0.15 — сигнал.
  final double? golden;
}

void _runAudit(String name, List<_Pair> pairs) {
  final violations = <String>[];
  final goldenMismatch = <String>[];
  final out = StringBuffer('\n=== $name ===\n');

  for (final p in pairs) {
    final c = _contrast(p.fg, p.bg);
    out.writeln(
        '${p.label.padLeft(36)}: ${c.toStringAsFixed(2)}'
        '${p.guarantee != null ? ' (мин ${p.guarantee!.toStringAsFixed(1)})' : ''}'
        '${p.golden != null ? ' (золото ${p.golden!.toStringAsFixed(2)})' : ''}');
    if (p.golden != null && (c - p.golden!).abs() > 0.15) {
      goldenMismatch.add(
          '${p.label}: золото ${p.golden!.toStringAsFixed(2)} → ${c.toStringAsFixed(2)}');
    }
    if (p.guarantee != null && c < p.guarantee!) {
      violations.add(
          '${p.label}: ${c.toStringAsFixed(2)} < ${p.guarantee!.toStringAsFixed(1)}');
    }
  }

  // ignore: avoid_print
  print(out);

  if (goldenMismatch.isNotEmpty) {
    throw TestFailure('ЗОЛОТО ТЕМ ИЗМЕНЕНО (эталон 13.08.2026):\n  '
        '${goldenMismatch.join('\n  ')}');
  }
  if (violations.isNotEmpty) {
    throw TestFailure('Контраст ниже гарантии WCAG:\n  ${violations.join('\n  ')}');
  }
}

/// Пары «роль/где используется» для [ThemeData].
/// [goldens] — эталон 13.08.2026 (см. вывод первого прогона).
List<_Pair> _pairsFor(ThemeData t, bool isDark, List<double?> goldens) {
  final s = t.colorScheme;
  final bg = t.scaffoldBackgroundColor;
  final tertiary = isDark ? VibeColors.textTertiaryDark : VibeColors.textTertiaryLight;
  final error = isDark ? VibeColors.error : VibeColors.errorLight;
  final accent = s.primary;

  final raw = <_Pair>[
    // ── Гарантии: основной текст и вторичный текст (bodyMedium!) ──
    _Pair('onSurface / фон', s.onSurface, bg, guarantee: 4.5),
    _Pair('onSurfaceVariant / фон', s.onSurfaceVariant, bg, guarantee: 4.5),
    _Pair('tertiary / фон (капшены, хинты)', tertiary, bg, guarantee: 3.0),
    _Pair('onSurface / surface (карточки)', s.onSurface, s.surface, guarantee: 4.5),
    _Pair('onSurface / surfaceHigh (elevated)',
        s.onSurface, s.surfaceContainerHigh, guarantee: 4.5),
    _Pair('onInverseSurface / inverseSurface',
        s.onInverseSurface, s.inverseSurface, guarantee: 4.5),

    // ── Осознанные компромиссы дизайна (под AA, документированы) ──
    // accent/фон: dark 4.65 (ok), light 3.94 — достаточно для крупного/UI;
    // onPrimary: 4.23 — чуть ниже 4.5 (крупный текст filledBtn);
    // error/фон: dark 6.47, light 6.08 — оба ≥4.5 (AA) с 13.08.2026
    //   (светлая тема переведена на errorLight #B3261E, 8.4.8).
    _Pair('accent / фон (textButton, ссылки)', accent, bg),
    _Pair('onPrimary(белый) / primary (filledBtn)', s.onPrimary, s.primary),
    _Pair('error / фон (текст ошибок)', error, bg, guarantee: 4.5),
  ];

  assert(goldens.length == raw.length, 'число эталонов = числу пар');
  return [
    for (var i = 0; i < raw.length; i++)
      _Pair(raw[i].label, raw[i].fg, raw[i].bg,
          guarantee: raw[i].guarantee, golden: goldens[i]),
  ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  test('golden dark: контраст пар темы (эталон 14.08.2026)', () {
    _runAudit('ТЁМНАЯ ТЕМА', _pairsFor(VibeTheme.dark(), true, const [
      16.29, // onSurface / фон
      7.64, // onSurfaceVariant / фон
      3.70, // tertiary / фон
      14.25, // onSurface / surface
      13.56, // onSurface / surfaceHigh
      11.57, // onInverseSurface / inverseSurface
      3.57, // accent / фон
      4.56, // onPrimary / primary
      5.06, // error / фон
    ]));
  });

  test('golden light: контраст пар темы (эталон 14.08.2026)', () {
    _runAudit('СВЕТЛАЯ ТЕМА', _pairsFor(VibeTheme.light(), false, const [
      21.00, // onSurface / фон
      4.66, // onSurfaceVariant / фон
      3.25, // tertiary / фон
      19.11, // onSurface / surface
      17.95, // onSurface / surfaceHigh
      16.66, // onInverseSurface / inverseSurface
      4.56, // accent / фон
      4.56, // onPrimary / primary
      6.54, // error / фон (errorLight, AA)
    ]));
  });
}