// lib/pages/arkadas/arkadas_widgets.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Ortak Kart Yapısı
Widget arkadasKart({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

/// Avatar Bileşeni
Widget arkadasAvatar(String nick, double r) {
  final harf = nick.trim().isEmpty ? '?' : nick.trim()[0].toUpperCase();
  return Container(
    width: r * 2,
    height: r * 2,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [AppColors.accentAmber, Color(0xFFB45309)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Text(
      harf,
      style: TextStyle(
        color: const Color(0xFF1A1206),
        fontWeight: FontWeight.w900,
        fontSize: r * 0.9,
      ),
    ),
  );
}

/// Aksiyon Butonu
Widget arkadasAksiyonButonu(
  String etiket,
  Color renk,
  VoidCallback onTap, {
  bool kucuk = false,
  bool yukleniyor = false,
}) {
  return Material(
    color: renk,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: yukleniyor ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: kucuk ? 12 : 18,
          vertical: kucuk ? 8 : 12,
        ),
        child: Text(
          etiket,
          style: TextStyle(
            color: renk == AppColors.textHint
                ? AppColors.textPrimary
                : AppColors.bgPrimary,
            fontWeight: FontWeight.w900,
            fontSize: kucuk ? 11 : 13,
            letterSpacing: 1,
          ),
        ),
      ),
    ),
  );
}

/// Bölüm Başlığı
Widget arkadasBolumBasligi(String baslik, int adet, Color renk) {
  return Row(
    children: [
      Icon(Icons.person_add_alt_1, color: renk, size: 14),
      const SizedBox(width: 8),
      Text(
        baslik.toUpperCase(),
        style: TextStyle(
          color: renk,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$adet',
          style: TextStyle(
            color: renk,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    ],
  );
}
