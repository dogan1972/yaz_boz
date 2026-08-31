// lib/pages/turnuva/turnuva_detay_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/services/turnuva_servisi.dart';
import 'package:yaz_boz/pages/turnuva/turnuva_detay_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class TurnuvaDetaySayfasi extends StatefulWidget {
  final String turnuvaId;
  final String turnuvaAdi;
  final int? turnuvaNumara;
  const TurnuvaDetaySayfasi({
    super.key,
    required this.turnuvaId,
    required this.turnuvaAdi,
    this.turnuvaNumara,
  });

  @override
  State<TurnuvaDetaySayfasi> createState() => _TurnuvaDetaySayfasiState();
}

class _TurnuvaDetaySayfasiState extends State<TurnuvaDetaySayfasi> {
  late Future<Map<String, dynamic>> _detayFuture;

  @override
  void initState() {
    super.initState();
    _detayFuture = TurnuvaServisi().turnuvaDetayHesapla(widget.turnuvaId);
  }

  Future<void> _turnuvayiSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_outline,
              color: AppColors.accentAmber,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Turnuvayı Sil', style: AppTextStyles.bodyPrimary),
          ],
        ),
        content: const Text(
          'Bu turnuvayı ve altındaki TÜM oyunları + girilmiş el skorlarını kalıcı olarak silmek istediğinize emin misiniz?',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('İptal', style: AppTextStyles.bodySecondary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text(
              'Kalıcı Sil',
              style: TextStyle(
                color: AppColors.accentAmber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentAmber),
      ),
    );
    try {
      await TurnuvaServisi().turnuvayiSil(widget.turnuvaId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context); // Loading
      Navigator.pop(context); // Detay Sayfası
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Turnuva ve tüm alt verileri silindi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Turnuva silme hatası: $e');
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme hatası: $e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Widget _banner(Map<String, dynamic> t, bool sonlandi, int toplam, int biten) {
    final kazanan = t['turKazanan']?.toString();
    final ikinci = t['turIkinci']?.toString();
    final ucuncu = t['turUcuncu']?.toString();
    final kaybeden = t['turKaybeden']?.toString();
    final podyumVar = [
      kazanan,
      ikinci,
      ucuncu,
      kaybeden,
    ].any((s) => s != null && s.isNotEmpty);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2740), Color(0xFF0E1626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentAmber.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentAmber.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              turnuvaNumaraRozeti(
                                widget.turnuvaNumara,
                                renk: AppColors.accentAmber,
                                font: 15,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (sonlandi
                                                ? AppColors.accentGreen
                                                : AppColors.accentAmber)
                                            .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!sonlandi) ...[
                                        const TurnuvaPulseDot(),
                                        const SizedBox(width: 6),
                                      ],
                                      Flexible(
                                        child: Text(
                                          sonlandi
                                              ? 'TAMAMLANDI'
                                              : 'DEVAM EDİYOR',
                                          style: TextStyle(
                                            color: sonlandi
                                                ? AppColors.accentGreen
                                                : AppColors.accentAmber,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t['turTarih']?.toString() ?? widget.turnuvaAdi,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.05,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    TurnuvaIlerlemeModulu(
                      toplam: toplam,
                      biten: biten,
                      sonlandi: sonlandi,
                    ),
                  ],
                ),

                // ✅ YATAY SCROLL KORUMALI PODIUM
                if (podyumVar) ...[
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        turnuvaMadalya(
                          '',
                          'Şampiyon',
                          kazanan,
                          const Color(0xFFFFD54F),
                        ),
                        turnuvaMadalya(
                          '',
                          'İkinci',
                          ikinci,
                          const Color(0xFFCFD8DC),
                        ),
                        turnuvaMadalya(
                          '🥉',
                          'Üçüncü',
                          ucuncu,
                          const Color(0xFFFFAB91),
                        ),
                        turnuvaMadalya(
                          '📉',
                          'Sonuncu',
                          kaybeden,
                          const Color(0xFFEF9A9A),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    turnuvaAksiyonKapsul(
                      icon: Icons.delete_outline,
                      etiket: 'Sil',
                      renk: AppColors.accentAmber,
                      onTap: _turnuvayiSil,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            turnuvaNumaraRozeti(widget.turnuvaNumara),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${widget.turnuvaAdi} Detayları',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detayFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentAmber),
            );
          }
          if (snapshot.hasError) {
            return turnuvaHataEkrani(
              snapshot.error.toString(),
              () => setState(
                () => _detayFuture = TurnuvaServisi().turnuvaDetayHesapla(
                  widget.turnuvaId,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Veri yüklenemedi.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final data = snapshot.data!;
          if (data['hata'] != null) {
            return turnuvaHataEkrani(
              data['hata'].toString(),
              () => setState(
                () => _detayFuture = TurnuvaServisi().turnuvaDetayHesapla(
                  widget.turnuvaId,
                ),
              ),
            );
          }

          final turData = data['turData'] as Map<String, dynamic>? ?? {};
          final oyunlar = data['oyunlar'] as List<dynamic>? ?? [];
          final toplam = data['toplamOyun'] as int? ?? 0;
          final biten = data['bitenOyun'] as int? ?? 0;
          final sonlandi = turData['turKazanan'] != null;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _banner(turData, sonlandi, toplam, biten),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        color: AppColors.accentAmber,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'OYUN GEÇMİŞİ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${oyunlar.length} kayıt',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ BOŞ TURNUVA ÖZEL GÖRÜNÜMÜ
              oyunlar.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: AppColors.divider,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bu turnuva boş olarak sonlandırılmış.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz hiç oyun oynanmamış veya veriler silinmiş.',
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              turnuvaOyunKarti(oyunlar[index], index),
                          childCount: oyunlar.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}
