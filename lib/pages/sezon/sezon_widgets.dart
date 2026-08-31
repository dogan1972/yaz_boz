// lib/pages/sezon/sezon_widgets.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/models/sezon_model.dart';
import 'package:yaz_boz/services/sezon_servisi.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

Widget sezonNumaraRozeti(
  int? n, {
  Color renk = AppColors.accentBlue,
  double? font,
}) {
  if (n == null) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: renk.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: renk.withValues(alpha: 0.55), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: renk.withValues(alpha: 0.30),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      '#$n',
      style: TextStyle(
        color: renk,
        fontWeight: FontWeight.w800,
        fontSize: font ?? 13,
        letterSpacing: 0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

Widget sezonSilDugmesi({required VoidCallback onTap}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentAmber.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentAmber.withValues(alpha: 0.45),
            ),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: AppColors.accentAmber,
            size: 22,
          ),
        ),
      ),
    ),
  );
}

Widget sezonHeroAksiyonButonu({
  required IconData icon,
  required Color renk,
  required String etiket,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: renk, size: 22),
          const SizedBox(height: 2),
          Text(
            etiket,
            style: TextStyle(
              color: renk.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget sezonBosDurum(bool gosterArsiv) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          gosterArsiv ? Icons.inventory_2_outlined : Icons.flag_outlined,
          size: 64,
          color: AppColors.divider,
        ),
        const SizedBox(height: 14),
        Text(
          gosterArsiv
              ? 'Arşivde hiç sezon bulunmuyor.'
              : 'Aktif (devam eden) sezon bulunmuyor.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          gosterArsiv
              ? 'Sonlanan sezonlar burada listelenecek.'
              : 'Yeni sezon başlatmak için + butonuna dokun.',
          style: const TextStyle(color: AppColors.textHint, fontSize: 12),
        ),
      ],
    ),
  );
}

Future<void> sezonFormuDiyalog(BuildContext context, {Sezon? sezon}) async {
  final tarihCtrl = TextEditingController(
    text: sezon?.sezonTarih ?? DateTime.now().toString().substring(0, 10),
  );
  final sampiyonCtrl = TextEditingController(text: sezon?.sezonSampiyon ?? '');
  bool isLowestWins = sezon?.isLowestWins ?? true;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          sezon == null ? 'Yeni Sezon Ekle' : 'Sezonu Düzenle',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tarihCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Sezon Tarihi / Adı',
                  labelStyle: const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              if (sezon != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: sampiyonCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Sezon Şampiyonu',
                    labelStyle: const TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLowestWins ? Icons.trending_down : Icons.trending_up,
                      color: isLowestWins
                          ? AppColors.accentGreen
                          : AppColors.accentRed,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLowestWins
                                ? 'En Düşük Skor Kazanır'
                                : 'En Yüksek Skor Kazanır',
                            style: TextStyle(
                              color: isLowestWins
                                  ? AppColors.accentGreen
                                  : AppColors.accentRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Oyun sonunda kazananı belirler',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isLowestWins,
                      onChanged: (v) => setStateDialog(() => isLowestWins = v),
                      activeThumbColor: AppColors.accentGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal', style: AppTextStyles.bodySecondary),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tarihCtrl.text.trim().isEmpty) return;

              try {
                final svc = SezonServisi();
                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                if (sezon == null) {
                  await svc.yeniSezonOlustur(
                    tarih: tarihCtrl.text.trim(),
                    isLowestWins: isLowestWins,
                  );
                } else {
                  await svc.sezonuGuncelle(sezon.id, {
                    'sezonTarih': tarihCtrl.text.trim(),
                    'sezonSampiyon': sampiyonCtrl.text.trim().isEmpty
                        ? null
                        : sampiyonCtrl.text.trim(),
                    'isLowestWins': isLowestWins,
                  });
                }

                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: AppColors.accentRed,
                  ),
                );
              }
            },
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}
