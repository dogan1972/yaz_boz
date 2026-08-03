import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/services/firestore_service.dart';
import 'package:yaz_boz/pages/oyunlar/oyunlar_sayfasi.dart';
import 'package:yaz_boz/pages/eller/yazboz_tahtasi.dart';
import 'package:yaz_boz/pages/eller/el_giris_formu.dart';
import 'package:yaz_boz/pages/eller/elleri_bitir.dart';

// ─────────────────────────────────────────────────────────────
// ELLER SAYFASI — koordinatör (tek parça, tutarlı akış)
//
//   İki giriş yolu, birbirine KARIŞMAZ:
//     A) oyunId DOLU  (oyun kartı) → doğrudan o oyun; arama YOK;
//        "oyun yok" ekranı bu yolda ASLA çıkmaz.
//     B) oyunId null  (gelecekte gerekirse) → aktif oyunu kendi arar;
//        bulamazsa yaşayan "masada oyun yok" ekranı.
//
//   Loading kilidi: oyun okunduğu an açılır (el-stream'ine bağımlı değil),
//   böylece eli olmayan yeni oyun "Yükleniyor"de takılmaz.
//   TEK YÖNLÜ: sadece 'eller' okur/yazar, 'oyunlar'a YAZMAZ.
// ─────────────────────────────────────────────────────────────
class EllerSayfasi extends StatefulWidget {
  final String? oyunId;
  final bool isHighestWins;

  const EllerSayfasi({super.key, this.oyunId, this.isHighestWins = false});

  @override
  State<EllerSayfasi> createState() => _EllerSayfasiState();
}

class _EllerSayfasiState extends State<EllerSayfasi> {
  final _fs = FirestoreService();

  List<El> _tumEller = [];
  List<String> _aktifOyuncular = [];
  Oyun? _seciliOyun;

  bool _isLoading = true;
  bool _aramaBitti = false;
  String? _cozulmusId;
  int _sonrakiElNo = 1;

  String _imza = '';
  String? _hata;
  StreamSubscription<QuerySnapshot>? _sub;

  // ✅ Nihai id — getter TEK kaynak. widget.oyunId her zaman öncelikli.
  String? get _oyunId => widget.oyunId ?? _cozulmusId;

  // ✅ "oyun yok" SADECE arama yolunda (widget.oyunId null) mümkündür.
  //    Oyun kartından gelindiğinde bu getter KESİNLİKLE false döner.
  bool get _oyunsuz =>
      widget.oyunId == null && _aramaBitti && _cozulmusId == null;

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  void _baslat() {
    _imza = '';
    _hata = null;
    _isLoading = true;
    _aramaBitti = false;
    _cozulmusId = null;
    _seciliOyun = null;
    _aktifOyuncular = [];
    _tumEller = [];
    _sub?.cancel();

    if (widget.oyunId != null) {
      // A) id hazır → arama yok, doğrudan yükle
      _aramaBitti = true;
      _verileriDinle();
      _oyunuYukle();
    } else {
      // B) id yok → aktif oyunu sayfa kendi arar
      _aktifOyunuAra();
    }
    if (mounted) setState(() {});
  }

