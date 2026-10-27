import 'package:flutter/material.dart';

class KidsTheme {
  // Gözü yormayan yumuşak Gece/Okyanus renk paleti
  static const Color background = Color(0xFF0B1120);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceElevated = Color(0xFF334155);
  static const Color surfaceDarker = Color(0xFF0F172A);

  // Semantik & Dostane İsimler (Eye-comfort Dark Palette)
  static const Color bgMidnight = background;
  static const Color cardSlate = surface;
  static const Color goldAmber = gold;
  static const Color emeraldGreen = emerald;
  static const Color roseLight = rose;
  static const Color cyanSoft = cyan;
  static const Color indigoPrimary = primary;
  static const Color purpleAccent = secondary;

  // Vurgu renkleri
  static const Color primary = Color(0xFF6366F1); // Canlı İndigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF8B5CF6); // Mor / Sihirli
  static const Color gold = Color(0xFFF59E0B); // Altın Puan & Hazine
  static const Color goldLight = Color(0xFFFCD34D);
  static const Color emerald = Color(0xFF10B981); // Başarı / Onay
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color rose = Color(0xFFF43F5E); // İhlal & Alarm
  static const Color cyan = Color(0xFF06B6D4); // Ders & Çalışma

  // Metin renkleri
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  // Gradyanlar
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4C1D95), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient studyLockGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

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
        selectedItemColor: gold,
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
