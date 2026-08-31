// lib/pages/eller/elleri_bitir.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// ELLER FAB — yeni el ekleme düğmesi.
class EllerFab extends StatelessWidget {
  final bool oyunBitti;
  final VoidCallback? onPressed;

  const EllerFab({super.key, required this.oyunBitti, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: FloatingActionButton.extended(
        onPressed: oyunBitti ? null : onPressed,
        backgroundColor: oyunBitti ? AppColors.cardBg : AppColors.accentAmber,
        foregroundColor: oyunBitti
            ? AppColors.textSecondary
            : const Color(0xFF1A1206),
        elevation: oyunBitti ? 0 : 8,
        icon: Icon(oyunBitti ? Icons.block : Icons.add),
        label: Text(
          oyunBitti ? 'El Tamam' : 'Yeni El',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
