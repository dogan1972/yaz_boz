// lib/pages/eller/yazboz_widgets.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Standart Tablo Hücresi
Widget ybHucre(
  String t, {
  Color? color,
  FontWeight? weight,
  double size = 14, // ✅ 15 → 14
  int? maxLines,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
  child: Text(
    t,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
    style: TextStyle(
      color: color ?? AppColors.textPrimary,
      fontWeight: weight ?? FontWeight.w600,
      fontSize: size,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  ),
);

/// Tıklanabilir Tablo Hücresi
Widget ybTiklanabilirHucre(
  VoidCallback onTap,
  String t, {
  double size = 14, // ✅ 15 → 14
}) => Material(
  type: MaterialType.transparency,
  child: InkWell(
    onTap: onTap,
    splashColor: AppColors.accentAmber.withValues(alpha: 0.15),
    highlightColor: AppColors.accentAmber.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size,
          color: AppColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
  ),
);

/// Sonuç Satırı Vurgulu Hücre
Widget ybSonucHucresi(
  int puan,
  int liderD,
  int sonuncD,
  bool acik,
  bool kilitli,
) {
  final lider = acik && puan == liderD;
  final son = acik && puan == sonuncD;
  Color? bg;
  Color fg;

  if (lider) {
    bg = AppColors.accentGreen.withValues(alpha: 0.16);
    fg = AppColors.accentGreen;
  } else if (son) {
    bg = AppColors.accentRed.withValues(alpha: 0.14);
    fg = AppColors.accentRed;
  } else {
    fg = puan >= 0 ? AppColors.textPrimary : AppColors.accentRed;
  }

  return Container(
    color: bg,
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
    child: Text(
      puan.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 15, // ✅ 17 → 15
        color: fg,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Tablo Başlığı
Widget ybBaslik(String t, {int maxLines = 2}) => Padding(
  // ✅ varsayılan 1 → 2
  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
  child: Text(
    t,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 13, // ✅ 14 → 13
      color: Colors.white,
      height: 1.15,
    ),
  ),
);