  // ── B) aktif oyun arama (3 sn timeout) ────────────────────
  Future<void> _aktifOyunuAra() async {
    try {
      final snap = await _fs
          .getCollection('oyunlar')
          .timeout(const Duration(seconds: 3));

      final aktifDoc = snap.docs.cast<DocumentSnapshot?>().firstWhere(
        (d) => (d!.data() as Map<String, dynamic>)['oyunKazanan'] == null,
        orElse: () => null,
      );

      if (!mounted) return;

      if (aktifDoc != null) {
        _cozulmusId = aktifDoc.id;
        _verileriDinle();
        _oyunuYukle();
        setState(() => _aramaBitti = true);
      } else {
        setState(() {
          _aramaBitti = true;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      debugPrint('⏱️ aktif oyun araması 3 sn timeout — boş durum');
      if (!mounted) return;
      setState(() {
        _aramaBitti = true;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('❌ aktif oyun araması hatası: $e\n$st');
      if (!mounted) return;
      setState(() {
        _aramaBitti = true;
        _isLoading = false;
      });
    }
  }

  // ── el stream (sadece bu oyun) ────────────────────────────
  void _verileriDinle() {
    final id = _oyunId;
    if (id == null) return;
    _sub = _fs
        .collectionStreamForOyun('eller', id)
        .listen(
          (snap) {
            try {
              if (!mounted) return;
              final yeni = snap.docs.map(El.fromFirestore).toList();
              final sb = StringBuffer();
              for (final e in yeni) {
                sb
                  ..write(e.id)
                  ..write('|')
                  ..write(e.elNo)
                  ..write('|')
                  ..write(e.skorlar.length)
                  ..write(';');
              }
              final yeniImza = sb.toString();
              if (yeniImza == _imza) return;
              _imza = yeniImza;
              setState(() {
                _tumEller = yeni;
                _sonrakiElNo =
                    yeni.fold<int>(
                      0,
                      (m, e) => (e.elNo ?? 0) > m ? e.elNo! : m,
                    ) +
                    1;
                _isLoading = false;
                _hata = null;
              });
            } catch (e, st) {
              debugPrint('❌ el stream onData hatası: $e\n$st');
              if (!mounted) return;
              setState(() {
                _hata = '$e';
                _isLoading = false;
              });
            }
          },
          onError: (Object e, StackTrace st) {
            debugPrint('❌ el stream onError: $e\n$st');
            if (!mounted) return;
            setState(() {
              _hata = '$e';
              _isLoading = false;
            });
          },
        );
  }

  // ── oyun belgesini oku ────────────────────────────────────
  Future<void> _oyunuYukle() async {
    final id = _oyunId;
    if (id == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await _fs.getDocument('oyunlar', id);
      if (!mounted) return;
      if (!doc.exists) {
        // id geçersiz → arama yolundaysa boş durum, kart yolundaysa hata kartı
        setState(() {
          _hata = widget.oyunId != null ? 'Oyun bulunamadı (id: $id).' : null;
          _isLoading = false;
        });
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _seciliOyun = Oyun.fromFirestore(doc);
        _aktifOyuncular =
            (data['oyuncu'] as String?)
                ?.split(', ')
                .where((o) => o.isNotEmpty)
                .toList() ??
            [];
        _isLoading = false; // ✅ KİLİT AÇILDI — el-stream'ini beklemez
      });
    } catch (e, st) {
      debugPrint('❌ oyun yüklenemedi: $e\n$st');
      if (!mounted) return;
      setState(() {
        _hata = '$e';
        _isLoading = false;
      });
    }
  }

  // ── türetilmiş durumlar ───────────────────────────────────
  bool get _oyunBitti {
    if (_seciliOyun == null) return false;
    return _tumEller.length >= _seciliOyun!.elSayisi;
  }

  bool get _kilitli => _seciliOyun?.oyunKazanan != null;

  int get _mevcutElSayisi => _tumEller.length;

  Map<String, int> get _toplam {
    final m = <String, int>{for (final o in _aktifOyuncular) o: 0};
    for (final el in _tumEller) {
      el.skorlar.forEach((o, s) {
        final g = el.gostergeMap[o] ?? el.gosterge ?? 0;
        m[o] = (m[o] ?? 0) + s + g;
      });
    }
    return m;
  }

  void _formAc({El? duzenle}) {
    final id = _oyunId;
    if (id == null || _kilitli) return;
    showDialog(
      context: context,
      builder: (_) => ElGirisFormu(
        oyunId: id,
        aktifOyuncular: _aktifOyuncular,
        seciliOyun: _seciliOyun,
        mevcutElSayisi: _mevcutElSayisi,
        sonrakiElNo: _sonrakiElNo,
        duzenlemeElId: duzenle?.id,
        duzenlemeTarih: duzenle?.elTarih,
        duzenlemeSkorlar: duzenle?.skorlar,
        duzenlemeGosterge: duzenle?.gosterge,
        duzenlemeGostergeler: duzenle?.gostergeMap,
      ),
    );
  }

  Future<void> _paylas() async {
    final sonuclar = _toplam;
    if (sonuclar.isEmpty || _aktifOyuncular.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşılacak skor henüz yok.')),
      );
      return;
    }
    final esli = _seciliOyun?.esliMi == true && _aktifOyuncular.length == 4;
    final buf = StringBuffer('✍️ YAZ BOZ SKOR TABLOSU\n')
      ..writeln('🎮 Oyun #$_oyunId')
      ..writeln('───────────────');
    if (esli) {
      for (var i = 0; i < 2; i++) {
        final a = _aktifOyuncular[i * 2], b = _aktifOyuncular[i * 2 + 1];
        buf.writeln('🤝 $a & $b: ${(sonuclar[a] ?? 0) + (sonuclar[b] ?? 0)}');
      }
    } else {
      sonuclar.forEach((o, p) => buf.writeln('• $o: $p'));
    }
    buf
      ..writeln('───────────────')
      ..writeln('📊 Oynanan el: $_mevcutElSayisi');
    final metin = buf.toString();
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(metin)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(
          Uri.parse('https://wa.me/?text=${Uri.encodeComponent(metin)}'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Paylaşılamadı: $e')));
    }
  }

  // ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _YukleniyorEkrani();
    if (_hata != null) return _hataEkrani(_hata!, null);

    // ✅ "oyun yok" SADECE arama yolunda. Oyun kartı buraya uğramaz.
    if (_oyunsuz) {
      return _AktifOyunYokEkrani(
        onBaslat: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OyunlarSayfasi()),
        ),
        onYenile: _baslat,
      );
    }

    try {
      final zemin = _kilitli
          ? const Color(0xFF0F172A)
          : const Color(0xFF0A0F1C);
      return Scaffold(
        backgroundColor: zemin,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text('Yaz Boz Tahtası', overflow: TextOverflow.ellipsis),
              ),
              if (_kilitli) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.white70, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'MÜHÜRLENDİ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: _kilitli
              ? const Color(0xFF1E293B)
              : const Color(0xFF0B1220),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed: _paylas,
              icon: const Icon(Icons.share, color: Colors.white, size: 18),
              label: const Text(
                'Paylaş',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            if (_kilitli) const _KilitSeridi(),
            if (!_kilitli && _seciliOyun != null && _aktifOyuncular.isNotEmpty)
              _ilerlemeCubugu(),
            YazbozTahtasi(
              oyunElleri: _tumEller,
              aktifOyuncular: _aktifOyuncular,
              seciliOyun: _seciliOyun,
              kilitli: _kilitli,
              isHighestWins: widget.isHighestWins,
              onElTap: (el) {
                if (!_kilitli) _formAc(duzenle: el);
              },
            ),
          ],
        ),
        floatingActionButton: EllerFab(
          oyunBitti: _oyunBitti || _kilitli,
          onPressed: _formAc,
        ),
      );
    } catch (e, st) {
      debugPrint('❌ build hatası: $e\n$st');
      return _hataEkrani('$e', '$st');
    }
  }

  Widget _ilerlemeCubugu() {
    final hedef = _seciliOyun!.elSayisi;
    final mevcut = _mevcutElSayisi;
    final gosterilen = mevcut.clamp(0, hedef);
    final oran = hedef == 0 ? 0.0 : (gosterilen / hedef).clamp(0.0, 1.0);
    final kalan = (hedef - mevcut).clamp(0, hedef);
    final asildi = mevcut > hedef;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF111A2B),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route,
                size: 15,
                color: asildi
                    ? const Color(0xFFF87171)
                    : const Color(0xFF2DD4BF),
              ),
              const SizedBox(width: 6),
              const Text(
                'İLERLEME',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const Spacer(),
              Text(
                '$gosterilen / $hedef el',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Color(0xFFF8FAFC),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 8,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(
                asildi ? const Color(0xFFF87171) : const Color(0xFF2DD4BF),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            asildi
                ? 'Hedef aşıldı · $mevcut el girildi'
                : (kalan > 0 ? '$kalan el kaldı' : 'Hedef el tamamlandı'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: asildi
                  ? const Color(0xFFF87171)
                  : (kalan > 0
                        ? const Color(0xFF64748B)
                        : const Color(0xFF2DD4BF)),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  Widget _hataEkrani(String hata, String? stack) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Yaz Boz Tahtası'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bug_report_outlined,
                                  color: Color(0xFFDC2626),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TAHTA YÜKLENEMEDİ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 1.6,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Bir hata yakalandı — uygulama çökmedi.',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  '$hata${stack != null ? '\n\n— stack —\n$stack' : ''}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.5,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _baslat,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Tekrar Dene'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back, size: 18),
                                  label: const Text('Geri Dön'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// GERİ BUTONU — ink zeminli ekranların sol üst çıkışı
// ─────────────────────────────────────────────────────────────
class _GeriButonu extends StatelessWidget {
  const _GeriButonu();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        hoverColor: const Color(0xFF334155),
        splashColor: const Color(0xFF0F766E).withValues(alpha: 0.35),
        onTap: () => Navigator.of(context).maybePop(),
        child: Tooltip(
          message: 'Geri Dön',
          waitDuration: const Duration(milliseconds: 400),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF334155), width: 1.2),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFFE2E8F0),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// YÜKLENİYOR — ink zemin, nabız atan ikon, sol üstte geri
// ─────────────────────────────────────────────────────────────
class _YukleniyorEkrani extends StatefulWidget {
  const _YukleniyorEkrani();
  @override
  State<_YukleniyorEkrani> createState() => _YukleniyorEkraniState();
}

class _YukleniyorEkraniState extends State<_YukleniyorEkrani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: _GeriButonu(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0F766E).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                final t = _c.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72 + 8 * t,
                      height: 72 + 8 * t,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF0F766E,
                        ).withValues(alpha: 0.14 + 0.10 * t),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F766E,
                            ).withValues(alpha: 0.4 * t),
                            blurRadius: 22 + 8 * t,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.style,
                        color: const Color(0xFF5EEAD4),
                        size: 34 + 3 * t,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'YAZ BOZ TAHTASI',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Yükleniyor',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.2,
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

// ─────────────────────────────────────────────────────────────
// AKTİF OYUN YOK — yaşayan boş-durum (sadece arama yolunda)
// ─────────────────────────────────────────────────────────────
class _AktifOyunYokEkrani extends StatefulWidget {
  final VoidCallback onBaslat;
  final VoidCallback onYenile;
  const _AktifOyunYokEkrani({required this.onBaslat, required this.onYenile});
  @override
  State<_AktifOyunYokEkrani> createState() => _AktifOyunYokEkraniState();
}

class _AktifOyunYokEkraniState extends State<_AktifOyunYokEkrani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: _GeriButonu(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            left: -90,
            bottom: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0E7490).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              color: const Color(0xFF0F766E).withValues(alpha: 0.6),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _c,
                      builder: (_, _) {
                        final t = _c.value;
                        return Container(
                          width: 104 + 10 * t,
                          height: 104 + 10 * t,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E293B),
                            border: Border.all(
                              color: const Color(0xFF334155),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F766E,
                                ).withValues(alpha: 0.35 * t),
                                blurRadius: 30 + 12 * t,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.sports_esports_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 44,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'YAZ BOZ · DURUM',
                      style: TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'MASADA AKTİF\nOYUN YOK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                        height: 1.04,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tahta bir oyuna bağlıdır. Şu an devam eden bir maç bulunmuyor — yeni bir oyun başlat, defter anında açılsın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: widget.onBaslat,
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        label: const Text(
                          'Oyun Başlat',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton.icon(
                        onPressed: widget.onYenile,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text(
                          'Tekrar Ara',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KİLİT ŞERİDİ
// ─────────────────────────────────────────────────────────────
class _KilitSeridi extends StatelessWidget {
  const _KilitSeridi();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFFCBD5E1),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BU OYUN SONUÇLANDI',
                        style: TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Skorlar salt okunur — geçmiş değiştirilemez.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
