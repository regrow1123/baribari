import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KakaoTheme {
  // Colors
  static const background = Color(0xFFB2C7D9);
  static const myBubble = Color(0xFFFEE500);
  static const otherBubble = Color(0xFFFFFFFF);
  static const sidebarBg = Color(0xFFFFFFFF);
  static const headerBg = Color(0xFF3C1E1E);
  static const primary = Color(0xFF391B1B);
  static const secondary = Color(0xFF999999);
  static const inputBg = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE5E5E5);

  // Bubble
  static const bubbleRadius = 16.0;
  static const bubblePadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  // Card
  static const cardRadius = 12.0;

  static ThemeData get themeData {
    final textTheme = GoogleFonts.notoSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF391B1B),
        secondary: myBubble,
        surface: sidebarBg,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: headerBg,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      textTheme: textTheme,
    );
  }
}
