import 'package:flutter/material.dart';

/// Pawly design tokens.
///
/// The one bold idea: every pet gets its own colour, and that colour follows
/// the pet everywhere (avatar ring, timeline dot, the segment it fills in the
/// Today ring). Everything else stays calm: a cool paper background, deep
/// night-blue ink, white cards.
class Brand {
  static const night = Color(0xFF26335C); // primary ink / brand
  static const nightSoft = Color(0xFFA9B6FF); // primary on dark
  static const marigold = Color(0xFFFFB23F); // highlight, Pro
  static const mint = Color(0xFF22B59A); // done
  static const coral = Color(0xFFF2604E); // overdue
  static const paper = Color(0xFFF5F6FA);
  static const paperDark = Color(0xFF11141D);

  static const display = 'Fredoka';
  static const body = 'Figtree';

  /// Colours a pet can wear.
  static const petColors = <Color>[
    Color(0xFFFFB23F), // marigold
    Color(0xFF3FB6A8), // sea
    Color(0xFF5B8DEF), // sky
    Color(0xFFF26D5B), // coral
    Color(0xFF9C7BE3), // lilac
    Color(0xFF7CC16B), // leaf
    Color(0xFFE77FB3), // rose
    Color(0xFF8A9BB0), // slate
  ];

  static Color petColor(int index) => petColors[index % petColors.length];
}

/// Extra colours that Material's ColorScheme does not have.
class PawlyColors extends ThemeExtension<PawlyColors> {
  const PawlyColors({
    required this.card,
    required this.cardBorder,
    required this.muted,
    required this.done,
    required this.overdue,
    required this.pro,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
  });

  final Color card;
  final Color cardBorder;
  final Color muted;
  final Color done;
  final Color overdue;
  final Color pro;
  final Color heroStart;
  final Color heroEnd;
  final Color onHero;

  static const light = PawlyColors(
    card: Colors.white,
    cardBorder: Color(0xFFE6E8F0),
    muted: Color(0xFF6B7287),
    done: Brand.mint,
    overdue: Brand.coral,
    pro: Brand.marigold,
    heroStart: Color(0xFF26335C),
    heroEnd: Color(0xFF3B4E8C),
    onHero: Colors.white,
  );

  static const dark = PawlyColors(
    card: Color(0xFF1B1F2B),
    cardBorder: Color(0xFF2A3040),
    muted: Color(0xFF9BA2B6),
    done: Color(0xFF3DD1B3),
    overdue: Color(0xFFFF7A69),
    pro: Brand.marigold,
    heroStart: Color(0xFF222B48),
    heroEnd: Color(0xFF2E3D6E),
    onHero: Colors.white,
  );

  static PawlyColors of(BuildContext context) =>
      Theme.of(context).extension<PawlyColors>()!;

  @override
  PawlyColors copyWith() => this;

  @override
  PawlyColors lerp(ThemeExtension<PawlyColors>? other, double t) {
    if (other is! PawlyColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PawlyColors(
      card: l(card, other.card),
      cardBorder: l(cardBorder, other.cardBorder),
      muted: l(muted, other.muted),
      done: l(done, other.done),
      overdue: l(overdue, other.overdue),
      pro: l(pro, other.pro),
      heroStart: l(heroStart, other.heroStart),
      heroEnd: l(heroEnd, other.heroEnd),
      onHero: l(onHero, other.onHero),
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final extra = dark ? PawlyColors.dark : PawlyColors.light;
  final ink = dark ? const Color(0xFFEDEFF6) : const Color(0xFF1B2236);

  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.night,
    brightness: brightness,
  ).copyWith(
    primary: dark ? Brand.nightSoft : Brand.night,
    onPrimary: dark ? const Color(0xFF141A33) : Colors.white,
    secondary: Brand.marigold,
    onSecondary: const Color(0xFF2B1D00),
    tertiary: Brand.mint,
    error: extra.overdue,
    surface: dark ? Brand.paperDark : Brand.paper,
    onSurface: ink,
    onSurfaceVariant: extra.muted,
    outlineVariant: extra.cardBorder,
    surfaceContainerLowest: extra.card,
    surfaceContainerLow: extra.card,
    surfaceContainer: dark ? const Color(0xFF202534) : const Color(0xFFEEF0F6),
    surfaceContainerHigh: dark ? const Color(0xFF252A3A) : const Color(0xFFE9EBF3),
  );

  TextStyle d(double size, FontWeight w, {double? h}) => TextStyle(
      fontFamily: Brand.display, fontSize: size, fontWeight: w, height: h, color: ink);
  TextStyle b(double size, FontWeight w, {double? h, Color? c}) => TextStyle(
      fontFamily: Brand.body, fontSize: size, fontWeight: w, height: h, color: c ?? ink);

  final text = TextTheme(
    displaySmall: d(34, FontWeight.w600, h: 1.1),
    headlineMedium: d(28, FontWeight.w600, h: 1.15),
    headlineSmall: d(23, FontWeight.w600, h: 1.2),
    titleLarge: d(20, FontWeight.w600, h: 1.25),
    titleMedium: b(16, FontWeight.w700, h: 1.3),
    titleSmall: b(14, FontWeight.w700, h: 1.3),
    bodyLarge: b(16, FontWeight.w400, h: 1.45),
    bodyMedium: b(14, FontWeight.w400, h: 1.45),
    bodySmall: b(12.5, FontWeight.w400, h: 1.4, c: extra.muted),
    labelLarge: b(14.5, FontWeight.w700),
    labelMedium: b(12.5, FontWeight.w600),
    labelSmall: b(11.5, FontWeight.w600, c: extra.muted),
  );

  final radius = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: Brand.body,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [extra],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: d(22, FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: extra.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: extra.cardBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: extra.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.12),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => b(
          12, s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          c: s.contains(WidgetState.selected) ? ink : extra.muted)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: b(15.5, FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: extra.cardBorder),
        textStyle: b(14.5, FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: b(14.5, FontWeight.w700)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: b(15, FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: extra.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide(color: extra.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide(color: extra.cardBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 1.6)),
      labelStyle: b(14.5, FontWeight.w600, c: extra.muted),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: extra.cardBorder),
      labelStyle: b(13.5, FontWeight.w600),
      backgroundColor: extra.card,
      selectedColor: scheme.primary.withValues(alpha: dark ? 0.28 : 0.12),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        textStyle: b(13.5, FontWeight.w700),
        selectedBackgroundColor: scheme.primary.withValues(alpha: dark ? 0.28 : 0.12),
        side: BorderSide(color: extra.cardBorder),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      titleTextStyle: b(15.5, FontWeight.w700),
      subtitleTextStyle: b(13, FontWeight.w400, c: extra.muted),
      iconColor: extra.muted,
    ),
    dividerTheme: DividerThemeData(color: extra.cardBorder, thickness: 1, space: 1),
    tabBarTheme: TabBarThemeData(
      labelStyle: b(14, FontWeight.w700),
      unselectedLabelStyle: b(14, FontWeight.w600),
      labelColor: ink,
      unselectedLabelColor: extra.muted,
      indicatorColor: scheme.primary,
      dividerColor: extra.cardBorder,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: extra.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: extra.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
