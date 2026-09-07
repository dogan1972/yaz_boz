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
import 'package:yaz_boz/models/turnuva_model.dart';

class OyunlarSayfasi extends StatefulWidget {
  const OyunlarSayfasi({super.key});

  @override
  State<OyunlarSayfasi> createState() => _OyunlarSayfasiState();
}

class _OyunlarSayfasiState extends State<OyunlarSayfasi> {
  List<Oyun> _tumOyunlar = [];
  bool _gosterArsiv = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
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
          a[i].oyunTarih != b[i].oyunTarih ||
          a[i].aktifMi != b[i].aktifMi) {
        return false;
      }
    }
    return true;
  }

  Future<void> _oyunuSonlandir(Oyun oyun) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentAmber),
      ),
    );

    try {
      final ellerSnap = await OyunServisi().oyunElleriniGetir(oyun.id);
      final puan = <String, int>{};

      for (final o in oyun.oyuncu.split(', ')) {
        if (o.trim().isNotEmpty) puan[o.trim()] = 0;
      }

      for (final d in ellerSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final skorlar = data['skorlar'];
        final gmap = data['gostergeler'];
        final gtek = data['gosterge'];

        if (skorlar is Map) {
          skorlar.forEach((k, v) {
            final o = k.toString().trim();
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

            String hedefOyuncu = o;
            if (oyun.oyuncuIds != null && oyun.oyuncuIds!.isNotEmpty) {
              final uidMap = <String, String>{};
              final oyuncuIsimleri = oyun.oyuncu
                  .split(', ')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              for (
                var i = 0;
                i < oyuncuIsimleri.length && i < oyun.oyuncuIds!.length;
                i++
              ) {
                uidMap[oyuncuIsimleri[i]] = oyun.oyuncuIds![i];
              }
              final eslesenIsim = uidMap.entries
                  .firstWhere(
                    (e) => e.value == o,
                    orElse: () => MapEntry('', ''),
                  )
                  .key;
              if (eslesenIsim.isNotEmpty) hedefOyuncu = eslesenIsim;
            }

            if (puan.containsKey(hedefOyuncu)) {
              puan[hedefOyuncu] = (puan[hedefOyuncu] ?? 0) + s + g;
            }
          });
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (puan.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu oyunda henüz kayıtlı el yok.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final high = oyun.yuksekSkorKazanir;
      final sirali = puan.entries.toList()
        ..sort(
          high
              ? (a, b) => b.value.compareTo(a.value)
              : (a, b) => a.value.compareTo(b.value),
        );
      final kazanan = sirali.first.key;
      final kaybeden = sirali.last.key;

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

      String? kazananUid;
      String? kaybedenUid;
      if (oyun.oyuncuIds != null && oyun.oyuncuIds!.isNotEmpty) {
        final uidMap = <String, String>{};
        final oyuncuIsimleri = oyun.oyuncu
            .split(', ')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        for (
          var i = 0;
          i < oyuncuIsimleri.length && i < oyun.oyuncuIds!.length;
          i++
        ) {
          uidMap[oyuncuIsimleri[i]] = oyun.oyuncuIds![i];
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
        kazananUid,
        kaybedenUid,
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
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentAmber),
      ),
    );
    try {
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
                itemContext,
                MaterialPageRoute(
                  builder: (_) => EllerSayfasi(
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
                                    n: oyun.numara,
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
                                    ' ',
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
                              if (!itemContext.mounted) return;
                              String metin =
                                  "️ YAZ BOZ MAÇ SONUCU \n📅 Tarih: ${oyun.oyunTarih}\n Oyuncular: ${oyun.oyuncu}\n-----------------------------------\n KAZANAN: ${oyun.oyunKazanan}\n KAYBEDEN: ${oyun.oyunKaybeden}\n\nGüzel maçtı! ";
                              final uri = Uri.parse(
                                "whatsapp://send?text=${Uri.encodeComponent(metin)}",
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                await launchUrl(
                                  Uri.parse(
                                    "https://wa.me/?text=${Uri.encodeComponent(metin)}",
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
                                'Bu oyunu ve tüm ellerini silmek istediğine emin misin?',
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

  // lib/pages/oyunlar/oyunlar_sayfasi.dart içindeki _aktifHeroGorunumu metodu

  Widget _aktifHeroGorunumu(Oyun oyun) {
    final bool yatay =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EllerSayfasi(
              oyunId: oyun.id,
              isHighestWins: oyun.yuksekSkorKazanir,
            ),
          ),
        ),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 200,
            maxHeight: yatay
                ? MediaQuery.of(context).size.height * 0.8
                : double.infinity,
          ),
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
            child: yatay
                ? _yatayOyunKartiIcerigi(oyun)
                : _dikeyOyunKartiIcerigi(oyun),
          ),
        ),
      ),
    );
  }

  // ✅ YATAY MOD İÇİN AYRI WIDGET (Butonlar geri bağlandı)
  Widget _yatayOyunKartiIcerigi(Oyun oyun) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              oyunNumaraRozeti(
                n: oyun.numara,
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
              const SizedBox(height: 12),
              const Text(
                "YAZ BOZ DEFTERİ AÇIK",
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Kadro: ${oyun.oyuncu}",
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              // ✅ PAYLAŞ BUTONU GERİ BAĞLANDI
              _heroButon(Icons.share, AppColors.accentCyan, "Paylaş", () async {
                if (!mounted) return;
                String metin =
                    "️ YAZ BOZ MAÇI DEVAM EDİYOR \n📅 Tarih: ${oyun.oyunTarih}\n Masadakiler: ${oyun.oyuncu}\n Format: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu\n-----------------------------------\nMaç devam ediyor! ";
                final uri = Uri.parse(
                  "https://wa.me/?text=${Uri.encodeComponent(metin)}",
                );
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Hata: $e"),
                        backgroundColor: Colors.orange.shade800,
                      ),
                    );
                  }
                }
              }),

              // ✅ DÜZENLE BUTONU GERİ BAĞLANDI
              _heroButon(
                Icons.edit,
                AppColors.textPrimary,
                "Düzenle",
                () async {
                  if (!mounted) return;
                  final guncelOyuncular = await OyunServisi()
                      .tumOyunculariGetir();
                  if (!mounted) return;
                  final aktifTurnuva = await TurnuvaServisi().aktifTurnuvaBul();
                  final turnuvaList = aktifTurnuva != null
                      ? [
                          TurBilgisi(
                            id: aktifTurnuva.id,
                            turTarih: aktifTurnuva.turTarih ?? '',
                            turKazanan: aktifTurnuva.turKazanan,
                          ),
                        ]
                      : <TurBilgisi>[];
                  if (!mounted) return;
                  oyunFormuDiyalog(
                    context,
                    oyun: oyun,
                    guncelOyuncuListesi: guncelOyuncular,
                    turnuvalar: turnuvaList,
                  );
                },
              ),

              // ✅ SONLANDIR BUTONU GERİ BAĞLANDI
              _heroButon(
                Icons.flag,
                AppColors.accentGreen,
                "Sonlandır",
                () async => _oyunuSonlandir(oyun),
              ),

              // ✅ SİL BUTONU GERİ BAĞLANDI
              _heroButon(Icons.delete, Colors.amber.shade700, "Sil", () async {
                if (!mounted) return;
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
                      'Bu oyunu ve tüm verilerini silmek istediğine emin misin?',
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
                          style: TextStyle(color: AppColors.accentRed),
                        ),
                      ),
                    ],
                  ),
                );
                if (onay == true && mounted) await _oyunuSil(oyun);
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ DİKEY MOD İÇİN AYRI WIDGET (Butonlar zaten bağlıydı, aynen korundu)
  Widget _dikeyOyunKartiIcerigi(Oyun oyun) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  oyunNumaraRozeti(
                    n: oyun.numara,
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
        Flexible(
          child: Column(
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
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 8,
            children: [
              // ✅ DİKEY MODDA DA TÜM BUTONLAR BAĞLI
              oyunHeroAksiyonButonu(
                icon: Icons.share,
                renk: AppColors.accentCyan,
                etiket: "Paylaş",
                onTap: () async {
                  if (!mounted) return;
                  String metin =
                      "️ YAZ BOZ MAÇI DEVAM EDİYOR \n📅 Tarih: ${oyun.oyunTarih}\n Masadakiler: ${oyun.oyuncu}\n Format: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu\n-----------------------------------\nMaç devam ediyor! ";
                  final uri = Uri.parse(
                    "https://wa.me/?text=${Uri.encodeComponent(metin)}",
                  );
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Hata: $e"),
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
                  final aktifTurnuva = await TurnuvaServisi().aktifTurnuvaBul();
                  final turnuvaList = aktifTurnuva != null
                      ? [
                          TurBilgisi(
                            id: aktifTurnuva.id,
                            turTarih: aktifTurnuva.turTarih ?? '',
                            turKazanan: aktifTurnuva.turKazanan,
                          ),
                        ]
                      : <TurBilgisi>[];
                  if (!mounted) return;
                  oyunFormuDiyalog(
                    context,
                    oyun: oyun,
                    guncelOyuncuListesi: guncelOyuncular,
                    turnuvalar: turnuvaList,
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
                  if (!mounted) return;
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
                        'Bu oyunu ve tüm verilerini silmek istediğine emin misin?',
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
                            style: TextStyle(color: AppColors.accentRed),
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
    );
  }

  // ✅ BUTON OLUŞTURMA YARDIMCISI
  Widget _heroButon(
    IconData icon,
    Color renk,
    String etiket,
    VoidCallback onTap,
  ) {
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
          (o) => _gosterArsiv
              ? !o.aktifMi || o.oyunKazanan != null
              : o.aktifMi && o.oyunKazanan == null,
        )
        .toList();

    return StreamBuilder<Turnuva?>(
      stream: TurnuvaServisi().aktifTurnuvaStreami(),
      builder: (context, snapshot) {
        final bool aktifTurnuvaVar = snapshot.hasData && snapshot.data != null;

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
                      .where((o) => o.aktifMi && o.oyunKazanan == null)
                      .toList();

                  if (!_gosterArsiv && !aktifTurnuvaVar) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.block_outlined,
                              size: 64,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Aktif turnuva olmadan oyun açılamaz.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Lütfen önce yeni bir turnuva başlatın.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!_gosterArsiv && aktifOyun.isNotEmpty) {
                    return _aktifHeroGorunumu(aktifOyun.first);
                  }
                  if (oyunlarListesi.isEmpty) {
                    return Center(
                      child: Text(
                        _gosterArsiv
                            ? 'Arşivde hiç oyun bulunmuyor.'
                            : 'Aktif oyun bulunmuyor.',
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
                    onPressed: () =>
                        setState(() => _gosterArsiv = !_gosterArsiv),
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
                      side: const BorderSide(
                        color: AppColors.divider,
                        width: 1.5,
                      ),
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
              onPressed: !aktifTurnuvaVar
                  ? null
                  : () async {
                      if (!mounted) return;
                      final safeCtx = context;
                      final aktifTurnuva = snapshot.data;
                      if (aktifTurnuva == null) {
                        ScaffoldMessenger.of(safeCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "⚠️ Önce aktif bir TURNUVA oluşturmalısınız!",
                            ),
                            backgroundColor: Colors.orangeAccent,
                          ),
                        );
                        return;
                      }
                      final aktifSezon = await SezonServisi().aktifSezonBul();
                      if (aktifSezon == null) {
                        if (!safeCtx.mounted) return;
                        ScaffoldMessenger.of(safeCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "️ Önce aktif bir SEZON başlatmalısınız!",
                            ),
                            backgroundColor: Colors.orangeAccent,
                          ),
                        );
                        return;
                      }
                      final buGruptaAktifOyunVar = _tumOyunlar.any(
                        (o) => o.aktifMi && o.oyunKazanan == null,
                      );
                      if (buGruptaAktifOyunVar && safeCtx.mounted) {
                        ScaffoldMessenger.of(safeCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Zaten devam eden aktif bir oyun var!",
                            ),
                            backgroundColor: Colors.orangeAccent,
                          ),
                        );
                        return;
                      }
                      if (!safeCtx.mounted) return;
                      final guncelOyuncular = await OyunServisi()
                          .tumOyunculariGetir();
                      if (!safeCtx.mounted) return;
                      final turnuvaList = [
                        TurBilgisi(
                          id: aktifTurnuva.id,
                          turTarih: aktifTurnuva.turTarih ?? '',
                          turKazanan: aktifTurnuva.turKazanan,
                        ),
                      ];
                      oyunFormuDiyalog(
                        safeCtx,
                        guncelOyuncuListesi: guncelOyuncular,
                        turnuvalar: turnuvaList,
                      );
                    },
              backgroundColor: !aktifTurnuvaVar
                  ? AppColors.divider
                  : AppColors.accentAmber,
              child: Icon(
                Icons.add,
                color: !aktifTurnuvaVar
                    ? AppColors.textHint
                    : const Color(0xFF1A1206),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
