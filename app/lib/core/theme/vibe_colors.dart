import 'package:flutter/material.dart';

/// Цветовая палитра Vibe v3 — premium, calm, dark-first.
/// Фиолетовый — accent, а не заливка всего интерфейса.
class VibeColors {
  VibeColors._();

  // Бренд
  static const primary = Color(0xFF8B4DFF); // основной accent
  static const primaryLight = Color(0xFFA66BFF);
  static const primaryDark = Color(0xFF6E38D8);
  static const vivid = Color(0xFF9B55FF); // яркий акцент (gradient end)
  static const pressed = Color(0xFF6E38D8);
  static const variant = Color(0xFF6E38D8);

  // Брендовые подложки (использовать дозированно)
  static const purpleSurface = Color(0xFF241441);
  static const purpleDeep = Color(0xFF2A1A4A);

  // Синие
  static const workBlue = Color(0xFF4DA3FF);
  static const scriptBotBlue = Color(0xFF4DA3FF);

  // === Тёмная тема ===
  static const bgDark = Color(0xFF0B0917);
  static const bgAltDark = Color(0xFF0F0D1D);
  static const surfaceDark = Color(0xFF151329);
  static const surfaceVariantDark = Color(0xFF1B1835); // elevated
  static const surfaceHighlightDark = Color(0xFF211C40); // active
  static const surfaceElevatedDark = Color(0xFF1B1835);
  static const toolbarDark = Color(0xFF0F0D1D);
  static const bottomNavDark = Color(0xFF0F0D1D);

  // === Светлая тема ===
  static const bgLight = Color(0xFFF7F6FB);
  static const surfaceVariantLight = Color(0xFFEFEDF7);
  static const surfaceHighlightLight = Color(0xFFE3DFF3);
  static const dividerLight = Color(0xFFE5E1F1);
  static const bgAltLight = Color(0xFFF0EEF8);

  // Текст
  static const textPrimaryDark = Color(0xFFF5F3FA);
  static const textSecondaryDark = Color(0xFF9C98AE);
  static const textTertiaryDark = Color(0xFF6E6A7D);
  static const textPrimaryLight = Color(0xFF1C1B22);
  static const textSecondaryLight = Color(0xFF52505C);
  static const textTertiaryLight = Color(0xFF797585);

  // Семантика
  static const success = Color(0xFF45D483);
  static const warning = Color(0xFFF5B942);
  static const warningGlow = Color(0xFFF5B942);
  static const error = Color(0xFFFF5A64);

  /// Ошибки на светлой теме: контраст ≥4.5:1 на всех светлых поверхностях
  /// (AA). Тёмный вариант [error] для тёмной темы.
  static const errorLight = Color(0xFFB3261E);
  static const info = Color(0xFF4DA3FF);
  static const teal = Color(0xFF45D483);

  // Границы
  static const borderDark = Color(0xFF2A2645);
  static const borderLight = Color(0xFFE5E1F1);

  // Компоненты (тёмная тема по умолчанию)
  static const btnSecondary = Color(0xFF1B1835);
  static const inputBg = Color(0xFF151329);
  static const inputBorder = Color(0xFF2A2645);
  static const inputErrorBorder = Color(0xFFFF5A64);
  static const cardDark = Color(0xFF151329);
  static const iconColor = Color(0xFF9C98AE);
  static const inactiveNav = Color(0xFF6E6A7D);

  // Градиенты — дозированно (CTA, Aurion hero, selected nav)
  static const brandGradient = [Color(0xFF6E38D8), Color(0xFF9B55FF)];
  static const avatarGradient = [Color(0xFF9B55FF), Color(0xFF6E38D8)];
  static const aurionGradient = [Color(0xFF1B1835), Color(0xFF241441)];
  static const confettiPalette = [
    primary,
    primaryLight,
    workBlue,
    success,
    warningGlow,
    error,
    teal,
  ];

  // === Лестница поверхностей (тёмная) ===
  static const surface0Dark = Color(0xFF0B0917); // фон
  static const surface1Dark = Color(0xFF0F0D1D); // bg secondary
  static const surface2Dark = Color(0xFF151329); // surface
  static const surface3Dark = Color(0xFF1B1835); // elevated
  static const surface4Dark = Color(0xFF211C40); // active

  // === Лестница поверхностей (светлая) ===
  static const surface0Light = Color(0xFFF7F6FB);
  static const surface1Light = Color(0xFFF0EEF8);
  static const surface2Light = Color(0xFFE9E7F5);
  static const surface3Light = Color(0xFFDFDBF1);
  static const surface4Light = Color(0xFFD3CDEA);

  // Стекло (blur-панели) — нейтральное, без фиолетового подтона
  static const glassDark = Color(0xE614121E);
  static const glassLight = Color(0xE6F4F2FA);

  // Синий непрочитанных
  static const unreadBlue = Color(0xFF4DA3FF);

  // Онлайн-индикатор
  static const onlineGreen = Color(0xFF45D483);

  // Мягкие ambient-свечения (только акценты: CTA, nav, Aurion)
  static const glowPrimary = Color(0x1A8B4DFF);
  static const glowVivid = Color(0x148B4DFF);
  static const glowBlue = Color(0x104DA3FF);
}

/// Тени и свечения дизайн-системы v3.
/// Dark theme: поверхностный контраст + subtle border вместо массивных теней.
class VibeShadows {
  VibeShadows._();

  /// Мягкое ambient-свечение акцента (primary CTA, active nav).
  static const glowPrimary = BoxShadow(
    color: Color(0x1A8B4DFF),
    blurRadius: 16,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );

  /// Усиленное свечение для крупных CTA.
  static const glowStrong = BoxShadow(
    color: Color(0x208B4DFF),
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 8),
  );

  /// Карточка: мягкая тень, почти незаметная в тёмной теме.
  static const cardDark = BoxShadow(
    color: Color(0x22000000),
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 10),
  );

  /// Всплывающий элемент (bottomsheet, menu).
  static const floating = BoxShadow(
    color: Color(0x30000000),
    blurRadius: 32,
    spreadRadius: 0,
    offset: Offset(0, 14),
  );
}

/// Радиусы blur для стеклянных панелей.
class VibeBlur {
  VibeBlur._();

  static const nav = 24.0;
  static const panel = 32.0;
  static const sheet = 40.0;
}

/// Единая градиентная схема аватарок — без «каждому свой рандомный градиент».
class VibeAvatarGradients {
  VibeAvatarGradients._();

  static const pairs = <List<Color>>[
    [Color(0xFF9B55FF), Color(0xFF6E38D8)],
    [Color(0xFF6E38D8), Color(0xFF4DA3FF)],
    [Color(0xFF4DA3FF), Color(0xFF45D483)],
    [Color(0xFF6E38D8), Color(0xFF9B55FF)],
    [Color(0xFF9B55FF), Color(0xFF4DA3FF)],
    [Color(0xFF6E38D8), Color(0xFF45D483)],
    [Color(0xFF4DA3FF), Color(0xFF6E38D8)],
    [Color(0xFF9B55FF), Color(0xFF45D483)],
  ];

  static List<Color> forName(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return pairs[hash % pairs.length];
  }
}
