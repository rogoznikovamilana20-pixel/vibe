import 'package:flutter/material.dart';

/// Кривые и длительности анимаций Vibe v3.
/// Micro-interactions: 120-220ms. Screen transitions: 250-400ms.
class VibeAnimations {
  VibeAnimations._();

  static const micro = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 150);
  static const fadeIn = Duration(milliseconds: 200);
  static const pulse = Duration(milliseconds: 200);
  static const scaleIn = Duration(milliseconds: 220);
  static const slideUp = Duration(milliseconds: 300);
  static const fluid = Duration(milliseconds: 350);
  static const shake = Duration(milliseconds: 500);

  static const easeOut = Curves.easeOut;
  static const overshootSoft = Curves.easeOutBack;
  static const pulseEasing = Curves.easeInOut;

  /// Ультра-гладкая кривая для навигации.
  static const fluidCurve = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Стандартная кривая для появления элементов.
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Мягкое появление карточек и пузырей (без excessive bounce).
  static const springy = Cubic(0.22, 1.15, 0.36, 1.0);
}
