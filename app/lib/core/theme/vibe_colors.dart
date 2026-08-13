import 'package:flutter/material.dart';

/// Цветовая палитра Vibe — строгий Telegram-стиль.
/// Акцент синий #3390EC, поверхности нейтральные без фиолетового подтона.
class VibeColors {
  VibeColors._();

  // Бренд (Telegram blue)
  static const primary = Color(0xFF3390EC); // основной accent
  static const primaryLight = Color(0xFF65ADF2);
  static const primaryDark = Color(0xFF2F7FC9);
  static const vivid = Color(0xFF3390EC); // яркий акцент (gradient end)
  static const pressed = Color(0xFF2F7FC9);
  static const variant = Color(0xFF2F7FC9);

  // Брендовые подложки (использовать дозированно)
  static const purpleSurface = Color(0xFF1C3348);
  static const purpleDeep = Color(0xFF223E57);

  // Синие
  static const workBlue = Color(0xFF3390EC);
  static const scriptBotBlue = Color(0xFF3390EC);

  // === Тёмная тема (Telegram dark) ===
  static const bgDark = Color(0xFF17212B);
  static const bgAltDark = Color(0xFF17212B);
  static const surfaceDark = Color(0xFF1F2C37); // поля, карточки
  static const surfaceVariantDark = Color(0xFF242F3D); // elevated
  static const surfaceHighlightDark = Color(0xFF263B4D); // active
  static const surfaceElevatedDark = Color(0xFF242F3D);
  static const toolbarDark = Color(0xFF17212B);
  static const bottomNavDark = Color(0xFF17212B);

  // Пузыри сообщений (тёмная тема)
  static const bubbleInDark = Color(0xFF182533);
  static const bubbleOutDark = Color(0xFF2B5278);

  // === Светлая тема (Telegram light) ===
  static const bgLight = Color(0xFFFFFFFF);
  static const surfaceVariantLight = Color(0xFFF4F4F5);
  static const surfaceHighlightLight = Color(0xFFE9E9EA);
  static const dividerLight = Color(0xFFE4E4E5);
  static const bgAltLight = Color(0xFFFFFFFF);

  // Пузыри сообщений (светлая тема)
  static const bubbleInLight = Color(0xFFFFFFFF);
  static const bubbleOutLight = Color(0xFFEFFDDE);

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

  /// Ошибки на светлой теме: контраст ≥4.5:1 на всех светлых поверхностях
  /// (AA). Тёмный вариант [error] для тёмной темы.
  static const errorLight = Color(0xFFB3261E);
  static const info = Color(0xFF3390EC);
  static const teal = Color(0xFF4DCD5E);

  // Границы
  static const borderDark = Color(0xFF2C3945);
  static const borderLight = Color(0xFFD9DDE2);

  // Компоненты (тёмная тема по умолчанию)
  static const btnSecondary = Color(0xFF242F3D);
  static const inputBg = Color(0xFF1F2C37);
  static const inputBorder = Color(0xFF2C3945);
  static const inputErrorBorder = Color(0xFFFF5147);
  static const cardDark = Color(0xFF1F2C37);
  static const iconColor = Color(0xFFA7B3BF);
  static const inactiveNav = Color(0xFF7D8B99);

  // Градиенты — дозированно (CTA, Aurion hero, selected nav), без неона
  static const brandGradient = [Color(0xFF2F7FC9), Color(0xFF3390EC)];
  static const avatarGradient = [Color(0xFF3390EC), Color(0xFF2F7FC9)];
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
  static const surface0Dark = Color(0xFF17212B); // фон
  static const surface1Dark = Color(0xFF1F2C37); // bg secondary
  static const surface2Dark = Color(0xFF1F2C37); // surface
  static const surface3Dark = Color(0xFF242F3D); // elevated
  static const surface4Dark = Color(0xFF263B4D); // active

  // === Лестница поверхностей (светлая) ===
  static const surface0Light = Color(0xFFFFFFFF);
  static const surface1Light = Color(0xFFF4F4F5);
  static const surface2Light = Color(0xFFF4F4F5);
  static const surface3Light = Color(0xFFEDEDEE);
  static const surface4Light = Color(0xFFE4E5E7);

  // Стекло (blur-панели) — нейтральное
  static const glassDark = Color(0xF217212B);
  static const glassLight = Color(0xF2FFFFFF);

  // Бейдж непрочитанных (Telegram blue)
  static const unreadBlue = Color(0xFF3390EC);

  // Онлайн-индикатор
  static const onlineGreen = Color(0xFF4DCD5E);

  // Мягкие ambient-свечения (только акценты: CTA, nav, Aurion)
  static const glowPrimary = Color(0x1A3390EC);
  static const glowVivid = Color(0x143390EC);
  static const glowBlue = Color(0x103390EC);
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
/// Сдержанная Telegram-палитра: синие/зелёные/серые пары.
class VibeAvatarGradients {
  VibeAvatarGradients._();

  static const pairs = <List<Color>>[
    [Color(0xFF3390EC), Color(0xFF2F7FC9)],
    [Color(0xFF4DCD5E), Color(0xFF3BA35A)],
    [Color(0xFF6C8EA4), Color(0xFF527DA3)],
    [Color(0xFF5778A5), Color(0xFF3E5F8F)],
    [Color(0xFF3390EC), Color(0xFF4DCD5E)],
    [Color(0xFF7D8B99), Color(0xFF5A7D9A)],
    [Color(0xFF3E5F8F), Color(0xFF3390EC)],
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
