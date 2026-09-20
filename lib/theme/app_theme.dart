import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const brand = Color(0xFFE94B6F);
  static const brandDark = Color(0xFFD63A5E);
  static const brandSoft = Color(0xFFFDEDF0);
  static const brandBorder = Color(0xFFF6C4CF);
  static const bg = Colors.white;
  static const surface = Colors.white;
  static const ink = Color(0xFF2B2D42);
  static const body = Color(0xFF4A4C5E);
  static const muted = Color(0xFF8A8C9B);
  static const line = Color(0xFFEDE9E8);
  static const green = Color(0xFF43A567);
  static const greenSoft = Color(0xFFEAF6EE);
  static const amber = Color(0xFFF2A93B);
  static const red = Color(0xFFE5484D);
  static const purple = Color(0xFF6C5CE7);
  static const blueSoft = Color(0xFFEEF3FF);
  static const peach = Color(0xFFFCEFEE);
}

TextStyle serif(
  double size, {
  FontWeight w = FontWeight.w700,
  Color color = C.ink,
  double? h,
}) => GoogleFonts.playfairDisplay(
  fontSize: size,
  fontWeight: w,
  color: color,
  height: h,
);

TextStyle sans(
  double size, {
  FontWeight w = FontWeight.w400,
  Color color = C.body,
  double? h,
}) => GoogleFonts.inter(fontSize: size, fontWeight: w, color: color, height: h);

TextStyle script(double size, {Color color = C.muted}) =>
    GoogleFonts.caveat(fontSize: size, color: color, height: 1.05);

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: C.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: C.brand,
    primary: C.brand,
    surface: C.surface,
  ),
  textTheme: GoogleFonts.interTextTheme(),
  dividerColor: C.line,
  switchTheme: SwitchThemeData(
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackColor: WidgetStateProperty.resolveWith(
      (s) =>
          s.contains(WidgetState.selected) ? C.brand : const Color(0xFFD9D6D5),
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  hoverColor: Colors.transparent,
);
