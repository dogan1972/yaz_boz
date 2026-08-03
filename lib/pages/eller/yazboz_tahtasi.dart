import 'package:flutter/material.dart';
import 'package:yaz_boz/pages/oyunlar/oyunlar_sayfasi.dart';

// ─────────────────────────────────────────────────────────────
// EL MODELİ  (+ oyuncu başına gösterge: gostergeMap)
// ─────────────────────────────────────────────────────────────
class El {
  final String id;
  final String oyunId;
  final String elTarih;
  final Map<String, int> skorlar;
  final Map<String, int> gostergeMap;
  final int? gosterge;
  final int? elNo;

  const El({
    required this.id,
    required this.oyunId,
    required this.elTarih,
    required this.skorlar,
    this.gostergeMap = const {},
    this.gosterge,
    this.elNo,
  });

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory El.fromFirestore(dynamic doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);

    final skorlar = <String, int>{};
    final raw = data['skorlar'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final n = _toInt(v);
        if (n != null) skorlar[k.toString()] = n;
      });
    }

    final gostergeMap = <String, int>{};
    final graw = data['gostergeler'];
    if (graw is Map) {
      graw.forEach((k, v) {
        final n = _toInt(v);
        if (n != null && n != 0) gostergeMap[k.toString()] = n;
      });
    }

    return El(
      id: doc.id as String,
      oyunId: data['oyunId']?.toString() ?? '',
      elTarih: data['elTarih']?.toString() ?? '',
      skorlar: skorlar,
      gostergeMap: gostergeMap,
      gosterge: _toInt(data['gosterge']),
      elNo: _toInt(data['elNo']),
    );
  }

  Map<String, dynamic> toMap() => {
    'oyunId': oyunId,
    'elTarih': elTarih,
    'skorlar': skorlar,
    'gostergeler': gostergeMap,
    'gosterge': gosterge,
    'elNo': elNo,
  };
}

// ─────────────────────────────────────────────────────────────
// YAZ BOZ TAHTASI  — ÇİFT YÖNLÜ KAYDIRMA + AKILLI SÜTUN GENİŞLİĞİ
//   • 4 oyuncuya kadar tablo ekrana TAM yayılır (kaydırmasız, boşluksuz).
//   • 5+ oyuncuda sütunlar 64'e kilitlenir + YATAY kaydırma (kesilme yok).
//   • Dikey kaydırmada FAB payı → SONUÇ satırı asla örtülmez.
// ─────────────────────────────────────────────────────────────
class YazbozTahtasi extends StatelessWidget {
  final List<El> oyunElleri;
  final List<String> aktifOyuncular;
  final Oyun? seciliOyun;
  final void Function(El el) onElTap;
  final bool kilitli;
  final bool isHighestWins;

  const YazbozTahtasi({
    super.key,
    required this.oyunElleri,
    required this.aktifOyuncular,
    required this.seciliOyun,
    required this.onElTap,
    this.kilitli = false,
    this.isHighestWins = false,
  });

  bool get _esliOyun =>
      seciliOyun?.esliMi == true && aktifOyuncular.length == 4;

  int? _gosterge(El el, String oyuncu) => el.gostergeMap[oyuncu] ?? el.gosterge;

