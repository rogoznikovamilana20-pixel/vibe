import 'package:flutter/material.dart';

/// Типографика Vibe v3 — строгая иерархия, шрифт Roboto (как в Telegram).
/// Три начертания: Regular (400), Medium (500), Bold (700).
/// Display 30-32 / H1 26-28 / H2 20-22 / Body 16 / Secondary 14-15 / Caption 12-13.
class VibeTypography {
  VibeTypography._();

  static const _roboto = 'Roboto';

  /// Крупные экранные заголовки (редко) — Bold.
  static const display = TextStyle(
    fontFamily: _roboto,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 36 / 30,
    letterSpacing: -0.4,
  );

  /// H1 — заголовки экранов — Medium.
  static const headline = TextStyle(
    fontFamily: _roboto,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    height: 32 / 26,
    letterSpacing: -0.2,
  );

  /// H2 — заголовки секций и карточек — Medium.
  static const title = TextStyle(
    fontFamily: _roboto,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 24 / 18,
  );

  /// Вторичный текст / строки списков — Medium.
  static const subtitle = TextStyle(
    fontFamily: _roboto,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 20 / 15,
  );

  /// Основной текст — Regular.
  static const body = TextStyle(
    fontFamily: _roboto,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 22 / 16,
  );

  /// Основной текст акцентный — Medium.
  static const bodyMedium = TextStyle(
    fontFamily: _roboto,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 20 / 15,
  );

  /// Подписи, метаданные — Regular.
  static const caption = TextStyle(
    fontFamily: _roboto,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  /// Подписи акцентные — Medium.
  static const captionMedium = TextStyle(
    fontFamily: _roboto,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  /// Микро-подписи (табы, бейджи) — Medium.
  static const label = TextStyle(
    fontFamily: _roboto,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 14 / 11,
    letterSpacing: 0.2,
  );

  /// Кнопки — Medium (как в Telegram).
  static const button = TextStyle(
    fontFamily: _roboto,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0.2,
  );
}
