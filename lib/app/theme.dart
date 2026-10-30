import 'package:flutter/material.dart';

import 'design/tokens.dart';

/// Tema aplikasi dibangun dari design tokens (lihat `design/tokens.dart`).
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = _buildScheme(brightness);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Nunito',
  );
  final text = AppText.build(base.textTheme, scheme.onSurface);
  final shape = RoundedRectangleBorder(borderRadius: AppRadius.control);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [dark ? AppSemanticColors.dark : AppSemanticColors.light],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: AppElevation.none,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(AppSize.tap, AppSize.tap),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(AppSize.tap, AppSize.tap),
        shape: shape,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppSize.tap, AppSize.tap),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      labelStyle: text.labelLarge,
      showCheckmark: false,
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: AppSpace.sm,
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.lg),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.navBarHeight,
      elevation: AppElevation.none,
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: AppElevation.raised,
      shape: shape,
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
    ),
  );
}

/// Warm, cheerful palette. Primary is a rich orange for readable contrast,
/// secondary is Saweria-style gold, and tertiary is a fresh teal for balance.
ColorScheme _buildScheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ColorScheme.fromSeed(
    seedColor: const Color(0xFFC2451A),
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFFFFB59B) : const Color(0xFFC2451A),
    onPrimary: dark ? const Color(0xFF552006) : const Color(0xFFFFFFFF),
    primaryContainer: dark ? const Color(0xFF7A2E10) : const Color(0xFFFFDBC9),
    onPrimaryContainer: dark
        ? const Color(0xFFFFDBC9)
        : const Color(0xFF3E1400),
    secondary: dark ? const Color(0xFFFFD27A) : const Color(0xFFF3A522),
    onSecondary: dark ? const Color(0xFF412D00) : const Color(0xFF3E2A00),
    secondaryContainer: dark
        ? const Color(0xFF5A4100)
        : const Color(0xFFFFE7B0),
    onSecondaryContainer: dark
        ? const Color(0xFFFFE3A8)
        : const Color(0xFF4A2E00),
    tertiary: dark ? const Color(0xFF7ADBCB) : const Color(0xFF0E7C74),
    onTertiary: dark ? const Color(0xFF003731) : const Color(0xFFFFFFFF),
    tertiaryContainer: dark ? const Color(0xFF005048) : const Color(0xFFC8F2E8),
    onTertiaryContainer: dark
        ? const Color(0xFF9BF8E7)
        : const Color(0xFF04342C),
    error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFC0392B),
    onError: dark ? const Color(0xFF690005) : const Color(0xFFFFFFFF),
    errorContainer: dark ? const Color(0xFF93000A) : const Color(0xFFFFDAD4),
    onErrorContainer: dark ? const Color(0xFFFFDAD6) : const Color(0xFF410002),
    surface: dark ? const Color(0xFF17120F) : const Color(0xFFFFF8F0),
    onSurface: dark ? const Color(0xFFF2E1D6) : const Color(0xFF241A12),
    onSurfaceVariant: dark ? const Color(0xFFD8C2B4) : const Color(0xFF6B5A4E),
    surfaceDim: dark ? const Color(0xFF17120F) : const Color(0xFFF3E3D4),
    surfaceBright: dark ? const Color(0xFF3E3129) : const Color(0xFFFFFFFF),
    surfaceContainerLowest: dark
        ? const Color(0xFF100C0A)
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: dark
        ? const Color(0xFF1F1815)
        : const Color(0xFFFFFFFF),
    surfaceContainer: dark ? const Color(0xFF2A211C) : const Color(0xFFFFF1E3),
    surfaceContainerHigh: dark
        ? const Color(0xFF362A23)
        : const Color(0xFFFCE4CF),
    surfaceContainerHighest: dark
        ? const Color(0xFF43352C)
        : const Color(0xFFF7D9BE),
    outline: dark ? const Color(0xFFA08D80) : const Color(0xFF8C7A6B),
    outlineVariant: dark ? const Color(0xFF51443B) : const Color(0xFFE9D9C9),
    inverseSurface: dark ? const Color(0xFFF2E1D6) : const Color(0xFF3A2E25),
    onInverseSurface: dark ? const Color(0xFF3A2E25) : const Color(0xFFFFEDE0),
    inversePrimary: dark ? const Color(0xFFC2451A) : const Color(0xFFFFB59B),
    surfaceTint: dark ? const Color(0xFFFFB59B) : const Color(0xFFC2451A),
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
  );
}
