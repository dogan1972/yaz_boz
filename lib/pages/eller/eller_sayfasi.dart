// lib/pages/eller/eller_sayfasi.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/services/el_servisi.dart';
import 'package:yaz_boz/services/oyun_servisi.dart';
import 'package:yaz_boz/models/oyun_model.dart';
import 'package:yaz_boz/pages/oyunlar/oyunlar_sayfasi.dart';
import 'package:yaz_boz/pages/eller/yazboz_tahtasi.dart';
import 'package:yaz_boz/pages/eller/el_giris_formu.dart';
import 'package:yaz_boz/pages/eller/elleri_bitir.dart';
import 'package:yaz_boz/models/el_model.dart';
import 'package:yaz_boz/pages/eller/eller_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

class EllerSayfasi extends StatefulWidget {
  final String? oyunId;
  final bool isHighestWins;
  const EllerSayfasi({super.key, this.oyunId, this.isHighestWins = false});

  @override
  State<EllerSayfasi> createState() => _EllerSayfasiState();
}

class _EllerSayfasiState extends State<EllerSayfasi> {
  List<El> _tumEller = [];
  List<String> _aktifOyuncular = [];
  Oyun? _seciliOyun;
  bool _isLoading = true;
  bool _aramaBitti = false;
  String? _cozulmusId;
  int _sonrakiElNo = 1;
  String _imza = '';
  String? _hata;
  StreamSubscription<List<El>>? _sub;

  String? get _oyunId => widget.oyunId ?? _cozulmusId;
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
      _aramaBitti = true;
      _verileriDinle();
      _oyunuYukle();
    } else {
      _aktifOyunuAra();
    }
  }

  Future<void> _aktifOyunuAra() async {
    try {
      final aktifOyun = await OyunServisi().aktifOyunBul();
      if (!mounted) return;

      if (aktifOyun != null) {
        _cozulmusId = aktifOyun.id;
        _verileriDinle();
        _oyunuYukle(oyun: aktifOyun);
        setState(() => _aramaBitti = true);
      } else {
        setState(() {
          _aramaBitti = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aramaBitti = true;
        _isLoading = false;
      });
    }
  }

  void _verileriDinle() {
    final id = _oyunId;
    if (id == null) return;

    _sub = ElServisi()
        .oyunElleriStreami(id)
        .listen(
          (yeni) {
            try {
              if (!mounted) return;

              final sb = StringBuffer();
              for (final e in yeni) {
                sb.write(e.id);
                sb.write('|');
                sb.write(e.elNo);
                sb.write('|');
                sb.write(e.skorlar.length);
                sb.write(';');
              }

              final yeniImza = sb.toString();
              if (yeniImza == _imza) return;
              _imza = yeniImza;

              int maxElNo = 0;
              for (final e in yeni) {
                if (e.elNo > maxElNo) maxElNo = e.elNo;
              }

              setState(() {
                _tumEller = yeni;
                _sonrakiElNo = maxElNo + 1;
                _isLoading = false;
                _hata = null;
              });
            } catch (e) {
              if (!mounted) return;
              setState(() {
                _hata = '$e';
                _isLoading = false;
              });
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _hata = '$e';
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _oyunuYukle({Oyun? oyun}) async {
    final id = _oyunId;
    if (id == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // ✅ 'oyun' parametre olarak verilmediyse Firestore'dan çek
      final secilenOyun = oyun ?? await OyunServisi().oyunGetir(id);

      if (!mounted) return;

      setState(() {
        _seciliOyun = secilenOyun;
        if (_seciliOyun != null) {
          _aktifOyuncular =
              (_seciliOyun!.oyuncu as String?)
                  ?.split(', ')
                  .where((o) => o.isNotEmpty)
                  .toList() ??
              [];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = '$e';
        _isLoading = false;
      });
    }
  }

  bool get _oyunBitti =>
      _seciliOyun != null && _tumEller.length >= _seciliOyun!.elSayisi;
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

    // ✅ esliMi kontrolü + 4 oyuncu kontrolü
    final esli = _seciliOyun?.esliMi == true && _aktifOyuncular.length == 4;

    final buf = StringBuffer('✍️ YAZ BOZ SKOR TABLOSU\n')
      ..writeln(' Oyun #$_oyunId')
      ..writeln('───────────────');

    if (esli) {
      // ✅ DÜZELTME: 1-3 ve 2-4 eşleme (indeks 0-2 ve 1-3)
      final takim1A = _aktifOyuncular[0]; // 1. oyuncu
      final takim1B = _aktifOyuncular[2]; // 3. oyuncu
      final takim2A = _aktifOyuncular[1]; // 2. oyuncu
      final takim2B = _aktifOyuncular[3]; // 4. oyuncu

      final puan1 = (sonuclar[takim1A] ?? 0) + (sonuclar[takim1B] ?? 0);
      final puan2 = (sonuclar[takim2A] ?? 0) + (sonuclar[takim2B] ?? 0);

      buf.writeln('🤝 $takim1A & $takim1B: $puan1');
      buf.writeln('🤝 $takim2A & $takim2B: $puan2');
    } else {
      // Eşsiz oyun: Herkes kendi skorunu alır
      sonuclar.forEach((o, p) => buf.writeln('• $o: $p'));
    }

    buf
      ..writeln('───────────────')
      ..writeln(' Oynanan el: $_mevcutElSayisi');

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const EllerYukleniyorEkrani();
    if (_hata != null) return ellerHataEkrani(_hata!, null, _baslat, context);
    if (_oyunsuz) {
      return EllerAktifOyunYokEkrani(
        onBaslat: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OyunlarSayfasi()),
        ),
        onYenile: _baslat,
      );
    }

    try {
      final zemin = _kilitli ? AppColors.bgSecondary : AppColors.bgPrimary;
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
                    color: AppColors.textPrimary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: AppColors.textPrimary, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'MÜHÜRLENDİ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
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
          backgroundColor: _kilitli ? AppColors.cardBg : AppColors.bgSecondary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed: _paylas,
              icon: const Icon(
                Icons.share,
                color: AppColors.textPrimary,
                size: 18,
              ),
              label: const Text(
                'Paylaş',
                style: TextStyle(
                  color: AppColors.textPrimary,
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
            if (_kilitli) const EllerKilitSeridi(),
            if (!_kilitli && _seciliOyun != null && _aktifOyuncular.isNotEmpty)
              ellerIlerlemeCubugu(_mevcutElSayisi, _seciliOyun!.elSayisi),
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
      return ellerHataEkrani('$e', '$st', _baslat, context);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
