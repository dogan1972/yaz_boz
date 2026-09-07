// lib/pages/turnuva/turnuva_detay_widgets.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/theme/app_theme.dart';

/// Numara Rozeti
Widget turnuvaNumaraRozeti(
  int? n, {
  Color renk = AppColors.textPrimary,
  double? font,
}) {
  if (n == null) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: renk.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: renk.withValues(alpha: 0.6), width: 1.2),
    ),
    child: Text(
      '#$n',
      style: TextStyle(
        color: renk,
        fontWeight: FontWeight.w800,
        fontSize: font ?? 14,
        letterSpacing: 0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Canlı Nabız Noktası
class TurnuvaPulseDot extends StatefulWidget {
  const TurnuvaPulseDot({super.key});
  @override
  State<TurnuvaPulseDot> createState() => _TurnuvaPulseDotState();
}

class _TurnuvaPulseDotState extends State<TurnuvaPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
      builder: (_, _) => Opacity(
        opacity: 0.4 + 0.6 * _c.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.orange.shade400,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.6 * _c.value),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İlerleme Modülü (Circular Progress)
class TurnuvaIlerlemeModulu extends StatelessWidget {
  final int toplam;
  final int biten;
  final bool sonlandi;
  const TurnuvaIlerlemeModulu({
    super.key,
    required this.toplam,
    required this.biten,
    required this.sonlandi,
  });

  @override
  Widget build(BuildContext context) {
    final oran = toplam == 0 ? 0.0 : (biten / toplam).clamp(0.0, 1.0);
    final vurgu = sonlandi ? AppColors.accentAmber : const Color(0xFF5EEAD4);
    return SizedBox(
      width: 112,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: oran),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textPrimary.withValues(alpha: 0.16),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(vurgu),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: vurgu.withValues(alpha: 0.35),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    sonlandi
                        ? const Icon(
                            Icons.emoji_events,
                            color: AppColors.accentAmber,
                            size: 32,
                          )
                        : Text(
                            '$biten',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                              height: 1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Madalya Bileşeni
Widget turnuvaMadalya(String emoji, String etiket, String? ad, Color renk) {
  if (ad == null || ad.isEmpty) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
    decoration: BoxDecoration(
      color: AppColors.textPrimary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: renk.withValues(alpha: 0.5), width: 1.1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                etiket,
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.6),
                  fontSize: 9,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                ad,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Aksiyon Kapsülü
Widget turnuvaAksiyonKapsul({
  required IconData icon,
  required String etiket,
  required Color renk,
  required VoidCallback onTap,
}) {
  return Material(
    color: AppColors.textPrimary.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      hoverColor: AppColors.textPrimary.withValues(alpha: 0.10),
      splashColor: renk.withValues(alpha: 0.30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: renk, size: 18),
            const SizedBox(width: 8),
            Text(
              etiket,
              style: TextStyle(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ✅✅ GÜNCELLENDİ: OYUN KARTI ESNİK YAPIDA (OVERFLOW SORUNU ÇÖZÜLDÜ) ✅✅
Widget turnuvaOyunKarti(DocumentSnapshot doc, int index) {
  final d = doc.data() as Map<String, dynamic>? ?? {};
  final kaybeden = d['oyunKaybeden']?.toString();
  final bitti = kaybeden != null;

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bitti
                ? AppColors.accentGreen.withValues(alpha: 0.30)
                : AppColors.accentAmber.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Dikey hizalama merkeze alındı
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bitti
                        ? [AppColors.accentGreen, const Color(0xFF15803D)]
                        : [AppColors.accentAmber, const Color(0xFFC2410C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlan
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d['oyunTarih']?.toString() ?? 'Oyun #${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!bitti) const TurnuvaPulseDot(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Oyuncu isimleri uzunsa alt satıra geçebilsin
                    Text(
                      d['oyuncu']?.toString() ?? '',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2, // Tek satır yerine iki satıra izin ver
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    bitti
                        ? Row(
                            children: [
                              const Text('🏆 ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  d['oyunKazanan']?.toString() ?? '-',
                                  style: const TextStyle(
                                    color: AppColors.accentGreen,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Text(' ', style: TextStyle(fontSize: 12)),
                              Flexible(
                                child: Text(
                                  kaybeden,
                                  style: const TextStyle(
                                    color: AppColors.accentRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Devam ediyor…',
                            style: TextStyle(
                              color: AppColors.accentAmber,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Boş Oyun Durumu
class TurnuvaBosOyun extends StatelessWidget {
  const TurnuvaBosOyun({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_esports, size: 56, color: AppColors.divider),
          const SizedBox(height: 12),
          const Text(
            'Bu turnuvada henüz oyun oynanmamış.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'İlk oyun başlatıldığında burada görünecek.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Hata Ekranı
Widget turnuvaHataEkrani(String hata, VoidCallback onRetry) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: AppColors.accentRed, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Veri yüklenirken hata oluştu',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.accentRed,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hata,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              foregroundColor: const Color(0xFF1A1206),
            ),
          ),
        ],
      ),
    ),
  );
}
