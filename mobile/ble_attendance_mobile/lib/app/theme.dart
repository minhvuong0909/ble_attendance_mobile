import 'package:flutter/material.dart';

const _seed = Color(0xFF0B6E4F);

ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final dark = brightness == Brightness.dark;
  final radius = BorderRadius.circular(14);
  final outline = scheme.outlineVariant;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? scheme.surface
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.03),
            scheme.surface,
          ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: outline),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    popupMenuTheme: PopupMenuThemeData(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: outline),
    ),
    dividerTheme: DividerThemeData(color: outline, space: 1),
  );
}

ThemeData buildLightTheme() => _build(Brightness.light);
ThemeData buildDarkTheme() => _build(Brightness.dark);
