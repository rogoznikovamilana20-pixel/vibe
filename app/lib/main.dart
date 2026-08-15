import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/scheduled_service.dart';
import 'core/env_config.dart';
import 'core/profile_avatar.dart';
import 'core/theme/vibe_theme.dart';
import 'core/localization/vibe_localizations.dart';
import 'data/backend.dart';
import 'data/settings_service.dart';
import 'data/passcode_service.dart';
import 'screens/splash_screen.dart';
import 'screens/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  if (!EnvConfig.isReady) {
    throw EnvConfig.missingError();
  }
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );

  await SettingsService.instance.init();
  await PasscodeService.instance.init();
  await ProfileAvatar.load();
  await ScheduledService.instance.init();

  // Временный E2E-хелпер: позволяет установить PIN без UI-навигации.
  const e2ePin = String.fromEnvironment('E2E_PIN');
  if (e2ePin.isNotEmpty) {
    if (PasscodeService.instance.hasPasscode) {
      debugPrint('[e2e] PIN уже установлен');
    } else {
      await PasscodeService.instance.setPasscode(e2ePin);
      debugPrint('[e2e] PIN установлен: $e2ePin');
    }
  }
  
  final initialTheme = SettingsService.instance.themeMode;
  VibeApp.themeModeNotifier.value = initialTheme;
  VibeApp.localeNotifier.value = Locale(SettingsService.instance.languageCode);

  SystemChrome.setSystemUIOverlayStyle(
    _overlayFor(initialTheme),
  );
  
  runApp(const VibeApp());
  // 5.9: облачное зеркало приватности (3.7) — фоновая догонялка уже
  // после первого кадра: локальный кеш готов ещё до runApp, серверная
  // перезапись не должна тянуть сплэш (best-effort, сеть может висеть).
  unawaited(SettingsService.instance.loadPrivacyFromServer());
}

class VibeApp extends StatefulWidget {
  const VibeApp({super.key});

  static final themeModeNotifier = ValueNotifier(ThemeMode.dark);
  static final localeNotifier = ValueNotifier(const Locale('ru'));

  @override
  State<VibeApp> createState() => _VibeAppState();
}

SystemUiOverlayStyle _overlayFor(ThemeMode mode) {
  final isDark = mode != ThemeMode.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isDark ? const Color(0xFF0C0B1A) : const Color(0xFFFFFFFF),
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  );
}

class _VibeAppState extends State<VibeApp> with WidgetsBindingObserver {
  static final _navigatorKey = GlobalKey<NavigatorState>();
  bool _lockPushed = false;
  Timer? _autoNightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyAutoNight();
    _autoNightTimer = Timer.periodic(const Duration(minutes: 5), (_) => _applyAutoNight());
  }

  @override
  void dispose() {
    _autoNightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _applyAutoNight() {
    final s = SettingsService.instance;
    if (!s.autoNightEnabled) return;
    final shouldBeDark = s.shouldUseDarkBySchedule;
    final currentMode = VibeApp.themeModeNotifier.value;
    final targetMode = shouldBeDark ? ThemeMode.dark : ThemeMode.light;
    if (currentMode != targetMode) {
      VibeApp.themeModeNotifier.value = targetMode;
      SystemChrome.setSystemUIOverlayStyle(_overlayFor(targetMode));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Честные онлайн-статусы: сворачивание — «не в сети», возврат — снова.
    final backend = VibeBackend.instance;
    switch (state) {
      case AppLifecycleState.resumed:
        backend.setOnline(true);
        backend.startPresence();
        _maybeLockOnResume();
        _applyAutoNight();
        // Обработать очередь офлайн-отправки и восстановить пропущенные события.
        unawaited(backend.processOfflineQueueOnResume());
        unawaited(backend.recoverMissedEvents());
      case AppLifecycleState.paused:
        PasscodeService.instance.onAppPaused();
        _lockPushed = false;
        backend.setOnline(false);
      case AppLifecycleState.detached:
        backend.setOnline(false);
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _maybeLockOnResume() async {
    if (_lockPushed) return;
    if (!await PasscodeService.instance.shouldLockOnResume()) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    _lockPushed = true;
    navigator.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => const LockScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: VibeApp.themeModeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: VibeApp.localeNotifier,
          builder: (context, locale, _) {
            return ValueListenableBuilder<int>(
              valueListenable: SettingsService.instance.accentVersion,
              builder: (context, _, _) {
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: _overlayFor(mode),
                  child: MaterialApp(
                    title: 'Vibe',
                    debugShowCheckedModeBanner: false,
                    theme: VibeTheme.light(),
                    darkTheme: VibeTheme.dark(),
                    themeMode: mode,
                    locale: locale,
                    localizationsDelegates: const [
                      VibeLocalizationsDelegate(),
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [
                      Locale('ru'),
                      Locale('en'),
                    ],
                    scrollBehavior: const VibeScrollBehavior(),
                    navigatorKey: _navigatorKey,
                    home: const SplashScreen(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}