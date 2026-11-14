import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens, ported from brand/tokens.css. These are the only colours,
/// radii and fonts the app uses; to white-label, edit this file and swap the
/// files in assets/brand/.
class Brand extends ThemeExtension<Brand> {
  const Brand({
    required this.brand,
    required this.onBrand,
    required this.paper,
    required this.card,
    required this.ink,
    required this.mute,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.err,
    required this.shadow,
  });

  final Color brand, onBrand, paper, card, ink, mute, line, accent, accentSoft, err;
  final List<BoxShadow> shadow;

  static const rCard = 22.0;
  static const rCtl = 14.0;
  static const rPill = 999.0;

  static const light = Brand(
    brand: Color(0xFFDB9558),
    onBrand: Color(0xFF1C1714),
    paper: Color(0xFFF7F4EE),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1C1714),
    mute: Color(0xFF6E655C),
    line: Color(0xFFE8E1D6),
    accent: Color(0xFF2B4C7E),
    accentSoft: Color(0xFFE3E9F2),
    err: Color(0xFFB5442B),
    shadow: [BoxShadow(color: Color(0x1F1C1714), blurRadius: 30, offset: Offset(0, 10))],
  );

  static const dark = Brand(
    brand: Color(0xFFDB9558),
    onBrand: Color(0xFF1C1714),
    paper: Color(0xFF1C1714),
    card: Color(0xFF2A231F),
    ink: Color(0xFFF3EEE6),
    mute: Color(0xFFA39A90),
    line: Color(0xFF3B322C),
    accent: Color(0xFF7FA1D6),
    accentSoft: Color(0xFF2E3A4D),
    err: Color(0xFFF0876F),
    shadow: [BoxShadow(color: Color(0x73000000), blurRadius: 30, offset: Offset(0, 10))],
  );

  static Brand of(BuildContext context) => Theme.of(context).extension<Brand>()!;

  @override
  Brand copyWith() => this;

  @override
  Brand lerp(Brand? other, double t) {
    if (other == null) return this;
    return Brand(
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mute: Color.lerp(mute, other.mute, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      err: Color.lerp(err, other.err, t)!,
      shadow: t < .5 ? shadow : other.shadow,
    );
  }
}

/// Display face: Jost 500/600. Body face: Work Sans 400/500/600.
TextStyle display({double size = 17, FontWeight weight = FontWeight.w600, Color? color, double? height, double? letterSpacing}) =>
    GoogleFonts.jost(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);

TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color? color, double? height, double? letterSpacing}) =>
    GoogleFonts.workSans(fontSize: size, fontWeight: weight, color: color, height: height ?? 1.45, letterSpacing: letterSpacing);

const monoFamily = 'Menlo';
TextStyle mono({double size = 15, Color? color, double? letterSpacing, FontWeight? weight}) => TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: const ['Courier', 'monospace'], fontSize: size, color: color, letterSpacing: letterSpacing, fontWeight: weight);

ThemeData buildTheme(Brightness brightness) {
  final b = brightness == Brightness.dark ? Brand.dark : Brand.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: b.brand,
    onPrimary: b.onBrand,
    secondary: b.accent,
    onSecondary: Colors.white,
    error: b.err,
    onError: Colors.white,
    surface: b.card,
    onSurface: b.ink,
    outline: b.line,
    onSurfaceVariant: b.mute,
  );
  final bodyText = GoogleFonts.workSansTextTheme().apply(bodyColor: b.ink, displayColor: b.ink);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: b.paper,
    canvasColor: b.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: b.line.withValues(alpha: .6),
    textTheme: bodyText.copyWith(
      bodyMedium: body(color: b.ink),
      bodyLarge: body(color: b.ink),
      bodySmall: body(size: 13, color: b.mute),
      titleLarge: display(size: 28, color: b.ink, height: 1.15),
      titleMedium: display(size: 17, color: b.ink),
      labelLarge: display(size: 16, color: b.ink),
    ),
    extensions: [b],
    appBarTheme: AppBarTheme(backgroundColor: b.paper, foregroundColor: b.ink, elevation: 0, scrolledUnderElevation: 0),
    dividerColor: b.line,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: b.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Brand.rCard))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: b.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Brand.rCard)),
      titleTextStyle: display(size: 20, color: b.ink),
      contentTextStyle: body(size: 15, color: b.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: body(color: b.mute),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Brand.rCtl), borderSide: BorderSide(color: b.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Brand.rCtl), borderSide: BorderSide(color: b.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Brand.rCtl), borderSide: BorderSide(color: b.brand, width: 2)),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: b.brand, selectionColor: b.brand.withValues(alpha: .3), selectionHandleColor: b.brand),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? b.brand : Colors.transparent),
      checkColor: WidgetStatePropertyAll(b.onBrand),
      side: BorderSide(color: b.line, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
    snackBarTheme: SnackBarThemeData(backgroundColor: b.ink, contentTextStyle: body(size: 14, color: b.paper), behavior: SnackBarBehavior.floating),
  );
}
