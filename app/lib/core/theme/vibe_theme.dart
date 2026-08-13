import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../../data/settings_service.dart';
import 'vibe_colors.dart';
import 'vibe_spacing.dart';
import 'vibe_typography.dart';

/// Тема Vibe v2: Material 3, лестница поверхностей, стекло, свечения.
/// Акцентный цвет берётся из настроек — применяется на лету без перезапуска.
class VibeTheme {
  VibeTheme._();

  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData light() => _build(brightness: Brightness.light);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final accent = Color(SettingsService.instance.accentColorValue);
    final accentLight = Color.lerp(accent, Colors.white, 0.45)!;
    final accentDark = Color.lerp(accent, Colors.black, 0.3)!;

    final bg = isDark ? VibeColors.surface0Dark : VibeColors.surface0Light;
    final surface1 = isDark ? VibeColors.surface1Dark : VibeColors.surface1Light;
    final surface2 = isDark ? VibeColors.surface2Dark : VibeColors.surface2Light;
    final surface3 = isDark ? VibeColors.surface3Dark : VibeColors.surface3Light;
    final surface4 = isDark ? VibeColors.surface4Dark : VibeColors.surface4Light;
    final textPrimary =
        isDark ? VibeColors.textPrimaryDark : VibeColors.textPrimaryLight;
    final textSecondary =
        isDark ? VibeColors.textSecondaryDark : VibeColors.textSecondaryLight;
    final textTertiary =
        isDark ? VibeColors.textTertiaryDark : VibeColors.textTertiaryLight;

    // Ошибки: тёмная тема — яркий красный, светлая — тёмный (контраст AA).
    final errorColor = isDark ? VibeColors.error : VibeColors.errorLight;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accent.withValues(alpha: 0.18),
      onPrimaryContainer: accentLight,
      secondary: accentDark,
      onSecondary: Colors.white,
      secondaryContainer: accent.withValues(alpha: 0.28),
      onSecondaryContainer: accentLight,
      tertiary: VibeColors.workBlue,
      onTertiary: Colors.white,
      error: errorColor,
      onError: Colors.white,
      errorContainer: errorColor.withValues(alpha: 0.15),
      onErrorContainer: errorColor,
      surface: surface2,
      onSurface: textPrimary,
      surfaceContainerLowest: bg,
      surfaceContainerLow: surface1,
      surfaceContainer: surface2,
      surfaceContainerHigh: surface3,
      surfaceContainerHighest: surface4,
      onSurfaceVariant: textSecondary,
      outline: isDark ? VibeColors.borderDark : VibeColors.borderLight,
      outlineVariant: surface2,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: surface4,
      onInverseSurface: textPrimary,
      inversePrimary: accentLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          textTertiary.withValues(alpha: 0.5),
        ),
        radius: const Radius.circular(4),
        thickness: WidgetStatePropertyAll(4),
      ),
      textTheme: TextTheme(
        displayLarge: VibeTypography.display.copyWith(color: textPrimary),
        headlineMedium: VibeTypography.headline.copyWith(color: textPrimary),
        titleLarge: VibeTypography.title.copyWith(color: textPrimary),
        titleMedium: VibeTypography.subtitle.copyWith(color: textPrimary),
        bodyLarge: VibeTypography.body.copyWith(color: textPrimary),
        bodyMedium: VibeTypography.body.copyWith(color: textSecondary),
        bodySmall: VibeTypography.caption.copyWith(color: textSecondary),
        labelSmall: VibeTypography.label.copyWith(color: textSecondary),
        labelLarge: VibeTypography.button.copyWith(color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? VibeColors.bgAltDark.withValues(alpha: 0.85)
            : VibeColors.surface0Light.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: VibeTypography.subtitle.copyWith(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary, size: 24),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: accent,
          minimumSize: const Size(0, VibeSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VibeRadius.button),
          ),
          textStyle: VibeTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, VibeSizes.buttonSmall),
          side: BorderSide(color: accent.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VibeRadius.button),
          ),
          textStyle: VibeTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: VibeTypography.button.copyWith(color: accent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? VibeColors.inputBg : VibeColors.surface2Light,
        hintStyle: VibeTypography.body.copyWith(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VibeSpacing.lg,
          vertical: VibeSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VibeRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VibeRadius.input),
          borderSide: BorderSide(
            color: isDark
                ? VibeColors.borderDark.withValues(alpha: 0.8)
                : const Color(0x261C1B22),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VibeRadius.input),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VibeRadius.input),
          borderSide: BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VibeRadius.input),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.14),
        elevation: 0,
        height: VibeSizes.bottomNavHeight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return VibeTypography.label.copyWith(
            color: active ? accent : textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? accent : VibeColors.inactiveNav,
            size: VibeSizes.iconMd,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeRadius.card),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? VibeColors.surface2Dark : surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeRadius.bottomSheet),
        ),
        titleTextStyle: VibeTypography.title.copyWith(color: textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0x141C1B1F),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? VibeColors.surface3Dark : surface3,
        contentTextStyle: VibeTypography.body.copyWith(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeRadius.sm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? VibeColors.surface2Dark : surface2,
        showDragHandle: true,
        dragHandleColor: textTertiary.withValues(alpha: 0.35),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VibeRadius.bottomSheet),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: accent.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent
              : Colors.white.withValues(alpha: 0.12),
        ),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.15),
        thumbColor: Colors.white,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeRadius.card),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStatePropertyAll(accent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? VibeColors.surface3Dark : surface3,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: VibeTypography.caption.copyWith(color: textPrimary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.28),
        selectionHandleColor: accentLight,
      ),
    );
  }
}

