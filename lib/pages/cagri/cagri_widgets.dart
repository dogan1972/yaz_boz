// lib/pages/cagri/cagri_widgets.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/pages/cagri/cagri_dialog.dart';
import 'package:yaz_boz/pages/salon/salon_sayfasi.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/theme/app_theme.dart';

/// Durum Bilgisi Sınıfı
class CagriDurumBilgisi {
  final String etiket;
  final Color renk;
  final IconData ikon;
  const CagriDurumBilgisi(this.etiket, this.renk, this.ikon);
}

/// Çağrı Kartı Bileşeni - DÜZELTİLMİŞ SAYIM MANTIĞI
class CagriKarti extends StatelessWidget {
  final Cagri cagri;
  final String uid;
  const CagriKarti({super.key, required this.cagri, required this.uid});

  bool get _benAcan => cagri.acanId == uid;

  CagriDurumBilgisi get _durum {
    switch (cagri.durum) {
      case 'acik':
        return const CagriDurumBilgisi(
          'AÇIK',
          AppColors.accentAmber,
          Icons.table_restaurant,
        );
      case 'onaylandi':
        return const CagriDurumBilgisi(
          'MÜHÜRLÜ',
          AppColors.accentCyan,
          Icons.verified_user_rounded,
        );
      case 'sonlandi':
        return const CagriDurumBilgisi(
          'SONLANDI',
          AppColors.textSecondary,
          Icons.power_settings_new,
        );
      default:
        return CagriDurumBilgisi(
          cagri.durum.toUpperCase(),
          AppColors.textSecondary,
          Icons.circle,
        );
    }
  }

  Future<void> _konumuAc(BuildContext context) async {
    String? aramaMetni = cagri.konumAd;
    if (aramaMetni == null || aramaMetni.isEmpty) {
      aramaMetni = cagri.yer;
    }
    if (aramaMetni == null || aramaMetni.isEmpty) return;

    Uri uri;
    if (aramaMetni.startsWith('http://') || aramaMetni.startsWith('https://')) {
      uri = Uri.parse(aramaMetni);
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(aramaMetni)}',
      );
    }

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Harita açılamadı.')));
        }
      }
    } catch (e) {
      debugPrint('Konum hatası: $e');
    }
  }

  void _duzenle(BuildContext context) {
    if (!context.mounted) return;
    cagriAcDialogu(context, uid, mevcutCagri: cagri);
  }

  Future<void> _iptalEt(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text(
          'Çağrıyı İptal Et?',
          style: AppTextStyles.bodyPrimary,
        ),
        content: const Text(
          'Bu işlem geri alınamaz.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (onay == true && context.mounted) {
      try {
        await CagriServisi().cagriIptalEt(cagri.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Çağrı iptal edildi.'),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.accentRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _durum;

    // ✅ KRİTİK DÜZELTME: Sayım Mantığı
    // cagri.hedef: Davetli sayısı (Örn: 3)
    // Toplam Katılımcı: Davetli + Çağrıcı (3 + 1 = 4)
    final toplamKatilimci = cagri.hedef + 1;

    // Onay Sayısı Hesaplama:
    // PanoVerisi.cagri içindeki mantıkla uyumlu olması için:
    // Eğer çağrıcı (acanId) onaylar listesinde YOKSA, listedeki sayıya +1 ekleriz.
    // Eğer VARSA (bazen sistem ekleyebilir), direkt liste uzunluğunu alırız.
    int onaySayisi = cagri.onaylar.length;
    if (!cagri.onaylar.contains(cagri.acanId)) {
      onaySayisi += 1;
    }

    final aktif = cagri.acik || cagri.kilitli;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SalonSayfasi(cagriId: cagri.id, uid: uid),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: aktif ? d.renk.withValues(alpha: 0.5) : AppColors.border,
                width: aktif ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. SATIR: DURUM + AÇAN KİŞİ + ONAY SAYISI ---
                Row(
                  children: [
                    Icon(d.ikon, color: d.renk, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      d.etiket,
                      style: TextStyle(
                        color: d.renk,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _benAcan ? 'sen açtın' : '${cagri.acanAd} çağırdı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // ✅ DÜZELTİLDİ: Artık her zaman (Onay / ToplamKatılımcı) formatında
                    Text(
                      '$onaySayisi/$toplamKatilimci',
                      style: TextStyle(
                        color: d.renk,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('onay', style: AppTextStyles.bodySecondary),
                  ],
                ),

                const SizedBox(height: 8),

                // --- 2. SATIR: TARİH VE SAAT ---
                Row(
                  children: [
                    if (cagri.tarih != null && cagri.tarih!.isNotEmpty) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.accentAmber,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cagri.tarih!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (cagri.saat != null && cagri.saat!.isNotEmpty) ...[
                      if (cagri.tarih != null && cagri.tarih!.isNotEmpty)
                        const SizedBox(width: 12),
                      Icon(
                        Icons.access_time_rounded,
                        color: AppColors.accentAmber,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cagri.saat!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if ((cagri.tarih == null || cagri.tarih!.isEmpty) &&
                        (cagri.saat == null || cagri.saat!.isEmpty)) ...[
                      Icon(Icons.schedule, color: AppColors.divider, size: 14),
                      const SizedBox(width: 6),
                      const Text(
                        '-',
                        style: TextStyle(
                          color: AppColors.divider,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // --- 3. SATIR: MEKAN + AKSİYONLAR ---
                Row(
                  children: [
                    Icon(Icons.place, color: AppColors.accentBlue, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _konumuAc(context),
                        child: Text(
                          cagri.yer ?? 'Konum yok',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accentBlue,
                          ),
                        ),
                      ),
                    ),
                    if (_benAcan && cagri.acik) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: AppColors.accentAmber,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _duzenle(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.accentRed,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _iptalEt(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Boş Durum Ekranı
class CagriBosDurumEkrani extends StatelessWidget {
  final String? uid;
  const CagriBosDurumEkrani({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_restaurant_rounded,
              size: 64,
              color: AppColors.accentAmber.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'MASA BOŞ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Son 24 saatte çağrı yok.\nYeni bir masa kur veya arkadaşını bekle.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.divider, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => cagriAcDialogu(context, uid!),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('ÇAĞRI AÇ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentAmber,
                foregroundColor: AppColors.bgPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
