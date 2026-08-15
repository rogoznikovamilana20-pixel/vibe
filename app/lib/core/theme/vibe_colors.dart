import 'package:flutter/material.dart';

/// Цветовая палитра Vibe — фирменный фиолетовый.
/// Акцент #8B4DFF, поверхности нейтральные с фиолетовым подтоном.
class VibeColors {
  VibeColors._();

  // Бренд (Vibe Purple)
  static const primary = Color(0xFF8B4DFF);
  static const primaryLight = Color(0xFFA87AFF);
  static const primaryDark = Color(0xFF6B3FCC);
  static const vivid = Color(0xFF9B6BFF);
  static const pressed = Color(0xFF6B3FCC);
  static const variant = Color(0xFF7B45E6);

  // Брендовые подложки
  static const purpleSurface = Color(0xFF1C2848);
  static const purpleDeep = Color(0xFF223457);

  // Синие (оставляем для обратной совместимости)
  static const workBlue = Color(0xFF8B4DFF);
  static const scriptBotBlue = Color(0xFF8B4DFF);

  // === Тёмная тема ===
  static const bgDark = Color(0xFF17212B);
  static const bgAltDark = Color(0xFF17212B);
  static const surfaceDark = Color(0xFF1F2C37);
  static const surfaceVariantDark = Color(0xFF242F3D);
  static const surfaceHighlightDark = Color(0xFF263B4D);
  static const surfaceElevatedDark = Color(0xFF242F3D);
  static const toolbarDark = Color(0xFF17212B);
  static const bottomNavDark = Color(0xFF17212B);

  // Пузыри сообщений (тёмная тема)
  static const bubbleInDark = Color(0xFF182533);
  static const bubbleOutDark = Color(0xFF2D2B5E);

  // === Светлая тема ===
  static const bgLight = Color(0xFFFFFFFF);
  static const surfaceVariantLight = Color(0xFFF4F4F5);
  static const surfaceHighlightLight = Color(0xFFE9E9EA);
  static const dividerLight = Color(0xFFE4E4E5);
  static const bgAltLight = Color(0xFFFFFFFF);

  // Пузыри сообщений (светлая тема)
  static const bubbleInLight = Color(0xFFFFFFFF);
  static const bubbleOutLight = Color(0xFFF0EAFF);

  // Текст
  static const textPrimaryDark = Color(0xFFFFFFFF);
  static const textSecondaryDark = Color(0xFFA7B3BF);
  static const textTertiaryDark = Color(0xFF6C7A86);
  static const textPrimaryLight = Color(0xFF000000);
  static const textSecondaryLight = Color(0xFF707579);
  static const textTertiaryLight = Color(0xFF8B8F96);

  // Семантика
  static const success = Color(0xFF4DCD5E);
  static const warning = Color(0xFFF5A623);
  static const warningGlow = Color(0xFFF5A623);
  static const error = Color(0xFFFF5147);
  static const errorLight = Color(0xFFB3261E);
  static const info = Color(0xFF8B4DFF);
  static const teal = Color(0xFF4DCD5E);

  // Границы
  static const borderDark = Color(0xFF2C3945);
  static const borderLight = Color(0xFFD9DDE2);

  // Компоненты
  static const btnSecondary = Color(0xFF242F3D);
  static const inputBg = Color(0xFF1F2C37);
  static const inputBorder = Color(0xFF2C3945);
  static const inputErrorBorder = Color(0xFFFF5147);
  static const cardDark = Color(0xFF1F2C37);
  static const iconColor = Color(0xFFA7B3BF);
  static const inactiveNav = Color(0xFF7D8B99);

  // Градиенты
  static const brandGradient = [Color(0xFF6B3FCC), Color(0xFF8B4DFF)];
  static const avatarGradient = [Color(0xFF8B4DFF), Color(0xFF6B3FCC)];
  static const aurionGradient = [Color(0xFF1F2C37), Color(0xFF242F3D)];
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
  static const surface0Dark = Color(0xFF17212B);
  static const surface1Dark = Color(0xFF1F2C37);
  static const surface2Dark = Color(0xFF1F2C37);
  static const surface3Dark = Color(0xFF242F3D);
  static const surface4Dark = Color(0xFF263B4D);

  // === Лестница поверхностей (светлая) ===
  static const surface0Light = Color(0xFFFFFFFF);
  static const surface1Light = Color(0xFFF4F4F5);
  static const surface2Light = Color(0xFFF4F4F5);
  static const surface3Light = Color(0xFFEDEDEE);
  static const surface4Light = Color(0xFFE4E5E7);

  // Стекло
  static const glassDark = Color(0xF217212B);
  static const glassLight = Color(0xF2FFFFFF);

  // Бейдж непрочитанных
  static const unreadBlue = Color(0xFF8B4DFF);

  // Онлайн-индикатор
  static const onlineGreen = Color(0xFF4DCD5E);

  // Цвет ссылок в исходящих пузырях
  static const outgoingLink = Color(0xFF8FC8FF);

  // Приглушённый текст (light theme)
  static const mutedTextLight = Color(0xFF5A5766);

  // Статус сообщений
  static const statusRead = Color(0xFF8AB4F8);
  static const statusFailed = Color(0xFFFF6B6B);

  // Мягкие ambient-свечения
  static const glowPrimary = Color(0x1A8B4DFF);
  static const glowVivid = Color(0x148B4DFF);
  static const glowBlue = Color(0x108B4DFF);
}

/// Тени и свечения дизайн-системы v3.
class VibeShadows {
  VibeShadows._();

  static const glowPrimary = BoxShadow(
    color: Color(0x1A8B4DFF),
    blurRadius: 16,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );

  static const glowStrong = BoxShadow(
    color: Color(0x208B4DFF),
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 8),
  );

  static const cardDark = BoxShadow(
    color: Color(0x22000000),
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 10),
  );

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

/// Единая градиентная схема аватарок — фиолетовая палитра.
class VibeAvatarGradients {
  VibeAvatarGradients._();

  static const pairs = <List<Color>>[
    [Color(0xFF8B4DFF), Color(0xFF6B3FCC)],
    [Color(0xFF9B6BFF), Color(0xFF7B45E6)],
    [Color(0xFF6C8EA4), Color(0xFF527DA3)],
    [Color(0xFF5778A5), Color(0xFF3E5F8F)],
    [Color(0xFF8B4DFF), Color(0xFF4DCD5E)],
    [Color(0xFF7D8B99), Color(0xFF5A7D9A)],
    [Color(0xFF3E5F8F), Color(0xFF8B4DFF)],
    [Color(0xFF527DA3), Color(0xFF4DCD5E)],
  ];

  static List<Color> forName(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return pairs[hash % pairs.length];
  }
}
