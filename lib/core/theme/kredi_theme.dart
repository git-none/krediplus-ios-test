import 'package:flutter/material.dart';

/// Sistema visual Kredi+ inspirado en la claridad y jerarquía de las fintech BNPL:
/// mucho blanco, tipografía negra fuerte, tarjetas amplias y acciones de marca.
/// La interacción usa naranja/coral Kredi+; el negro se reserva para texto y contraste.
class KrediColors {
  static const orange = Color(0xFFFD9C24);
  static const orangeDeep = Color(0xFFE47E00);
  static const coral = Color(0xFFFC5A35);
  static const black = Color(0xFF0B0B0C);
  static const navy = black;
  static const navySoft = Color(0xFF5C6470);
  static const background = Color(0xFFFAFAFA);
  static const surface = Colors.white;
  static const secondary = Color(0xFF667085);
  static const border = Color(0xFFE5E5E7);
  static const fieldBorder = Color(0xFFDADADD);
  static const green = Color(0xFF16865C);
  static const success = green;
  static const blue = Color(0xFF4B79D8);
  static const violet = Color(0xFF7357C8);
  static const rose = Color(0xFFD95A75);
  static const gold = Color(0xFFD99000);
  static const danger = Color(0xFFE1483D);
  static const warning = orange;
  static const softOrange = Color(0xFFFFF3E1);
  static const softBlue = Color(0xFFF0F4FF);
  static const softCream = Color(0xFFFFF8EE);
  static const charcoal = Color(0xFF242527);
  static const softCoral = Color(0xFFFFEDE8);
  static const softGreen = Color(0xFFEEF9F3);
  static const softError = Color(0xFFFFEFEC);
  static const inkSoft = Color(0xFF34363A);
}

class KrediMetrics {
  static const double contentMaxWidth = 520;
  static const double compactPadding = 16;
  static const double regularPadding = 20;
  static const double screenBottomPadding = 28;
  static const double touchTarget = 48;
  static const double buttonHeight = 52;
  static const double buttonRadius = 18;
  static const double cardRadius = 20;
  static const double fieldRadius = 18;
  static const double authFieldRadius = 20;
  static const double bottomBarHeight = 70;
  static const double bottomBarRadius = 20;
  static const double navIconSize = 21;
  static const double navCenterIconSize = 22;
}

class KrediMotion {
  static const Duration press = Duration(milliseconds: 90);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration page = Duration(milliseconds: 220);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

class _KrediPageTransitionsBuilder extends PageTransitionsBuilder {
  const _KrediPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: KrediMotion.enter,
      reverseCurve: KrediMotion.exit,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.025, 0),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

ThemeData krediTheme() {
  const scheme = ColorScheme.light(
    primary: KrediColors.orange,
    onPrimary: KrediColors.black,
    primaryContainer: KrediColors.softOrange,
    onPrimaryContainer: KrediColors.black,
    secondary: KrediColors.orange,
    onSecondary: KrediColors.black,
    secondaryContainer: KrediColors.softCoral,
    onSecondaryContainer: KrediColors.black,
    tertiary: KrediColors.green,
    onTertiary: Colors.white,
    surface: KrediColors.surface,
    onSurface: KrediColors.black,
    error: KrediColors.danger,
    errorContainer: KrediColors.softError,
    onErrorContainer: Color(0xFF7A1616),
    outline: KrediColors.border,
    outlineVariant: KrediColors.border,
  );

  const typography = TextTheme(
    displayLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 23,
      height: 29 / 23,
      letterSpacing: 0,
    ),
    displayMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 27 / 21,
      letterSpacing: 0,
    ),
    headlineLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 24 / 19,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 23 / 18,
      letterSpacing: 0,
    ),
    headlineSmall: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 21 / 16,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 21 / 16,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 19 / 14,
    ),
    titleSmall: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 19 / 14,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 20 / 14,
    ),
    bodyMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 19 / 13,
    ),
    bodySmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 12,
      height: 18 / 12,
    ),
    labelLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      height: 18 / 13,
    ),
    labelMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 17 / 12,
    ),
    labelSmall: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 11,
      height: 16 / 11,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    visualDensity: const VisualDensity(horizontal: -0.5, vertical: -0.5),
    colorScheme: scheme,
    textTheme: typography,
    scaffoldBackgroundColor: KrediColors.background,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: const Color(0x0A0B0B0C),
    hoverColor: const Color(0x060B0B0C),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _KrediPageTransitionsBuilder(),
        TargetPlatform.iOS: _KrediPageTransitionsBuilder(),
        TargetPlatform.macOS: _KrediPageTransitionsBuilder(),
        TargetPlatform.windows: _KrediPageTransitionsBuilder(),
        TargetPlatform.linux: _KrediPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: KrediColors.background,
      foregroundColor: KrediColors.black,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: KrediColors.black,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KrediMetrics.cardRadius),
        side: const BorderSide(color: KrediColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: KrediColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      labelStyle: const TextStyle(
        color: KrediColors.secondary,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      floatingLabelStyle: const TextStyle(
        color: KrediColors.secondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF8A8D92),
        fontWeight: FontWeight.w500,
        fontSize: 12.5,
      ),
      prefixStyle: const TextStyle(
        color: KrediColors.black,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      helperStyle: const TextStyle(
        color: KrediColors.secondary,
        fontSize: 11,
        height: 1.25,
      ),
      errorStyle: const TextStyle(
        color: KrediColors.danger,
        fontSize: 11,
        height: 1.15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KrediMetrics.fieldRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KrediMetrics.fieldRadius),
        borderSide: const BorderSide(color: KrediColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KrediMetrics.fieldRadius),
        borderSide: const BorderSide(color: KrediColors.orangeDeep, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KrediMetrics.fieldRadius),
        borderSide: const BorderSide(color: KrediColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KrediMetrics.fieldRadius),
        borderSide: const BorderSide(color: KrediColors.danger, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KrediColors.orange,
        foregroundColor: KrediColors.black,
        disabledBackgroundColor: const Color(0xFFE2E3E5),
        disabledForegroundColor: const Color(0xFF999CA1),
        minimumSize: const Size(0, KrediMetrics.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrediMetrics.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KrediColors.black,
        backgroundColor: Colors.white,
        minimumSize: const Size(0, KrediMetrics.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: KrediColors.border, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KrediMetrics.buttonRadius),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KrediColors.orangeDeep,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: KrediColors.orangeDeep,
        minimumSize: const Size(48, 48),
        iconSize: 22,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: KrediColors.softOrange,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: KrediColors.black,
      ),
      secondaryLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: KrediColors.orangeDeep,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: KrediColors.border),
      ),
      side: BorderSide.none,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KrediColors.orange,
      contentTextStyle: const TextStyle(
        color: KrediColors.black,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: KrediColors.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KrediColors.orange,
      linearTrackColor: Color(0xFFE8E9EB),
    ),
  );
}
