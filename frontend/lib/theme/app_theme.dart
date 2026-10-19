import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color ciano = Color(0xff27B8B5);
  static const Color darkCiano = Color(0xFF167C80);
  static const Color cianoClaro = Color(0xFFDDF7F6);
  static const Color gray = Color(0xFF68777A);

  // cores de branco
  static const Color background = Color(0xFFF7FAFA);
  static const Color surface = Color(0xFFFFFFFF);

  // cores pro form
  static const Color inputText = Color(0xFF163A43);
  static const Color field = Color(0xFFDCE7E8);
  static const Color hintText = Color(0x80163A43);

  static const Color title = Color(0xFF1E1E1E);

  static const Color error = Color(0xFFD9535B);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.poppins().fontFamily,
  );
}
