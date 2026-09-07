// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

// 🎨 RENK PALETİ (Amber/Cyan Night Palette)
class AppColors {
  // Arkaplanlar
  static const Color bgPrimary = Color(0xFF0A0F1C); // Ana Arka Plan
  static const Color bgSecondary = Color(0xFF0B1220); // AppBar / İkincil
  static const Color cardBg = Color(0xFF111A2B); // Kart Arka Planı
  static const Color inputBg = Color(0xFF0B1220); // Input Arka Planı

  // Metinler
  static const Color textPrimary = Color(0xFFF8FAFC); // Ana Metin
  static const Color textSecondary = Color(0xFF94A3B8); // İkincil Metin
  static const Color textHint = Color(0xFF64748B); // İpucu Metni

  // Vurgu Renkleri (Accents)
  static const Color accentAmber = Color(0xFFF59E0B); // Amber (Ana Vurgu)
  static const Color accentCyan = Color(0xFF38BDF8); // Cyan (İkincil Vurgu)
  static const Color accentBlue = Color(0xFF60A5FA); // Mavi
  static const Color accentGreen = Color(0xFF4ADE80); // Yeşil (Başarı)
  static const Color accentRed = Color(0xFFF87171); // Kırmızı (Hata/Silme)
  static const Color accentPurple = Color(0xFFA78BFA); // Mor

  // Kenarlıklar ve Ayırıcılar
  static const Color border = Color(0xFF1E293B);
  static const Color divider = Color(0xFF334155);

  // ✅ ÇAĞRI PANOSU ÖZEL RENKLERİ (Buraya taşındı)
  static const Color panoBgGradientStart = Color(0xFF1565C0);
  static const Color panoBgGradientEnd = Color(0xFF0B2A5B);
  static const Color panoTextPrimary = Colors.white;
  static const Color panoTextSecondary = Colors.white70;
  static const Color panoAccentGreen = Color(0xFF22C55E);
  static const Color panoAccentAmber = Color(0xFFF59E0B);
  static const Color panoAccentBlue = Color.fromARGB(15, 5, 1, 255);
  static const Color panoAccentBlueFixed = Color(0xFF3DD3FC);
  static const Color panoBorderTop = Color(
    0xFFFFFFFF,
  );
}

// 📝 METİN STİLLERİ
class AppTextStyles {
  static const TextStyle heading = TextStyle(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );

  static const TextStyle bodyPrimary = TextStyle(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textHint,
    fontSize: 11,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w700,
  );
}

//  TEMA TANIMI
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bgPrimary,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.bgSecondary,
    foregroundColor: AppColors.textPrimary,
    titleTextStyle: AppTextStyles.heading,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputBg,
    labelStyle: const TextStyle(color: AppColors.textHint),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.accentAmber),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accentAmber,
      foregroundColor: const Color(0xFF1A1206),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.accentAmber,
    foregroundColor: Color(0xFF1A1206),
  ),
);
