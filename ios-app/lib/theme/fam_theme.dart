import 'package:flutter/material.dart';

class FamTheme {
  // Gözü yormayan derin Gece/Safir paleti (Executive Family Theme)
  static const Color background = Color(0xFF0B132B);
  static const Color surface = Color(0xFF1C2541);
  static const Color surfaceElevated = Color(0xFF283655);
  static const Color surfaceDarker = Color(0xFF070D1F);

  // Vurgu renkleri
  static const Color primary = Color(0xFF4361EE); // Kraliyet Safiri
  static const Color primaryLight = Color(0xFF4CC9F0);
  static const Color secondary = Color(0xFF7209B7); // Mor / Kraliyet
  static const Color gold = Color(0xFFF59E0B); // Altın Puan & Hazine
  static const Color goldLight = Color(0xFFFBBF24); // Açık Altın
  static const Color emerald = Color(0xFF10B981); // Onay & Başarı
  static const Color rose = Color(0xFFF72585); // Alarm & İhlal
  static const Color cyan = Color(0xFF4CC9F0); // Odak / Canlı Durum

  // Metin renkleri
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  // Kart Kutusu Dekorasyonu
  static BoxDecoration cardDecoration({
    Color? borderColor,
    double radius = 22,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? primary.withOpacity(0.25),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: glow
              ? (borderColor ?? primary).withOpacity(0.2)
              : Colors.black.withOpacity(0.35),
          blurRadius: glow ? 16 : 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Flutter ThemeData
  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      fontFamily: 'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDarker,
        selectedItemColor: primaryLight,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 20,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
