// lib/pages/oyunlar/oyunlar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/services/oyun_servisi.dart';
import 'package:yaz_boz/services/sezon_servisi.dart';
import 'package:yaz_boz/services/turnuva_servisi.dart';
import 'package:yaz_boz/pages/eller/eller_sayfasi.dart';
import 'package:yaz_boz/models/oyun_model.dart';
import 'package:yaz_boz/pages/oyunlar/oyun_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class OyunlarSayfasi extends StatefulWidget {
  const OyunlarSayfasi({super.key});

  @override
  State<OyunlarSayfasi> createState() => _OyunlarSayfasiState();
}

class _OyunlarSayfasiState extends State<OyunlarSayfasi> {
  List<Oyun> _tumOyunlar = [];
  List<TurBilgisi> _turnuvalar = [];
  bool _gosterArsiv = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
    _yardimciVerileriYukle();
  }

  void _verileriDinle() {
    OyunServisi().tumOyunlarStreami().listen((yeniOyunlar) {
      if (!mounted) return;
      if (yeniOyunlar.length != _tumOyunlar.length ||
          !_listelerEsitMi(yeniOyunlar, _tumOyunlar)) {
        setState(() {
          _tumOyunlar = yeniOyunlar;
          _isLoading = false;
        });
      } else if (_isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  bool _listelerEsitMi(List<Oyun> a, List<Oyun> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].oyunKazanan != b[i].oyunKazanan ||
          a[i].oyunTarih != b[i].oyunTarih) {
        return false;
      }
    }
    return true;
  }

  Future<void> _yardimciVerileriYukle() async {
    try {
      final aktifTurnuva = await TurnuvaServisi().aktifTurnuvaBul();
      if (!mounted) return;
      setState(() {
        _turnuvalar = aktifTurnuva != null
            ? [
                TurBilgisi(
                  id: aktifTurnuva.id,
                  turTarih: aktifTurnuva.turTarih ?? '',
                  turKazanan: aktifTurnuva.turKazanan,
                ),
              ]
            : [];
      });
    } catch (e) {
      debugPrint("❌ Yardımcı veri hatası: $e");
    }
  }

  // ✅ UID DESTEKLİ OYUN SONLANDIRMA METODU
  Future<void> _oyunuSonlandir(Oyun oyun) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: AppColors.accentAmber),
        ),
      );

      final ellerSnap = await OyunServisi().oyunElleriniGetir(oyun.id);
      final puan = <String, int>{};

      // Oyuncu isimlerini başlat
      for (final o in oyun.oyuncu.split(', ')) {
        if (o.trim().isNotEmpty) puan[o.trim()] = 0;
      }

      // Puanları topla
      for (final d in ellerSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final skorlar = data['skorlar'];
        final gmap = data['gostergeler'];
        final gtek = data['gosterge'];

        if (skorlar is Map) {
          skorlar.forEach((k, v) {
            final o = k.toString();
            final s = (v is num)
                ? v.toInt()
                : (int.tryParse(v.toString()) ?? 0);
            int g = 0;

            if (gmap is Map && gmap[k] != null) {
              final gv = gmap[k];
              g = (gv is num) ? gv.toInt() : (int.tryParse(gv.toString()) ?? 0);
            } else if (gtek is num) {
              g = gtek.toInt();
            }

            puan[o] = (puan[o] ?? 0) + s + g;
          });
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Loading'i kapat

      if (puan.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu oyunda henüz kayıtlı el yok — sonlandırılamaz.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      // Sıralama yap
      final high = oyun
          .yuksekSkorKazanir; // Eski kodda esliMi kullanılmıştı ama yuksekSkorKazanir olmalı
      final sirali = puan.entries.toList()
        ..sort(
          high
              ? (a, b) =>
                    b.value.compareTo(a.value) // Yüksek kazanır
              : (a, b) => a.value.compareTo(b.value), // Düşük kazanır
        );

      final kazanan = sirali.first.key;
      final kaybeden = sirali.last.key;

      // Onay Dialogu
      final onay = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.accentAmber, size: 26),
              SizedBox(width: 8),
              Text('Oyunu Sonlandır', style: AppTextStyles.bodyPrimary),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  high ? '(En yüksek skor kazanır)' : '(En düşük skor kazanır)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                ...sirali.take(4).map((p) {
                  final isK = p.key == kazanan;
                  final isS = p.key == kaybeden;
                  final emoji = isK ? '' : (isS ? '' : '·');
                  final renk = isK
                      ? AppColors.accentGreen
                      : (isS ? AppColors.accentRed : AppColors.textPrimary);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            p.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${p.value}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: renk,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('İptal', style: AppTextStyles.bodySecondary),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(d, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentAmber,
                foregroundColor: const Color(0xFF1A1206),
              ),
              child: const Text(
                'Sonlandır',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

      if (onay != true || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // ✅ UID EŞLEŞTİRME VE GÖNDERME
      String? kazananUid;
      String? kaybedenUid;

      if (oyun.oyuncuIds != null && oyun.oyuncuIds!.isNotEmpty) {
        final uidMap = <String, String>{};
        final isimler = oyun.oyuncu.split(',').map((e) => e.trim()).toList();

        // İsimleri UID'lerle eşleştir
        for (var i = 0; i < isimler.length && i < oyun.oyuncuIds!.length; i++) {
          uidMap[isimler[i]] = oyun.oyuncuIds![i];
        }

        kazananUid = uidMap[kazanan];
        kaybedenUid = uidMap[kaybeden];
      }

      await OyunServisi().oyunuSonlandir(
        oyun.id,
        kazanan,
        kaybeden,
        sirali.length > 1 ? sirali[1].key : null,
        sirali.length > 2 ? sirali[2].key : null,
        kazananUid, // ✅ KAZANAN UID
        kaybedenUid, // ✅ KAYBEDEN UID
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(' Oyun sonlandı — Şampiyon: $kazanan'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, st) {
      debugPrint('❌ oyun sonlandırma hatası: $e\n$st');
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sonlandırma hatası: $e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Future<void> _oyunuSil(Oyun oyun) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: AppColors.accentAmber),
        ),
      );

      await OyunServisi().oyunuSil(oyun.id);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Oyun ve altındaki el skorları silindi.")),
      );
    } catch (e) {
      debugPrint("Silme hatası: $e");
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Silme sırasında hata oluştu: $e"),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Widget _arsivListeGorunumu(List<Oyun> oyunlar) {
    return ListView.builder(
      itemCount: oyunlar.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (itemContext, index) {
        final oyun = oyunlar[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EllerSayfasi(
                    oyunId: oyun.id,
                    isHighestWins: oyun.yuksekSkorKazanir,
                  ),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  oyunNumaraRozeti(
                                    oyun.numara,
                                    renk: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      oyun.oyunTarih,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Transform.rotate(
                                    angle: -0.12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.textHint.withValues(
                                            alpha: 0.55,
                                          ),
                                          width: 1.4,
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        'ARŞİV',
                                        style: TextStyle(
                                          color: AppColors.textHint,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                " ${oyun.oyuncu}",
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    '🏆 ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  Expanded(
                                    child: Text(
                                      oyun.oyunKazanan ?? '—',
                                      style: const TextStyle(
                                        color: AppColors.accentAmber,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Text(
                                    '  ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  Flexible(
                                    child: Text(
                                      oyun.oyunKaybeden ?? '—',
                                      style: const TextStyle(
                                        color: AppColors.accentRed,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              if (!context.mounted) return;
                              String paylasimMetni =
                                  "✍️ YAZ BOZ MAÇ SONUCU \n📅 Tarih: ${oyun.oyunTarih}\n👥 Oyuncular: ${oyun.oyuncu}\n-----------------------------------\n🏆 KAZANAN LİDER: ${oyun.oyunKazanan}\n📉 CEZA GÜZELİ: ${oyun.oyunKaybeden}\n\nGüzel maçtı, elinize sağlık! ";
                              final Uri whatsappUrl = Uri.parse(
                                "whatsapp://send?text=${Uri.encodeComponent(paylasimMetni)}",
                              );
                              if (await canLaunchUrl(whatsappUrl)) {
                                await launchUrl(
                                  whatsappUrl,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                await launchUrl(
                                  Uri.parse(
                                    "https://wa.me/?text=${Uri.encodeComponent(paylasimMetni)}",
                                  ),
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accentPurple.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.accentPurple.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.share_outlined,
                                color: AppColors.accentPurple,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      oyunSilDugmesi(
                        onTap: () async {
                          final onay = await showDialog<bool>(
                            context: itemContext,
                            builder: (d) => AlertDialog(
                              backgroundColor: AppColors.cardBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: const Text(
                                'Oyunu Sil',
                                style: AppTextStyles.bodyPrimary,
                              ),
                              content: const Text(
                                'Bu oyunu sildiğinizde oyuna ait girilmiş TÜM eller de silinecektir. Onaylıyor musunuz?',
                                style: AppTextStyles.bodySecondary,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text(
                                    'İptal',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text(
                                    'Sil',
                                    style: TextStyle(
                                      color: AppColors.accentAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (onay == true && mounted) await _oyunuSil(oyun);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _aktifHeroGorunumu(Oyun oyun) {
    final double ekranYuksekligi = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EllerSayfasi(
              oyunId: oyun.id,
              isHighestWins: oyun.yuksekSkorKazanir,
            ),
          ),
        ),
        child: Container(
          height: ekranYuksekligi * 0.55,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2740), Color(0xFF0E1626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: AppColors.accentAmber.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentAmber.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          oyunNumaraRozeti(
                            oyun.numara,
                            renk: AppColors.accentAmber,
                            font: 15,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Masa: ${oyun.oyunTarih}",
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentAmber.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.accentAmber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.style,
                        color: AppColors.accentAmber,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_filled,
                      color: AppColors.accentGreen,
                      size: 54,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "YAZ BOZ DEFTERİ AÇIK",
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Kadro: ${oyun.oyuncu}\nFormat: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      oyunHeroAksiyonButonu(
                        icon: Icons.share,
                        renk: AppColors.accentCyan,
                        etiket: "Paylaş",
                        onTap: () async {
                          if (!context.mounted) return;
                          String paylasimMetni =
                              "✍️ YAZ BOZ MAÇI DEVAM EDİYOR \n📅 Tarih: ${oyun.oyunTarih}\n Masadakiler: ${oyun.oyuncu}\n🎮 Format: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu\n-----------------------------------\nMaç henüz sonlanmadı, defterde heyecan dorukta! ";
                          final Uri whatsappUrl = Uri.parse(
                            "https://wa.me/?text=${Uri.encodeComponent(paylasimMetni)}",
                          );
                          try {
                            if (await canLaunchUrl(whatsappUrl)) {
                              await launchUrl(
                                whatsappUrl,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "WhatsApp açılırken bir sorun oluştu: $e",
                                  ),
                                  backgroundColor: Colors.orange.shade800,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      oyunHeroAksiyonButonu(
                        icon: Icons.edit,
                        renk: AppColors.textPrimary,
                        etiket: "Düzenle",
                        onTap: () async {
                          if (!mounted) return;
                          final guncelOyuncular = await OyunServisi()
                              .tumOyunculariGetir();
                          if (!mounted) return;
                          oyunFormuDiyalog(
                            context,
                            oyun: oyun,
                            guncelOyuncuListesi: guncelOyuncular,
                            turnuvalar: _turnuvalar,
                          );
                        },
                      ),
                      oyunHeroAksiyonButonu(
                        icon: Icons.flag,
                        renk: AppColors.accentGreen,
                        etiket: "Sonlandır",
                        onTap: () async => _oyunuSonlandir(oyun),
                      ),
                      oyunHeroAksiyonButonu(
                        icon: Icons.delete,
                        renk: Colors.amber.shade700,
                        etiket: "Sil",
                        onTap: () async {
                          bool? onay = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              backgroundColor: AppColors.cardBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: const Text(
                                'Oyunu Sil',
                                style: AppTextStyles.bodyPrimary,
                              ),
                              content: const Text(
                                'Bu oyunu sildiğinizde girilmiş TÜM skor tablosu yok olacaktır. Onaylıyor musunuz?',
                                style: AppTextStyles.bodySecondary,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text(
                                    'İptal',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text(
                                    'Sil',
                                    style: TextStyle(
                                      color: AppColors.accentRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (onay == true && mounted) await _oyunuSil(oyun);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentAmber),
        ),
      );
    }

    final oyunlarListesi = _tumOyunlar
        .where(
          (o) => _gosterArsiv ? o.oyunKazanan != null : o.oyunKazanan == null,
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuçlanan Oyunlar' : 'Aktif Oyunlar',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: (() {
              final aktifOyun = _tumOyunlar
                  .where((o) => o.oyunKazanan == null)
                  .toList();
              if (!_gosterArsiv && aktifOyun.isNotEmpty) {
                return _aktifHeroGorunumu(aktifOyun.first);
              }
              if (oyunlarListesi.isEmpty) {
                return Center(
                  child: Text(
                    _gosterArsiv
                        ? 'Arşivde hiç oyun bulunmuyor.'
                        : 'Aktif (devam eden) oyun bulunmuyor.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return _gosterArsiv
                  ? _arsivListeGorunumu(oyunlarListesi)
                  : _aktifHeroGorunumu(oyunlarListesi.first);
            })(),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 90.0,
              top: 12.0,
              bottom: 80.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _gosterArsiv = !_gosterArsiv),
                icon: Icon(
                  _gosterArsiv ? Icons.play_circle_outline : Icons.history,
                  color: AppColors.textPrimary,
                ),
                label: Text(
                  _gosterArsiv ? "Aktif Oyunlara Dön" : "Eski Oyunlar",
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.divider, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () async {
            final currentContext = context;
            if (!currentContext.mounted) return;
            final messenger = ScaffoldMessenger.of(currentContext);

            final aktifSezon = await SezonServisi().aktifSezonBul();
            if (aktifSezon == null) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    "⚠️ Manuel oyun eklemek için önce aktif bir SEZON başlatmalısınız!",
                  ),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }

            if (_turnuvalar.isEmpty) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    "Oyun başlatabilmek için önce aktif bir TURNUVA oluşturmalısınız!",
                  ),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }

            final buGruptaAktifOyunVar = _tumOyunlar.any(
              (o) => o.oyunKazanan == null,
            );
            if (buGruptaAktifOyunVar && currentContext.mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    "Bu grupta zaten devam eden aktif bir oyun bulunuyor!",
                  ),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }

            if (!currentContext.mounted) return;
            final guncelOyuncular = await OyunServisi().tumOyunculariGetir();
            if (!currentContext.mounted) return;

            oyunFormuDiyalog(
              currentContext,
              guncelOyuncuListesi: guncelOyuncular,
              turnuvalar: _turnuvalar,
            );
          },
          backgroundColor: AppColors.accentAmber,
          child: const Icon(Icons.add, color: Color(0xFF1A1206)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
