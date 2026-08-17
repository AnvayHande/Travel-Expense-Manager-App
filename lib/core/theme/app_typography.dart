import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get textTheme {
    final base = GoogleFonts.interTextTheme();
    return base;
  }

  static TextTheme get displayLarge => textTheme;
}
