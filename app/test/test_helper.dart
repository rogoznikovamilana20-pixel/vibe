// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:vibe_app/core/localization/vibe_localizations.dart';

/// Wraps a widget with MaterialApp + localization for testing.
Widget wrapWithApp(Widget child, {Locale locale = const Locale('ru')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      VibeLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ru')],
    home: Scaffold(body: child),
  );
}
