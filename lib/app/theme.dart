import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// AutoRent design system — "Midnight & Sunset" palette.
///
/// A deep navy ink paired with a warm sunset orange, soft grey surfaces,
/// generous radii and the Poppins type family.
class AppColors {
  AppColors._();

  // Brand
  static const brand = Color(0xFFFF6B2C);
  static const brandDark = Color(0xFFE5551A);
  static const brandSoft = Color(0xFFFFE6DA);

  // Ink (navy)
  static const ink = Color(0xFF0E1726);
  static const ink2 = Color(0xFF1C2638);
  static const ink3 = Color(0xFF2A3650);

  // Neutrals (light)
  static const background = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFEFF2F7);
  static const border = Color(0xFFE5E8EF);
  static const muted = Color(0xFF6B7385);

  // Neutrals (dark)
  static const backgroundDark = Color(0xFF0A0F1A);
  static const surfaceDark = Color(0xFF141C2A);
  static const surfaceAltDark = Color(0xFF1C2536);
  static const borderDark = Color(0xFF263045);
  static const mutedDark = Color(0xFF94A0B8);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const info = Color(0xFF2563EB);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const violet = Color(0xFF7C3AED);
  static const teal = Color(0xFF0D9488);

  /// Hero gradient used by headers, splash and login.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, ink3],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A4C), brand, brandDark],
  );

  /// Pleasant gradients for vehicles without photos, picked by a stable hash.
  static const carGradients = <List<Color>>[
    [Color(0xFFFFD6C2), Color(0xFFFFB38A)],
    [Color(0xFFCFE0FF), Color(0xFF9DBBFF)],
    [Color(0xFFD5F5E3), Color(0xFF9FE3BD)],
    [Color(0xFFE9DDFF), Color(0xFFC6B0FF)],
    [Color(0xFFFFE9B3), Color(0xFFFFD36B)],
    [Color(0xFFD3F1F4), Color(0xFF95DCE4)],
  ];
}

/// Extra semantic colours that follow light / dark mode.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color muted;
  final Color border;
  final Color surfaceAlt;
  final Color cardShadow;

  const AppPalette({
    required this.muted,
    required this.border,
    required this.surfaceAlt,
    required this.cardShadow,
  });

  static const light = AppPalette(
    muted: AppColors.muted,
    border: AppColors.border,
    surfaceAlt: AppColors.surfaceAlt,
    cardShadow: Color(0x140E1726),
  );

  static const dark = AppPalette(
    muted: AppColors.mutedDark,
    border: AppColors.borderDark,
    surfaceAlt: AppColors.surfaceAltDark,
    cardShadow: Color(0x66000000),
  );

  @override
  AppPalette copyWith({
    Color? muted,
    Color? border,
    Color? surfaceAlt,
    Color? cardShadow,
  }) =>
      AppPalette(
        muted: muted ?? this.muted,
        border: border ?? this.border,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        cardShadow: cardShadow ?? this.cardShadow,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

const _font = 'Poppins';

ThemeData buildTheme() => _build(Brightness.light);
ThemeData buildDarkTheme() => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final palette = dark ? AppPalette.dark : AppPalette.light;

  final background = dark ? AppColors.backgroundDark : AppColors.background;
  final surface = dark ? AppColors.surfaceDark : AppColors.surface;
  final onSurface = dark ? const Color(0xFFE9EDF5) : AppColors.ink;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.brand,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0xFF4A2414) : AppColors.brandSoft,
    onPrimaryContainer: dark ? const Color(0xFFFFD2BD) : AppColors.brandDark,
    secondary: dark ? const Color(0xFF8FA3C8) : AppColors.ink,
    onSecondary: Colors.white,
    tertiary: AppColors.info,
    error: AppColors.danger,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: palette.muted,
    surfaceContainerLowest: surface,
    surfaceContainerLow: dark ? const Color(0xFF111827) : const Color(0xFFF8F9FC),
    surfaceContainer: palette.surfaceAlt,
    surfaceContainerHigh: palette.surfaceAlt,
    surfaceContainerHighest: palette.surfaceAlt,
    outline: palette.muted,
    outlineVariant: palette.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _font,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    extensions: [palette],
  );

  final text = base.textTheme
      .copyWith(
        displaySmall: base.textTheme.displaySmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineLarge: base.textTheme.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontSize: 19, fontWeight: FontWeight.w600),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
        titleSmall: base.textTheme.titleSmall
            ?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 15),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13.5),
        bodySmall: base.textTheme.bodySmall
            ?.copyWith(fontSize: 12, color: palette.muted),
        labelLarge: base.textTheme.labelLarge
            ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: base.textTheme.labelMedium
            ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: base.textTheme.labelSmall
            ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
      )
      .apply(
        fontFamily: _font,
        bodyColor: onSurface,
        displayColor: onSurface,
      );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: palette.border),
  );

  return base.copyWith(
    textTheme: text,
    // Native-feeling slide transitions (with swipe-back) on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: onSurface),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: palette.border.withValues(alpha: 0.7)),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: dark ? AppColors.surfaceAltDark : const Color(0xFFF6F7FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6)),
      errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6)),
      labelStyle: TextStyle(color: palette.muted, fontSize: 14),
      floatingLabelStyle:
          const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: palette.muted, fontSize: 14),
      prefixIconColor: palette.muted,
      suffixIconColor: palette.muted,
      errorStyle: const TextStyle(fontSize: 11.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 54),
        elevation: 0,
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: palette.border,
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md + 2)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md + 2)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        foregroundColor: onSurface,
        side: BorderSide(color: palette.border, width: 1.2),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md + 2)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: onSurface),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 4,
      focusElevation: 4,
      hoverElevation: 6,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      extendedTextStyle: text.labelLarge,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: AppColors.ink,
      labelStyle: text.labelMedium,
      side: BorderSide(color: palette.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: palette.muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: palette.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? AppColors.surfaceAltDark : AppColors.ink,
      contentTextStyle:
          text.bodyMedium?.copyWith(color: Colors.white, fontFamily: _font),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.muted,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      textStyle: text.bodyMedium,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.brand : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.transparent : null),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.ink,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: palette.border),
        textStyle: text.labelMedium,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brand,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.ink,
      headerForegroundColor: Colors.white,
      rangeSelectionBackgroundColor: AppColors.brand.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.brand,
      selectionColor: AppColors.brand.withValues(alpha: 0.25),
      selectionHandleColor: AppColors.brand,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
          color: Colors.white, fontSize: 12, fontFamily: _font),
    ),
  );
}
