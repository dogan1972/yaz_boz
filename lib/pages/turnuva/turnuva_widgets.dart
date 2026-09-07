// lib/pages/turnuva/turnuva_widgets.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/models/turnuva_model.dart';
import 'package:yaz_boz/services/turnuva_servisi.dart';
import 'package:yaz_boz/services/sezon_servisi.dart';
import 'package:yaz_boz/theme/app_theme.dart';

/// Numara Rozeti
Widget turnuvaNumaraRozeti(
  int? n, {
  Color renk = AppColors.accentPurple,
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

/// Çift Rozet (Sezon + Turnuva)
Widget turnuvaCiftRozet(
  int? sezonNo,
  int? turnuvaNo, {
  required bool koyu,
  bool yatay = false,
}) {
  final sezon = turnuvaRozetSatir(
    'Sezon No',
    sezonNo,
    renk: koyu ? Colors.cyan.shade200 : AppColors.accentBlue,
    koyu: koyu,
  );
  final turnuva = turnuvaRozetSatir(
    'Turnuva No',
    turnuvaNo,
    renk: koyu ? Colors.amber.shade200 : AppColors.accentPurple,
    koyu: koyu,
  );
  if (yatay) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [sezon, const SizedBox(width: 14), turnuva],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [sezon, const SizedBox(height: 5), turnuva],
  );
}

/// Tek Rozet Satırı
Widget turnuvaRozetSatir(
  String etiket,
  int? n, {
  required Color renk,
  required bool koyu,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        etiket,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: koyu
              ? Colors.white.withValues(alpha: 0.7)
              : AppColors.textSecondary,
        ),
      ),
      const SizedBox(width: 6),
      n == null
          ? Text(
              '—',
              style: TextStyle(
                color: koyu ? Colors.white70 : AppColors.textHint,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            )
          : turnuvaNumaraRozeti(n, renk: renk, font: 12),
    ],
  );
}

/// Blok Ayırıcı
Widget turnuvaBlokAyirac([double h = 22]) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Container(
      width: 1.5,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );
}

/// Sonuç Sütunu (Kazanan/Kaybeden)
Widget turnuvaSonucSutunu(String emoji, String etiket, String? ad, Color renk) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            etiket,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        (ad == null || ad.isEmpty) ? '—' : ad,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: renk,
          letterSpacing: -0.2,
          height: 1.1,
        ),
      ),
    ],
  );
}

/// Hero Aksiyon Butonu
Widget turnuvaHeroAksiyonButonu({
  required IconData icon,
  required Color renk,
  required String etiket,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    hoverColor: Colors.white.withValues(alpha: 0.10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: renk, size: 24),
          const SizedBox(height: 4),
          Text(
            etiket,
            style: TextStyle(
              color: renk.withValues(alpha: 0.92),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Kıvılcım Animasyonu
class TurnuvaKivilcim extends StatefulWidget {
  const TurnuvaKivilcim({super.key});
  @override
  State<TurnuvaKivilcim> createState() => _TurnuvaKivilcimState();
}

class _TurnuvaKivilcimState extends State<TurnuvaKivilcim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return Container(
          width: 64 + 12 * t,
          height: 64 + 12 * t,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orangeAccent.withValues(alpha: 0.18 + 0.12 * t),
            boxShadow: [
              BoxShadow(
                color: Colors.orangeAccent.withValues(alpha: 0.5 * t),
                blurRadius: 24 + 10 * t,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.local_fire_department,
            color: Colors.orangeAccent,
            size: 40 + 6 * t,
          ),
        );
      },
    );
  }
}

/// Boş Durum Ekranı
Widget turnuvaBosDurum(bool gosterArsiv) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          gosterArsiv
              ? Icons.inventory_2_outlined
              : Icons.emoji_events_outlined,
          size: 64,
          color: AppColors.divider,
        ),
        const SizedBox(height: 14),
        Text(
          gosterArsiv ? 'Arşivde turnuva yok.' : 'Aktif turnuva bulunmuyor.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          gosterArsiv
              ? 'Sonlanan turnuvalar burada listelenecek.'
              : 'Yeni turnuva başlatmak için + butonuna dokun.',
          style: const TextStyle(color: AppColors.textHint, fontSize: 12),
        ),
      ],
    ),
  );
}

// ✅✅ GÜNCELLENDİ: LOADING DİYALOĞU GÜVENLİĞİ EKLENDİ ✅✅
Future<void> turnuvaFormuDiyalog(
  BuildContext context, {
  Turnuva? turnuva,
}) async {
  final tarihCtrl = TextEditingController(
    text: turnuva?.turTarih ?? DateTime.now().toString().substring(0, 10),
  );
  final kazananCtrl = TextEditingController(text: turnuva?.turKazanan ?? '');
  final ikinciCtrl = TextEditingController(text: turnuva?.turIkinci ?? '');
  final ucuncuCtrl = TextEditingController(text: turnuva?.turUcuncu ?? '');
  final kaybedenCtrl = TextEditingController(text: turnuva?.turKaybeden ?? '');
  bool isLowestWins = turnuva?.isLowestWins ?? true;

  InputDecoration formDeco(String label) => InputDecoration(
    labelText: label,
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
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.accentAmber),
    ),
  );

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          turnuva == null ? 'Yeni Turnuva Ekle' : 'Turnuvayı Düzenle',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tarihCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: formDeco('Turnuva Tarihi / Adı'),
              ),
              if (turnuva != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: kazananCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: formDeco(' Şampiyon'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ikinciCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: formDeco(' İkinci'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ucuncuCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: formDeco(' Üçüncü'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kaybedenCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: formDeco('📉 Sonuncu'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              foregroundColor: const Color(0xFF1A1206),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (tarihCtrl.text.trim().isEmpty) return;

              // Form dialogunu kapat
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              // Loading dialogunu aç
              if (!context.mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final svc = TurnuvaServisi();
                if (turnuva == null) {
                  final aktifSezon = await SezonServisi().aktifSezonBul();
                  if (aktifSezon == null) {
                    throw Exception('Aktif sezon bulunamadı!');
                  }
                  await svc.yeniTurnuvaOlustur(
                    sezonId: aktifSezon.id,
                    turTarih: tarihCtrl.text.trim(),
                    isLowestWins: isLowestWins,
                  );
                } else {
                  await svc.turnuvayiGuncelle(turnuva.id, {
                    'turTarih': tarihCtrl.text.trim(),
                    'turKazanan': kazananCtrl.text.trim().isEmpty
                        ? null
                        : kazananCtrl.text.trim(),
                    'turIkinci': ikinciCtrl.text.trim().isEmpty
                        ? null
                        : ikinciCtrl.text.trim(),
                    'turUcuncu': ucuncuCtrl.text.trim().isEmpty
                        ? null
                        : ucuncuCtrl.text.trim(),
                    'turKaybeden': kaybedenCtrl.text.trim().isEmpty
                        ? null
                        : kaybedenCtrl.text.trim(),
                    'tursonuc': kazananCtrl.text.trim().isNotEmpty ? 1 : 0,
                    'isLowestWins': isLowestWins,
                  });
                }

                // Başarılıysa loading'i kapat
                if (!context.mounted) return;
                if (Navigator.canPop(context)) Navigator.pop(context);
              } catch (e) {
                // Hata durumunda loading'i kapat ve hata göster
                if (!context.mounted) return;
                if (Navigator.canPop(context)) Navigator.pop(context);
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
