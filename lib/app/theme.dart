import 'package:flutter/material.dart';

import 'design/tokens.dart';

/// Tema aplikasi dibangun dari design tokens (lihat `design/tokens.dart`).
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B5F55),
    brightness: brightness,
  ).copyWith(
    // Permukaan sedikit lebih hangat/netral agar kartu terpisah tanpa border tebal.
    surface: dark ? const Color(0xFF111615) : const Color(0xFFF7F8F6),
    surfaceContainerLow: dark ? const Color(0xFF181E1D) : const Color(0xFFFFFFFF),
    surfaceContainer: dark ? const Color(0xFF1D2423) : const Color(0xFFF0F2EF),
    surfaceContainerHigh: dark ? const Color(0xFF242C2B) : const Color(0xFFE8EBE7),
    outlineVariant: dark ? const Color(0xFF39423F) : const Color(0xFFDDE1DC),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
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
