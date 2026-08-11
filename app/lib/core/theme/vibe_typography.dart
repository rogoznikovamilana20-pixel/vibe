import 'package:flutter/material.dart';

/// Типографика Vibe v3 — строгая иерархия, шрифт Inter.
/// Display 30-32 / H1 26-28 / H2 20-22 / Body 16 / Secondary 14-15 / Caption 12-13.
class VibeTypography {
  VibeTypography._();

  static const _inter = 'Inter';

  /// Крупные экранные заголовки (редко).
  static const display = TextStyle(
    fontFamily: _inter,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 36 / 30,
    letterSpacing: -0.4,
  );

  /// H1 — заголовки экранов.
  static const headline = TextStyle(
    fontFamily: _inter,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 32 / 26,
    letterSpacing: -0.2,
  );

  /// H2 — заголовки секций и карточек.
  static const title = TextStyle(
    fontFamily: _inter,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 26 / 20,
  );

  /// Вторичный текст / строки списков.
  static const subtitle = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 20 / 15,
  );

  /// Основной текст.
  static const body = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 22 / 16,
  );

  static const bodyMedium = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 20 / 15,
  );

  /// Подписи, метаданные.
  static const caption = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  static const captionMedium = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  /// Микро-подписи (табы, бейджи).
  static const label = TextStyle(
    fontFamily: _inter,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 14 / 11,
    letterSpacing: 0.2,
  );

  static const button = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0.2,
  );
}