  @override
  Widget build(BuildContext context) {
    if (oyunElleri.isEmpty || aktifOyuncular.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, size: 56, color: Color(0xFF334155)),
              const SizedBox(height: 12),
              const Text(
                'Henüz hiç el skoru girilmemiş.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kilitli
                    ? 'Bu oyun kayıtsız kapanmış.'
                    : 'İlk eli eklemek için + butonuna dokun.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final sirali = List<El>.from(oyunElleri)
      ..sort((a, b) {
        if (a.elNo != null && b.elNo != null) return a.elNo!.compareTo(b.elNo!);
        return a.elTarih.compareTo(b.elTarih);
      });

    final gruplar = <String, List<El>>{};
    for (final el in sirali) {
      gruplar.putIfAbsent('${el.elNo ?? el.elTarih}', () => []).add(el);
    }
    final anahtarlar = gruplar.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a), nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });

    final toplam = <String, int>{for (final o in aktifOyuncular) o: 0};
    final gostergeler = <String, List<int>>{
      for (final o in aktifOyuncular) o: <int>[],
    };
    for (final el in sirali) {
      el.skorlar.forEach((oyuncu, skor) {
        final g = _gosterge(el, oyuncu) ?? 0;
        toplam[oyuncu] = (toplam[oyuncu] ?? 0) + skor + g;
      });
      for (final o in aktifOyuncular) {
        final g = _gosterge(el, o);
        if (g != null && g != 0) {
          gostergeler.putIfAbsent(o, () => []).add(g);
        }
      }
    }
    final maxGosterge = gostergeler.values.fold<int>(
      1,
      (m, l) => l.length > m ? l.length : m,
    );

    final List<int> sonucDegerleri = _esliOyun
        ? [for (var i = 0; i < 2; i++) _esToplam(i, toplam)]
        : [for (final o in aktifOyuncular) toplam[o] ?? 0];
    final siraliSonuc = List<int>.from(sonucDegerleri)..sort();
    final vurguAcik =
        siraliSonuc.isNotEmpty && siraliSonuc.first != siraliSonuc.last;
    final int liderD = isHighestWins ? siraliSonuc.last : siraliSonuc.first;
    final int sonuncD = isHighestWins ? siraliSonuc.first : siraliSonuc.last;

    // ✅ AKILLI GENİŞLİK — mantık aynı
    final double ekran = MediaQuery.of(context).size.width - 24;
    const double etiketW = 58;
    final int sutunSayisi = _esliOyun ? 2 : aktifOyuncular.length;
    final double pay = (ekran - etiketW) / sutunSayisi;
    final double sutunW = pay < 64 ? 64 : pay;

    final genislikler = <int, TableColumnWidth>{
      0: const FixedColumnWidth(etiketW),
    };
    final basliklar = <Widget>[];
    if (_esliOyun) {
      for (var i = 0; i < 2; i++) {
        final a = aktifOyuncular[i * 2], b = aktifOyuncular[i * 2 + 1];
        basliklar.add(_baslik("$a – $b", maxLines: 2));
        genislikler[i + 1] = FixedColumnWidth(sutunW);
      }
    } else {
      for (var i = 0; i < aktifOyuncular.length; i++) {
        basliklar.add(_baslik(aktifOyuncular[i]));
        genislikler[i + 1] = FixedColumnWidth(sutunW);
      }
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111A2B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kilitli
                  ? const Color(0xFF334155)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.3),
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
                  horizontalInside: BorderSide(color: Color(0xFF1E293B)),
                  verticalInside: BorderSide(color: Color(0xFF1E293B)),
                ),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                    ),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox.shrink(),
                      ),
                      ...basliklar.map((w) => _baslikBeyaz(w)),
                    ],
                  ),

                  for (var r = 0; r < maxGosterge; r++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF87171).withValues(alpha: 0.08),
                      ),
                      children: [
                        _hucre(
                          r == 0 ? 'Göst.' : '',
                          color: const Color(0xFFF87171),
                          weight: FontWeight.w700,
                          size: 11,
                        ),
                        if (_esliOyun)
                          for (var i = 0; i < 2; i++)
                            _hucre(
                              _esGosterge(i, r, gostergeler).toString(),
                              color: const Color(0xFFFCA5A5),
                              weight: FontWeight.w800,
                              size: 14,
                            )
                        else
                          for (final o in aktifOyuncular)
                            _hucre(
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
                    ),

                  TableRow(
                    decoration: BoxDecoration(
                      color: kilitli
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.10),
                    ),
                    children: [
                      _hucre(
                        'SONUÇ',
                        color: kilitli
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFFFCD34D),
                        weight: FontWeight.w900,
                        size: 13,
                      ),
                      if (_esliOyun)
                        for (var i = 0; i < 2; i++)
                          _sonucHucresiVurgulu(
                            _esToplam(i, toplam),
                            liderD,
                            sonuncD,
                            vurguAcik,
                          )
                      else
                        for (final o in aktifOyuncular)
                          _sonucHucresiVurgulu(
                            toplam[o] ?? 0,
                            liderD,
                            sonuncD,
                            vurguAcik,
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

  TableRow _elSatiri(String key, List<El> grup, {required bool zebra}) {
    final etiket = int.tryParse(key) != null ? '$key.' : key;
    final el = grup.first;
    final skorRengi = kilitli
        ? const Color(0xFF64748B)
        : const Color(0xFFF8FAFC);
    return TableRow(
      decoration: BoxDecoration(
        color: zebra ? const Color(0xFF0F172A) : const Color(0xFF111A2B),
      ),
      children: [
        _hucre(
          etiket,
          weight: FontWeight.w800,
          size: 13,
          color: kilitli ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        if (_esliOyun)
          for (var i = 0; i < 2; i++)
            kilitli
                ? _hucre(
                    _esElSkor(i, grup).toString(),
                    color: skorRengi,
                    weight: FontWeight.w700,
                    size: 15,
                  )
                : _tiklanabilirHucre(
                    () => onElTap(el),
                    _esElSkor(i, grup).toString(),
                  )
        else
          for (final o in aktifOyuncular)
            kilitli
                ? _hucre(
                    (el.skorlar[o] ?? 0).toString(),
                    color: skorRengi,
                    weight: FontWeight.w700,
                    size: 15,
                  )
                : _tiklanabilirHucre(
                    () => onElTap(el),
                    (el.skorlar[o] ?? 0).toString(),
                  ),
      ],
    );
  }

  Widget _baslik(String t, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    child: Text(
      t,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    ),
  );

  Widget _baslikBeyaz(Widget ic) => DefaultTextStyle.merge(
    style: const TextStyle(color: Colors.white, letterSpacing: 0.2),
    child: ic,
  );

  Widget _hucre(
    String t, {
    Color? color,
    FontWeight? weight,
    double size = 15,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
    child: Text(
      t,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? const Color(0xFFE2E8F0),
        fontWeight: weight ?? FontWeight.w600,
        fontSize: size,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );

  Widget _tiklanabilirHucre(VoidCallback onTap, String t) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      splashColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
      highlightColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Color(0xFFF8FAFC),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );

  Widget _sonucHucresiVurgulu(int puan, int liderD, int sonuncD, bool acik) {
    final lider = acik && puan == liderD;
    final son = acik && puan == sonuncD;
    Color? bg;
    Color fg;
    if (lider) {
      bg = const Color(0xFF4ADE80).withValues(alpha: 0.16);
      fg = const Color(0xFF4ADE80);
    } else if (son) {
      bg = const Color(0xFFF87171).withValues(alpha: 0.14);
      fg = const Color(0xFFF87171);
    } else {
      fg = puan >= 0 ? const Color(0xFFE2E8F0) : const Color(0xFFF87171);
    }
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        puan.toString(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 17,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  int _esGosterge(int es, int row, Map<String, List<int>> g) {
    var t = 0;
    for (var j = 0; j < 2; j++) {
      final l = g[aktifOyuncular[es * 2 + j]] ?? const [];
      if (l.length > row) t += l[row];
    }
    return t;
  }

  int _esElSkor(int es, List<El> grup) {
    var t = 0;
    for (var j = 0; j < 2; j++) {
      final o = aktifOyuncular[es * 2 + j];
      final e = grup.firstWhere(
        (x) => x.skorlar.containsKey(o),
        orElse: () => const El(id: '', oyunId: '', elTarih: '', skorlar: {}),
      );
      t += (e.skorlar[o] ?? 0) + (e.gostergeMap[o] ?? e.gosterge ?? 0);
    }
    return t;
  }

  int _esToplam(int es, Map<String, int> toplam) {
    var t = 0;
    for (var j = 0; j < 2; j++) {
      t += toplam[aktifOyuncular[es * 2 + j]] ?? 0;
    }
    return t;
  }
}
