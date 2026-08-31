// lib/models/el_model.dart
import 'package:flutter/material.dart';

/// Skor Girişi İçin Renk Paleti
const Color elBgDark = Color(0xFF0A0F1C);
const Color elCardBg = Color(0xFF111A2B);
const Color elInputBg = Color(0xFF0B1220);
const Color elBorder = Color(0xFF1E293B);
const Color elTextPrimary = Color(0xFFF8FAFC);
const Color elTextSecondary = Color(0xFF64748B);
const Color elAccentAmber = Color(0xFFF59E0B);
const Color elAccentCyan = Color(0xFF2DD4BF);

/// Oyuncu Skor Verisi (Widget'lara taşımak için)
class OyuncuSkorVerisi {
  final String ad;
  final TextEditingController karController;
  final TextEditingController zararController;
  final TextEditingController gostergeController;

  OyuncuSkorVerisi({
    required this.ad,
    required this.karController,
    required this.zararController,
    required this.gostergeController,
  });

  int get netSkor {
    final k = int.tryParse(karController.text.trim()) ?? 0;
    final z = int.tryParse(zararController.text.trim()) ?? 0;
    return z - k; // Net = Zarar - Kar
  }

  int get gostergeDegeri {
    final g = int.tryParse(gostergeController.text.trim()) ?? 0;
    return -g; // Modelde negatif olarak tutuluyor
  }
}