/// Токены темы, доступные из любого места.
extension VibeContext on BuildContext {
  ColorScheme get vibeScheme => Theme.of(this).colorScheme;

  Color get vibeBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get vibeSurface => Theme.of(this).colorScheme.surface;

  Color get vibeSurfaceVariant =>
      Theme.of(this).colorScheme.surfaceContainer;

  Color get vibeSurfaceLowest =>
      Theme.of(this).colorScheme.surfaceContainerLowest;

  Color get vibeSurfaceLow => Theme.of(this).colorScheme.surfaceContainerLow;

  Color get vibeSurfaceHigh => Theme.of(this).colorScheme.surfaceContainerHigh;

  Color get vibeSurfaceElevated =>
      Theme.of(this).colorScheme.surfaceContainerHighest;

  Color get vibeTextPrimary => Theme.of(this).colorScheme.onSurface;

  Color get vibeTextSecondary => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get vibeTextTertiary => isDarkMode
      ? VibeColors.textTertiaryDark
      : VibeColors.textTertiaryLight;

  Color get vibeSurfaceHighlight => isDarkMode
      ? VibeColors.surfaceHighlightDark
      : VibeColors.surfaceHighlightLight;

  Color get vibeGlass =>
      isDarkMode ? VibeColors.glassDark : VibeColors.glassLight;

  Color get vibeGlassBorder => isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0x141C1B1F);

  /// Тень для «плавающих» стеклянных островов — мягче в светлой теме,
  /// чтобы не выглядеть чёрным грузом на белом фоне.
  BoxShadow get vibeGlassShadow => isDarkMode
      ? VibeShadows.cardDark
      : const BoxShadow(
          color: Color(0x1A4B4B66),
          blurRadius: 18,
          spreadRadius: 0,
          offset: Offset(0, 6),
        );

  Color get vibeDivider => isDarkMode
      ? Colors.white.withValues(alpha: 0.06)
      : VibeColors.dividerLight;

  Color get vibeBorder => isDarkMode
      ? VibeColors.borderDark
      : VibeColors.borderLight;

  Color get vibePrimary => Theme.of(this).colorScheme.primary;

  /// Цвет ошибок темы (тёмная тема — яркий, светлая — тёмный, AA).
  Color get vibeError => Theme.of(this).colorScheme.error;

  Color get vibeAccent => Theme.of(this).colorScheme.secondary;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Поведение скролла Vibe: упругая перетяжка вместо свечения.
class VibeScrollBehavior extends MaterialScrollBehavior {
  const VibeScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (details.direction == AxisDirection.up ||
        details.direction == AxisDirection.down) {
      return child;
    }
    return super.buildOverscrollIndicator(context, child, details);
  }
}