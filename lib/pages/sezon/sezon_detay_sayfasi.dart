import 'package:flutter/material.dart';
import 'package:yaz_boz/services/firestore_service.dart';

// ─────────────────────────────────────────────────────────────
// SEZON OYUNCU İSTATİSTİĞİ  (katılım = adın altındaki "N turnuva")
// ─────────────────────────────────────────────────────────────
class OyuncuSezonIstatistigi {
  final String ad;
  int trvKazanma = 0;
  int trvKaybetme = 0;
  int trvKatilim = 0; // ✅ adının geçtiği distinct turnuva sayısı
  int oyunGalibiyet = 0;
  int oyunMaglubiyet = 0;

  OyuncuSezonIstatistigi(this.ad);
}

class SezonDetaySayfasi extends StatefulWidget {
  final String sezonId;
  final String sezonAdi;
  final int? sezonNumara;

  const SezonDetaySayfasi({
    super.key,
    required this.sezonId,
    required this.sezonAdi,
    this.sezonNumara,
  });

  @override
  State<SezonDetaySayfasi> createState() => _SezonDetaySayfasiState();
}

class _SezonDetaySayfasiState extends State<SezonDetaySayfasi> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<Map<String, dynamic>> _istatistikFuture;

  @override
  void initState() {
    super.initState();
    _istatistikFuture = _sezonVerileriniHesapla(widget.sezonId);
  }

  Widget _numaraRozeti(int? n, {Color renk = Colors.white, double? font}) {
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

  // ───────────────────────────────────────────────────────────
  // HESAPLAMA — oyunlar + turnuvalar; katılım = distinct turId
  // ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _sezonVerileriniHesapla(String sId) async {
    try {
      final turnuvaSnap = await _firestoreService.getCollection('turnuva');
      final sezonTurnuvalari = turnuvaSnap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['sezonId'].toString() == sId.toString();
      }).toList();

      if (sezonTurnuvalari.isEmpty) return _bosVeriDondur();

      final Set<String> turIdSeti = sezonTurnuvalari.map((d) => d.id).toSet();

      final oyunlarSnap = await _firestoreService.getCollection('oyunlar');
      final sezonOyunlari = oyunlarSnap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return turIdSeti.contains(data['turId']?.toString());
      }).toList();

      final Map<String, OyuncuSezonIstatistigi> stats = {};
      OyuncuSezonIstatistigi of(String ad) =>
          stats.putIfAbsent(ad, () => OyuncuSezonIstatistigi(ad));

      final Map<String, Set<String>> oyuncuTurSeti = {};

      // Oyun G/M + katılım
      for (var doc in sezonOyunlari) {
        final data = doc.data() as Map<String, dynamic>;
        final kaybeden = data['oyunKaybeden']?.toString();
        final turId = data['turId']?.toString();
        if (data['oyuncu'] != null) {
          final katilimcilar = data['oyuncu']
              .toString()
              .split(RegExp(r'[,\n]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          for (var oyuncu in katilimcilar) {
            of(oyuncu);
            if (turId != null && turId.isNotEmpty) {
              oyuncuTurSeti.putIfAbsent(oyuncu, () => {}).add(turId);
            }
            if (kaybeden != null && kaybeden.isNotEmpty) {
              if (oyuncu == kaybeden) {
                of(oyuncu).oyunMaglubiyet++;
              } else {
                of(oyuncu).oyunGalibiyet++;
              }
            } else {
              of(oyuncu).oyunGalibiyet++;
            }
          }
        }
      }
      oyuncuTurSeti.forEach((ad, set) => of(ad).trvKatilim = set.length);

      // Trv G/M
      for (var doc in sezonTurnuvalari) {
        final data = doc.data() as Map<String, dynamic>;
        final tKazanan =
            data['turKazanan'] ?? data['sampiyon'] ?? data['kazanan'];
        final tKaybeden =
            data['turKaybeden'] ?? data['sonuncu'] ?? data['kaybeden'];
        if (tKazanan != null && tKazanan.toString().isNotEmpty) {
          of(tKazanan.toString()).trvKazanma++;
        }
        if (tKaybeden != null && tKaybeden.toString().isNotEmpty) {
          of(tKaybeden.toString()).trvKaybetme++;
        }
      }

      // Özet: şampiyon / sonuncu (ad + turnuva sayısı AYRI → kartta kısaltma yok)
      final kazanma = <String, int>{};
      final kaybetme = <String, int>{};
      stats.forEach((ad, s) {
        if (s.trvKazanma > 0) kazanma[ad] = s.trvKazanma;
        if (s.trvKaybetme > 0) kaybetme[ad] = s.trvKaybetme;
      });
      String sampiyonAd = '—';
      int sampiyonTrv = 0;
      if (kazanma.isNotEmpty) {
        final e = kazanma.entries.reduce((a, b) => a.value > b.value ? a : b);
        sampiyonAd = e.key;
        sampiyonTrv = e.value;
      }
      String sonuncuAd = '—';
      int sonuncuTrv = 0;
      if (kaybetme.isNotEmpty) {
        final e = kaybetme.entries.reduce((a, b) => a.value > b.value ? a : b);
        sonuncuAd = e.key;
        sonuncuTrv = e.value;
      }

      final liste = stats.values.toList();
      liste.sort((a, b) {
        if (b.trvKazanma != a.trvKazanma) {
          return b.trvKazanma.compareTo(a.trvKazanma);
        }
        if (b.oyunGalibiyet != a.oyunGalibiyet) {
          return b.oyunGalibiyet.compareTo(a.oyunGalibiyet);
        }
        return a.ad.compareTo(b.ad);
      });

      return {
        'toplamTurnuva': sezonTurnuvalari.length,
        'toplamOyun': sezonOyunlari.length,
        'sampiyonAd': sampiyonAd,
        'sampiyonTrv': sampiyonTrv,
        'sonuncuAd': sonuncuAd,
        'sonuncuTrv': sonuncuTrv,
        'detayListesi': liste,
      };
    } catch (e) {
      debugPrint('Sezon verileri hesaplanırken hata: $e');
      return _bosVeriDondur();
    }
  }

  Map<String, dynamic> _bosVeriDondur() => {
    'toplamTurnuva': 0,
    'toplamOyun': 0,
    'sampiyonAd': '—',
    'sampiyonTrv': 0,
    'sonuncuAd': '—',
    'sonuncuTrv': 0,
    'detayListesi': <OyuncuSezonIstatistigi>[],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numaraRozeti(widget.sezonNumara),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${widget.sezonAdi} Detayları',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _istatistikFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            );
          }
          if (snapshot.hasError) return _hataEkrani(snapshot.error.toString());
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Veri yüklenemedi.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            );
          }

          final data = snapshot.data!;
          final liste = data['detayListesi'] as List<OyuncuSezonIstatistigi>;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ozetKart(
                        'Toplam Turnuva',
                        '${data['toplamTurnuva']}',
                        Icons.flag_rounded,
                        const Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ozetKart(
                        'Toplam Oyun',
                        '${data['toplamOyun']}',
                        Icons.sports_esports_rounded,
                        const Color(0xFFA78BFA),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ozetKartAd(
                        'Sezon Şampiyonu',
                        data['sampiyonAd'] ?? '—',
                        data['sampiyonTrv'] ?? 0,
                        Icons.emoji_events_rounded,
                        const Color(0xFFFCD34D),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ozetKartAd(
                        'Sezon Sonuncusu',
                        data['sonuncuAd'] ?? '—',
                        data['sonuncuTrv'] ?? 0,
                        Icons.trending_down_rounded,
                        const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'SEZON OYUNCU KARNESİ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.4,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${liste.length} oyuncu',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                liste.isEmpty ? _bosKarme() : _karmeTablosu(liste),
              ],
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // ÖZET KART (sayı) — tok, büyük, tek satır
  // ───────────────────────────────────────────────────────────
  Widget _ozetKart(String baslik, String deger, IconData icon, Color renk) {
    return _kartCerceve(
      renk: renk,
      icon: icon,
      baslik: baslik,
      degerWidget: Text(
        deger,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFFF8FAFC),
          height: 1.05,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // ÖZET KART (ad) — KISALTMA YOK: ad + alt satırda "N Turnuva"
  // ───────────────────────────────────────────────────────────
  Widget _ozetKartAd(
    String baslik,
    String ad,
    int trv,
    IconData icon,
    Color renk,
  ) {
    return _kartCerceve(
      renk: renk,
      icon: icon,
      baslik: baslik,
      degerWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ad,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF8FAFC),
              height: 1.1,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$trv Turnuva',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: renk.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ortak kart iskeleti — sol accent şerit + renkli ikon kutusu
  Widget _kartCerceve({
    required Color renk,
    required IconData icon,
    required String baslik,
    required Widget degerWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: renk.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: renk),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: renk.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: renk, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            baslik,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          degerWidget,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // KARNE TABLOSU — sıra: Oyuncu · Oyun G/M · Trv. G/M
  // ───────────────────────────────────────────────────────────
  Widget _karmeTablosu(List<OyuncuSezonIstatistigi> liste) {
    final liderAd =
        liste.isNotEmpty &&
            (liste.first.trvKazanma > 0 || liste.first.oyunGalibiyet > 0)
        ? liste.first.ad
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.4),
          1: FlexColumnWidth(1.3),
          2: FlexColumnWidth(1.3),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: const BorderSide(color: Color(0xFF1E293B)),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            children: [
              _baslikHucresi('Oyuncu', align: TextAlign.left),
              _baslikHucresi('Oyun G/M'),
              _baslikHucresi('Trv. G/M'),
            ],
          ),
          for (var i = 0; i < liste.length; i++)
            _karneSatiri(
              liste[i],
              zebra: i.isOdd,
              lider: liste[i].ad == liderAd,
            ),
        ],
      ),
    );
  }

  TableRow _karneSatiri(
    OyuncuSezonIstatistigi p, {
    required bool zebra,
    required bool lider,
  }) {
    final bg = lider
        ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
        : (zebra ? const Color(0xFF0F172A) : const Color(0xFF111A2B));

    final int trvG = (p.trvKatilim - p.trvKaybetme).clamp(0, 999);
    final int trvM = p.trvKaybetme;
    final bool trvVar = p.trvKatilim > 0;
    final Color trvRenk = !trvVar
        ? const Color(0xFF94A3B8)
        : (trvG > trvM
              ? const Color(0xFF4ADE80)
              : (trvM > trvG
                    ? const Color(0xFFF87171)
                    : const Color(0xFF94A3B8)));

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lider)
                const Padding(
                  padding: EdgeInsets.only(right: 6, top: 1),
                  child: Text('🏆', style: TextStyle(fontSize: 13)),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: lider
                            ? const Color(0xFFFCD34D)
                            : const Color(0xFFF8FAFC),
                      ),
                    ),
                    if (p.trvKatilim > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${p.trvKatilim} turnuva',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          child: Text(
            '${p.oyunGalibiyet}/${p.oyunMaglubiyet}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: p.oyunGalibiyet > p.oyunMaglubiyet
                  ? const Color(0xFF4ADE80)
                  : (p.oyunMaglubiyet > p.oyunGalibiyet
                        ? const Color(0xFFF87171)
                        : const Color(0xFF94A3B8)),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          child: Text(
            trvVar ? '$trvG/$trvM' : '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: trvRenk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _baslikHucresi(String t, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
      child: Text(
        t,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _bosKarme() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.group_off_outlined,
            size: 40,
            color: Color(0xFF334155),
          ),
          const SizedBox(height: 10),
          const Text(
            'Bu sezonda henüz oyuncu kaydı yok.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Oyunlar oynandıkça karne burada dolacak.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _hataEkrani(String hata) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Color(0xFFFCA5A5), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Veri yüklenirken hata oluştu',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFFFCA5A5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hata,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => setState(
                () =>
                    _istatistikFuture = _sezonVerileriniHesapla(widget.sezonId),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF1A1206),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
