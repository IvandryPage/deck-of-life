import 'package:flutter/material.dart';

/// Design tokens terpusat. Semua nilai visual berasal dari sini; halaman dan
/// komponen tidak boleh memakai angka/warna "ajaib".
///
/// Warm, student-friendly surfaces with Saweria-inspired orange and gold accents.

// ---------------------------------------------------------------------------
// Spacing (kelipatan 4)
// ---------------------------------------------------------------------------
abstract class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Margin horizontal halaman.
  static const double gutter = 16;

  /// Ruang bawah daftar agar tidak tertutup FAB / bottom nav.
  static const double listBottom = 96;
}

// ---------------------------------------------------------------------------
// Radius
// ---------------------------------------------------------------------------
abstract class AppRadius {
  static const double sm = 8; // chip, tag
  static const double md = 12; // input, tombol, baris
  static const double lg = 20; // cards and sheets
  static const double xl = 28; // sheet atas

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get control => BorderRadius.circular(md);
  static BorderRadius get tag => BorderRadius.circular(sm);
}

// ---------------------------------------------------------------------------
// Ukuran komponen & ikon
// ---------------------------------------------------------------------------
abstract class AppSize {
  /// Target sentuh minimum untuk kontrol utama.
  static const double tap = 48;
  static const double navBarHeight = 68;
  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double avatarIcon = 40;
  static const double calendarCell = 44;
  static const double maxContentWidth = 640; // layar lebar: konten tidak melebar
}

// ---------------------------------------------------------------------------
// Elevasi: sengaja minimal. Pemisahan lewat warna permukaan, bukan bayangan.
// ---------------------------------------------------------------------------
abstract class AppElevation {
  static const double none = 0;
  static const double raised = 1; // kartu penting
  static const double overlay = 3; // sheet, menu
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------
abstract class AppMotion {
  /// Mikro-interaksi: tekan tombol, centang.
  static const Duration micro = Duration(milliseconds: 140);

  /// Transisi standar: ganti filter, expand/collapse, muncul konten.
  static const Duration standard = Duration(milliseconds: 220);

  /// Transisi bertekanan: perpindahan halaman, sheet.
  static const Duration emphasized = Duration(milliseconds: 300);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standardCurve = Curves.easeInOutCubic;

  /// Hormati pengaturan "reduce motion"/"remove animations" sistem.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

// ---------------------------------------------------------------------------
// Typography uses the bundled Nunito font and tabular figures for money.
// ---------------------------------------------------------------------------
abstract class AppText {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme build(TextTheme base, Color onSurface) {
    TextStyle s(TextStyle? b, double size, FontWeight w,
            {double? height, double? spacing}) =>
        (b ?? const TextStyle()).copyWith(
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: spacing,
          color: onSurface,
        );
    return base.copyWith(
      // Angka hero (saldo)
      displaySmall: s(base.displaySmall, 34, FontWeight.w700, height: 1.1, spacing: -0.5),
      headlineMedium: s(base.headlineMedium, 26, FontWeight.w700, height: 1.2, spacing: -0.3),
      headlineSmall: s(base.headlineSmall, 22, FontWeight.w700, height: 1.25),
      titleLarge: s(base.titleLarge, 20, FontWeight.w600, height: 1.3),
      titleMedium: s(base.titleMedium, 16, FontWeight.w600, height: 1.35),
      titleSmall: s(base.titleSmall, 14, FontWeight.w600, height: 1.35),
      bodyLarge: s(base.bodyLarge, 16, FontWeight.w400, height: 1.45),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w400, height: 1.45),
      // Minimum 12sp: tidak ada teks lebih kecil dari ini.
      bodySmall: s(base.bodySmall, 13, FontWeight.w400, height: 1.4),
      labelLarge: s(base.labelLarge, 14, FontWeight.w600, height: 1.2),
      labelMedium: s(base.labelMedium, 13, FontWeight.w600, height: 1.2),
      labelSmall: s(base.labelSmall, 13, FontWeight.w600, height: 1.2),
    );
  }
}

// ---------------------------------------------------------------------------
// Warna semantik di luar ColorScheme (light & dark seimbang kontrasnya).
// ---------------------------------------------------------------------------
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.income,
    required this.incomeContainer,
    required this.expense,
    required this.expenseContainer,
    required this.warning,
    required this.warningContainer,
    required this.success,
    required this.urgent,
  });

  final Color income;
  final Color incomeContainer;
  final Color expense;
  final Color expenseContainer;
  final Color warning;
  final Color warningContainer;
  final Color success;
  final Color urgent;

  static const light = AppSemanticColors(
    income: Color(0xFF14724A),
    incomeContainer: Color(0xFFD7F0E3),
    expense: Color(0xFFB3261E),
    expenseContainer: Color(0xFFFBE0DD),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFFEBC2),
    success: Color(0xFF14724A),
    urgent: Color(0xFFB3261E),
  );

  static const dark = AppSemanticColors(
    income: Color(0xFF7FD6A8),
    incomeContainer: Color(0xFF123D2B),
    expense: Color(0xFFFFB4AB),
    expenseContainer: Color(0xFF5A1C17),
    warning: Color(0xFFFFCB66),
    warningContainer: Color(0xFF4A3300),
    success: Color(0xFF7FD6A8),
    urgent: Color(0xFFFFB4AB),
  );

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? incomeContainer,
    Color? expense,
    Color? expenseContainer,
    Color? warning,
    Color? warningContainer,
    Color? success,
    Color? urgent,
  }) =>
      AppSemanticColors(
        income: income ?? this.income,
        incomeContainer: incomeContainer ?? this.incomeContainer,
        expense: expense ?? this.expense,
        expenseContainer: expenseContainer ?? this.expenseContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        success: success ?? this.success,
        urgent: urgent ?? this.urgent,
      );

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseContainer: Color.lerp(expenseContainer, other.expenseContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppSemanticColors.dark
          : AppSemanticColors.light);
}
