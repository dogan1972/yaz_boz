// lib/pages/eller/el_giris_widgets.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/models/el_giris_model.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Standart Input Dekorasyonu
InputDecoration elInputDeko(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    hintStyle: const TextStyle(color: AppColors.divider),
    filled: true,
    fillColor: AppColors.inputBg,
    isDense: true,
    contentPadding: const EdgeInsets.all(8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.accentAmber),
    ),
  );
}

/// Tek Oyuncu Skor Kutusu
Widget oyuncuKutu(OyuncuSkorVerisi veri) {
  return Padding(
    padding: const EdgeInsets.all(3),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            veri.ad,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: veri.karController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: elInputDeko('Kar'),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: veri.zararController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: elInputDeko('Zarar'),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: veri.gostergeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: elInputDeko('Göst.', hint: '0'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Yatay Mod Sağ Panel
Widget elSagPanel({
  required String oyunId,
  required bool duzenlemeModu,
  required bool kaydediyor,
  required VoidCallback onKaydet,
}) {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.sports_esports,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
                const SizedBox(height: 2),
                Text(
                  'Oyun: #$oyunId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  duzenlemeModu ? 'Düzenleme' : 'Yeni Kayıt',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kar, Zarar ve\nGösterge Dağılımı',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: 12, color: AppColors.border),
          ElevatedButton.icon(
            onPressed: kaydediyor ? null : onKaydet,
            icon: kaydediyor
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1A1206),
                    ),
                  )
                : const Icon(Icons.save, color: Color(0xFF1A1206), size: 16),
            label: const Text(
              'KAYDET',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1206),
                fontSize: 12,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
