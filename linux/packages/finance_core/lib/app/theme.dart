import 'package:flutter/material.dart';

ThemeData financeTheme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  brightness: brightness,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff356859),
    brightness: brightness,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    isDense: true,
  ),
  cardTheme: const CardThemeData(elevation: 0),
  visualDensity: VisualDensity.standard,
);
