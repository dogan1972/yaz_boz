// lib/pages/eller/yazboz_tahtasi.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/models/el_model.dart';
import 'package:yaz_boz/models/oyun_model.dart';
import 'package:yaz_boz/pages/eller/yazboz_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class YazbozTahtasi extends StatelessWidget {
  final List<El> oyunElleri;
  final List<String> aktifOyuncular;
  final Oyun? seciliOyun;
  final void Function(El el) onElTap;
  final bool kilitli;
  final bool isHighestWins;

  // ✅ YENİ: İsim -> UID Eşleştirme Haritası
  final Map<String, String>? oyuncuUidMap;

  const YazbozTahtasi({
    super.key,
    required this.oyunElleri,
    required this.aktifOyuncular,
    required this.seciliOyun,
    required this.onElTap,
    this.kilitli = false,
    this.isHighestWins = false,
    this.oyuncuUidMap, // ✅ YENİ PARAMETRE
  });

  bool get _esliOyun =>
      seciliOyun?.esliMi == true && aktifOyuncular.length == 4;

  // ✅ YARDIMCI METOD: İsmi UID'ye Çevir
  String _getUid(String oyuncuAdi) {
    return oyuncuUidMap?[oyuncuAdi] ?? oyuncuAdi;
  }

  // ✅ GÜNCELLENMİŞ: Gösterge Okuma (UID Desteği)
  int? _gosterge(El el, String oyuncuAdi) {
    final uid = _getUid(oyuncuAdi);
    // Önce UID ile ara, bulunamazsa isimle ara (geriye dönük uyumluluk)
    return el.gostergeMap[uid] ?? el.gostergeMap[oyuncuAdi] ?? el.gosterge;
  }

  @override
  Widget build(BuildContext context) {
    if (oyunElleri.isEmpty || aktifOyuncular.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, size: 56, color: AppColors.divider),
              const SizedBox(height: 12),
              const Text(
                'Henüz hiç el skoru girilmemiş.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kilitli
                    ? 'Bu oyun kayıtsız kapanmış.'
                    : 'İlk eli eklemek için + butonuna dokun.',
                style: const TextStyle(color: AppColors.textHint, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ DİNAMİK GENİŞLİK HESAPLAMA
    final ekranGenisligi = MediaQuery.of(context).size.width;
    const solEtiketW = 68.0;
    final sutunSayisi = _esliOyun ? 2 : aktifOyuncular.length;

    final minSutunW = 56.0;
    final kullanilabilirW = ekranGenisligi - solEtiketW - 20;
    final dinamikSutunW = (kullanilabilirW / sutunSayisi).clamp(
      minSutunW,
      double.infinity,
    );

    final genislikler = <int, TableColumnWidth>{
      0: const FixedColumnWidth(solEtiketW),
    };

    for (var i = 1; i <= sutunSayisi; i++) {
      genislikler[i] = FixedColumnWidth(dinamikSutunW);
    }

    final sirali = List<El>.from(oyunElleri)
      ..sort((a, b) {
        if (a.elNo != b.elNo) return a.elNo.compareTo(b.elNo);
        return (a.elTarih ?? '').compareTo(b.elTarih ?? '');
      });

    final gruplar = <String, List<El>>{};
    for (final el in sirali) {
      gruplar.putIfAbsent('${el.elNo}', () => []).add(el);
    }

    final anahtarlar = gruplar.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a), nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });

    // ✅ GÜNCELLENMİŞ TOPLAM HESAPLAMA: UID DESTEKLİ
    final toplam = <String, int>{for (final o in aktifOyuncular) o: 0};
    final gostergeler = <String, List<int>>{
      for (final o in aktifOyuncular) o: <int>[],
    };

    for (final el in sirali) {
      el.skorlar.forEach((key, skor) {
        // Key UID veya İsim olabilir. Hangi oyuncuya ait olduğunu bul.
        String? eslesenOyuncu;

        // 1. Doğrudan isim eşleşmesi var mı?
        if (aktifOyuncular.contains(key)) {
          eslesenOyuncu = key;
        }
        // 2. UID eşleşmesi var mı?
        else {
          eslesenOyuncu = oyuncuUidMap?.entries
              .firstWhere((e) => e.value == key, orElse: () => MapEntry('', ''))
              .key;
        }

        if (eslesenOyuncu != null && eslesenOyuncu.isNotEmpty) {
          final g = _gosterge(el, eslesenOyuncu) ?? 0;
          toplam[eslesenOyuncu] = (toplam[eslesenOyuncu] ?? 0) + skor + g;

          final gVal = _gosterge(el, eslesenOyuncu);
          if (gVal != null && gVal != 0) {
            gostergeler.putIfAbsent(eslesenOyuncu, () => []).add(gVal);
          }
        }
      });
    }

    final maxGosterge = gostergeler.values.fold<int>(
      1,
      (m, l) => l.length > m ? l.length : m,
    );

    final sonucDegerleri = _esliOyun
        ? [for (var i = 0; i < 2; i++) _esToplam(i, toplam)]
        : [for (final o in aktifOyuncular) toplam[o] ?? 0];
    final siraliSonuc = List<int>.from(sonucDegerleri)..sort();
    final vurguAcik =
        siraliSonuc.isNotEmpty && siraliSonuc.first != siraliSonuc.last;
    final liderD = isHighestWins ? siraliSonuc.last : siraliSonuc.first;
    final sonuncD = isHighestWins ? siraliSonuc.first : siraliSonuc.last;

    final basliklar = <Widget>[];
    if (_esliOyun) {
      final takim1 = "${aktifOyuncular[0]} – ${aktifOyuncular[2]}";
      final takim2 = "${aktifOyuncular[1]} – ${aktifOyuncular[3]}";
      basliklar.add(ybBaslik(takim1, maxLines: 2));
      basliklar.add(ybBaslik(takim2, maxLines: 2));
    } else {
      for (var i = 0; i < aktifOyuncular.length; i++) {
        basliklar.add(ybBaslik(aktifOyuncular[i]));
      }
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kilitli
                  ? AppColors.divider
                  : AppColors.accentAmber.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: kilitli ? 0.25 : 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              child: Table(
                columnWidths: genislikler,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.border),
                  verticalInside: BorderSide(color: AppColors.border),
                ),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.border, AppColors.bgSecondary],
                      ),
                    ),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox.shrink(),
                      ),
                      ...basliklar,
                    ],
                  ),
                  for (var r = 0; r < maxGosterge; r++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppColors.accentRed.withValues(alpha: 0.08),
                      ),
                      children: [
                        ybHucre(
                          r == 0 ? 'Gösterge' : '',
                          color: AppColors.accentRed,
                          weight: FontWeight.w700,
                          size: 10,
                        ),
                        if (_esliOyun)
                          for (var i = 0; i < 2; i++)
                            ybHucre(
                              _esGosterge(i, r, gostergeler).toString(),
                              color: const Color(0xFFFCA5A5),
                              weight: FontWeight.w800,
                              size: 14,
                            )
                        else
                          for (final o in aktifOyuncular)
                            ybHucre(
                              (gostergeler[o] ?? const []).length > r
                                  ? (gostergeler[o]![r]).toString()
                                  : '',
                              color: const Color(0xFFFCA5A5),
                              weight: FontWeight.w800,
                              size: 14,
                            ),
                      ],
                    ),
                  for (var idx = 0; idx < anahtarlar.length; idx++)
                    _elSatiri(
                      anahtarlar[idx],
                      gruplar[anahtarlar[idx]]!,
                      zebra: idx.isOdd,
                      kilitli: kilitli,
                    ),
                  TableRow(
                    decoration: BoxDecoration(
                      color: kilitli
                          ? AppColors.border
                          : AppColors.accentAmber.withValues(alpha: 0.10),
                    ),
                    children: [
                      ybHucre(
                        'SONUÇ',
                        color: kilitli
                            ? AppColors.textSecondary
                            : AppColors.accentAmber,
                        weight: FontWeight.w900,
                        size: 12,
                      ),
                      if (_esliOyun)
                        for (var i = 0; i < 2; i++)
                          ybSonucHucresi(
                            _esToplam(i, toplam),
                            liderD,
                            sonuncD,
                            vurguAcik,
                            kilitli,
                          )
                      else
                        for (final o in aktifOyuncular)
                          ybSonucHucresi(
                            toplam[o] ?? 0,
                            liderD,
                            sonuncD,
                            vurguAcik,
                            kilitli,
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _elSatiri(
    String key,
    List<El> grup, {
    required bool zebra,
    required bool kilitli,
  }) {
    final etiket = int.tryParse(key) != null ? '$key.' : key;
    final el = grup.first;
    final skorRengi = kilitli ? AppColors.textSecondary : AppColors.textPrimary;

    return TableRow(
      decoration: BoxDecoration(
        color: zebra ? AppColors.bgSecondary : AppColors.cardBg,
      ),
      children: [
        ybHucre(
          etiket,
          weight: FontWeight.w800,
          size: 12,
          color: kilitli ? AppColors.textSecondary : AppColors.textHint,
        ),
        if (_esliOyun)
          for (var i = 0; i < 2; i++)
            kilitli
                ? ybHucre(
                    _esElSkor(i, grup).toString(),
                    color: skorRengi,
                    weight: FontWeight.w700,
                    size: 14,
                  )
                : ybTiklanabilirHucre(
                    () => onElTap(el),
                    _esElSkor(i, grup).toString(),
                  )
        else
          // ✅ GÜNCELLENMİŞ: Tekil Oyuncu Skorlarını UID ile Oku
          for (final o in aktifOyuncular)
            kilitli
                ? ybHucre(
                    _tekilSkor(el, o).toString(),
                    color: skorRengi,
                    weight: FontWeight.w700,
                    size: 14,
                  )
                : ybTiklanabilirHucre(
                    () => onElTap(el),
                    _tekilSkor(el, o).toString(),
                  ),
      ],
    );
  }

  // ✅ YENİ YARDIMCI METOD: Tekil Oyuncu Skorunu UID ile Oku
  int _tekilSkor(El el, String oyuncuAdi) {
    final uid = _getUid(oyuncuAdi);
    // Önce UID ile ara, yoksa isimle ara
    final s = el.skorlar[uid] ?? el.skorlar[oyuncuAdi] ?? 0;
    final g = _gosterge(el, oyuncuAdi) ?? 0;
    return s + g;
  }

  // ✅ GÜNCELLENMİŞ: Çapraz Eşleme (UID Desteği)
  int _esGosterge(int es, int row, Map<String, List<int>> g) {
    var t = 0;
    for (var j = 0; j < 2; j++) {
      final idx = es + j * 2;
      final l = g[aktifOyuncular[idx]] ?? const [];
      if (l.length > row) t += l[row];
    }
    return t;
  }

  // ✅ GÜNCELLENMİŞ: Eşli El Skoru (UID Desteği)
  int _esElSkor(int es, List<El> grup) {
    var t = 0;
    for (var j = 0; j < 2; j++) {
      final idx = es + j * 2;
      final o = aktifOyuncular[idx];
      t += _tekilSkor(grup.first, o);
    }
    return t;
  }

  // ✅ GÜNCELLENMİŞ: Eşli Toplam (UID Desteği)
  int _esToplam(int es, Map<String, int> toplam) {
    var t = 0;
    for (var j = 0; j < 2; j++) {
      final idx = es + j * 2;
      t += toplam[aktifOyuncular[idx]] ?? 0;
    }
    return t;
  }
}
