import 'package:flutter/material.dart';

import 'design/tokens.dart';

/// Tema aplikasi dibangun dari design tokens (lihat `design/tokens.dart`).
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFC65320),
    brightness: brightness,
  ).copyWith(
    primaryContainer: dark ? const Color(0xFF5C2A12) : const Color(0xFFFFE2D2),
    onPrimaryContainer: dark ? const Color(0xFFFFDBCA) : const Color(0xFF54220A),
    secondary: dark ? const Color(0xFFFFD27A) : const Color(0xFF805400),
    onSecondary: dark ? const Color(0xFF3B2600) : const Color(0xFFFFFFFF),
    secondaryContainer: dark ? const Color(0xFF5B3D12) : const Color(0xFFFFE8B0),
    onSecondaryContainer: dark ? const Color(0xFFFFE9C0) : const Color(0xFF442C00),
    surface: dark ? const Color(0xFF171411) : const Color(0xFFFFF8F0),
    surfaceContainerLow: dark ? const Color(0xFF211B17) : const Color(0xFFFFFFFF),
    surfaceContainer: dark ? const Color(0xFF2B231F) : const Color(0xFFFFF1E4),
    surfaceContainerHigh: dark ? const Color(0xFF382C25) : const Color(0xFFFFE7D3),
    outlineVariant: dark ? const Color(0xFF51443B) : const Color(0xFFE8D9CC),
  );

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
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    }),
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
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
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
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: AppElevation.raised,
      shape: shape,
    ),
  );
}
