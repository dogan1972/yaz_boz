// lib/pages/turnuva/turnuva_sayfasi.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/turnuva_servisi.dart';
import 'package:yaz_boz/services/sezon_servisi.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/pages/turnuva/turnuva_detay_sayfasi.dart';
import 'package:yaz_boz/models/turnuva_model.dart';
import 'package:yaz_boz/pages/turnuva/turnuva_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

class TurnuvaSayfasi extends StatefulWidget {
  const TurnuvaSayfasi({super.key});
  @override
  State<TurnuvaSayfasi> createState() => _TurnuvaSayfasiState();
}

class _TurnuvaSayfasiState extends State<TurnuvaSayfasi> {
  List<Turnuva> _tumTurnuvalar = [];
  bool _isLoading = true;
  bool _gosterArsiv = false;
  Map<String, int> _sezonNumara = {};
  StreamSubscription<List<Turnuva>>? _turnuvaStreamSub;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
    _sezonlariYukle();
  }

  void _verileriDinle() {
    _turnuvaStreamSub = TurnuvaServisi().tumTurnuvalarStreami().listen((
      yeniListe,
    ) {
      if (!mounted) return;
      if (yeniListe.length != _tumTurnuvalar.length ||
          !_listelerEsitMi(yeniListe, _tumTurnuvalar)) {
        setState(() {
          _tumTurnuvalar = yeniListe;
          _isLoading = false;
        });
      } else if (_isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  bool _listelerEsitMi(List<Turnuva> a, List<Turnuva> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].numara != b[i].numara ||
          a[i].turTarih != b[i].turTarih ||
          a[i].turKazanan != b[i].turKazanan ||
          a[i].tursonuc != b[i].tursonuc) {
        return false;
      }
    }
    return true;
  }

  Future<void> _sezonlariYukle() async {
    try {
      final k = await AuthService().profilGarantile();
      if (!mounted || k?.grupId == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('sezonlar')
          .where('grupId', isEqualTo: k?.grupId)
          .get();
      if (!mounted) return;
      final m = <String, int>{};
      for (final d in snap.docs) {
        final n = ((d.data())['numara'] as num?)?.toInt();
        if (n != null) m[d.id] = n;
      }
      setState(() => _sezonNumara = m);
    } catch (e) {
      debugPrint('Sezon numaraları yüklenemedi: $e');
    }
  }

  Future<void> _turnuvayiSonlandir(Turnuva tekTurnuva) async {
    try {
      if (!mounted) return;

      // ✅ 1. ADIM: Oyun sayısını ve durumunu kontrol et
      final k = await AuthService().profilGarantile();
      if (k == null || k.grupId == null) return;

      final oyunlarSnap = await FirebaseFirestore.instance
          .collection('oyunlar')
          .where('turId', isEqualTo: tekTurnuva.id)
          .where('grupId', isEqualTo: k.grupId)
          .get();

      if (!mounted) return;

      // Aktif (bitmemiş) oyun varsa engelle
      final aktifOyun = oyunlarSnap.docs
          .where((d) => (d.data())['oyunKazanan'] == null)
          .length;

      if (aktifOyun > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "⚠️ Bu turnuvada hâlâ devam eden $aktifOyun aktif oyun var — önce onları sonlandırın.",
            ),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // ✅ BOŞ TURNUVA UYARISI
      if (oyunlarSnap.docs.isEmpty) {
        final bosOnay = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber),
                SizedBox(width: 8),
                Text('Turnuva Boş!', style: AppTextStyles.bodyPrimary),
              ],
            ),
            content: const Text(
              'Bu turnuvada hiç oyun oynanmamış. Yine de sonlandırmak istiyor musunuz?',
              style: AppTextStyles.bodySecondary,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Vazgeç', style: AppTextStyles.bodySecondary),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(d, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentAmber,
                ),
                child: const Text(
                  'Evet, Sonlandır',
                  style: TextStyle(
                    color: Color(0xFF1A1206),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
        if (bosOnay != true || !mounted) return;
      }

      // ✅ 2. ADIM: Şampiyon ve Sonuncu Hesaplama (DOĞRU MANTIK)
      String sampiyon = '';
      String? sonuncu;

      if (oyunlarSnap.docs.isNotEmpty) {
        Map<String, int> galibiyetler = {};
        Set<String> oyuncular = {};

        // 1. GEÇİŞ: Tüm oyuncuları topla
        for (var doc in oyunlarSnap.docs) {
          final data = doc.data();
          if (data['oyuncu'] != null) {
            for (var s in data['oyuncu'].toString().split(RegExp(r'[,\n]'))) {
              final o = s.trim();
              if (o.isNotEmpty) oyuncular.add(o);
            }
          }
        }

        // Herkesi 0 galibiyetle başlat
        for (final o in oyuncular) {
          galibiyetler[o] = 0;
        }

        // 2. GEÇİŞ: Galibiyetleri say
        // KURAL: Bir oyunda kaybeden dışındaki HERKES +1 galibiyet alır.
        for (var doc in oyunlarSnap.docs) {
          final data = doc.data();
          final kaybeden = data['oyunKaybeden'];

          if (kaybeden != null && kaybeden.toString().isNotEmpty) {
            final kAdi = kaybeden.toString();
            // Kaybeden hariç tüm oyunculara galibiyet ekle
            for (var oyuncu in oyuncular) {
              if (oyuncu != kAdi) {
                galibiyetler[oyuncu] = (galibiyetler[oyuncu] ?? 0) + 1;
              }
            }
          }
        }

        // ✅ ŞAMPİYON: En çok galibiyeti alan
        var sirali = galibiyetler.entries.toList();
        sirali.sort((a, b) => b.value.compareTo(a.value)); // AZALAN SIRALAMA

        // Eğer birden fazla kişi aynı en yüksek galibiyete sahipse,
        // ilk sırada olanı şampiyon alıyoruz (veya tie-breaker eklenebilir)
        sampiyon = sirali.isNotEmpty ? sirali.first.key : '';

        // ✅ SONUNCU: En az galibiyeti alan (En çok kaybeden)
        var sonSirali = galibiyetler.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value)); // ARTAN SIRALAMA
        sonuncu = sonSirali.isNotEmpty ? sonSirali.first.key : null;

        // Eğer şampiyon ve sonuncu aynı kişi çıkarsa (tek oyuncu vb.), sonuncuyu null yap
        if (sampiyon == sonuncu) sonuncu = null;
      } else {
        sampiyon = '-';
      }

      if (!mounted) return;

      // ✅ 3. ADIM: Onay Dialogu
      // ✅ 3. ADIM: Onay Dialogu (KLAVYE DÜZELTMESİ)
      final onay = await showDialog<bool>(
        context: context,
        builder: (d) => StatefulBuilder(
          // ✅ StatefulBuilder eklendi
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                oyunlarSnap.docs.isEmpty
                    ? 'Boş Turnuvayı Kapat'
                    : 'Turnuvayı Sonlandır',
              ),
              content: SingleChildScrollView(
                // ✅ Scroll eklendi
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (oyunlarSnap.docs.isEmpty)
                      const Text(
                        "Bu turnuva boş olarak kapatılacak.",
                        style: AppTextStyles.bodySecondary,
                      )
                    else ...[
                      Text(
                        "Hesaplanan Şampiyon: $sampiyon",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (sonuncu != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Sonuncu: $sonuncu",
                            style: const TextStyle(color: AppColors.accentRed),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true, // ✅ İmleç otomatik odaklanır
                      controller: TextEditingController(text: sampiyon),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Şampiyon / Durum',
                        border: OutlineInputBorder(),
                        labelStyle: TextStyle(color: AppColors.textHint),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (val) => setDialogState(
                        () => sampiyon = val,
                      ), // ✅ Anlık güncelleme
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text(
                    'İptal',
                    style: AppTextStyles.bodySecondary,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(d, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentAmber,
                  ),
                  child: const Text(
                    'Onayla',
                    style: TextStyle(
                      color: Color(0xFF1A1206),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
      if (onay != true || !mounted || sampiyon.trim().isEmpty) return;

      // ✅ 4. ADIM: İşlemi tamamla
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await TurnuvaServisi().turnuvayiSonlandir(
        tekTurnuva.id,
        sampiyon.trim(),
        sonuncu,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            oyunlarSnap.docs.isEmpty
                ? "Boş turnuva kapatıldı."
                : "Turnuva Bitti! Şampiyon: $sampiyon",
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("Sonlandırma hatası: $e");
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hata: $e"),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Future<void> _turnuvayiKaliciSil(Turnuva tekTurnuva) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: AppColors.accentAmber),
        ),
      );
      await TurnuvaServisi().turnuvayiSil(tekTurnuva.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Turnuva ve verileri silindi."),
          backgroundColor: Colors.amber.shade800,
        ),
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

  Widget _arsivListeGorunumu(List<Turnuva> turnuvalar) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: turnuvalar.length,
      itemBuilder: (itemContext, index) {
        final tekTurnuva = turnuvalar[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              hoverColor: const Color(0xFFB8860B).withValues(alpha: 0.08),
              splashColor: const Color(0xFFB8860B).withValues(alpha: 0.14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => TurnuvaDetaySayfasi(
                    turnuvaId: tekTurnuva.id,
                    turnuvaAdi: tekTurnuva.turTarih ?? 'Turnuva',
                    turnuvaNumara: tekTurnuva.numara,
                  ),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
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
                            colors: [Color(0xFFE0B53C), Color(0xFFB8860B)],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned(
                              right: -30,
                              top: -40,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(
                                        0xFFB8860B,
                                      ).withValues(alpha: 0.10),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      turnuvaRozetSatir(
                                        'Sezon No',
                                        _sezonNumara[tekTurnuva.sezonId],
                                        renk: AppColors.accentBlue,
                                        koyu: true,
                                      ),
                                      turnuvaBlokAyirac(22),
                                      Expanded(
                                        child: Text(
                                          tekTurnuva.turTarih ?? 'Tarih Yok',
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      turnuvaBlokAyirac(22),
                                      turnuvaRozetSatir(
                                        'Turnuva No',
                                        tekTurnuva.numara,
                                        renk: AppColors.accentPurple,
                                        koyu: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: turnuvaSonucSutunu(
                                          '',
                                          'KAZANAN',
                                          tekTurnuva.turKazanan,
                                          AppColors.accentAmber,
                                        ),
                                      ),
                                      turnuvaBlokAyirac(34),
                                      Expanded(
                                        child: turnuvaSonucSutunu(
                                          '',
                                          'KAYBEDEN',
                                          tekTurnuva.turKaybeden,
                                          AppColors.accentRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _aktifHeroGorunumu(Turnuva tekTurnuva) {
    final double h = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24.0),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => TurnuvaDetaySayfasi(
                turnuvaId: tekTurnuva.id,
                turnuvaAdi: tekTurnuva.turTarih ?? 'Turnuva',
                turnuvaNumara: tekTurnuva.numara,
              ),
            ),
          ),
          child: Container(
            height: h * 0.62,
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
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -70,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -60,
                  child: Container(
                    width: 150,
                    height: 150,
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
                Padding(
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
                                turnuvaCiftRozet(
                                  _sezonNumara[tekTurnuva.sezonId],
                                  tekTurnuva.numara,
                                  koyu: true,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  tekTurnuva.turTarih ?? 'Tarih Yok',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 30,
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accentAmber.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.emoji_events,
                              color: AppColors.accentAmber,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TurnuvaKivilcim(),
                          const SizedBox(height: 14),
                          const Text(
                            "TURNUVA DEVAM EDİYOR",
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Masada kıyasıya rekabet tüm hızıyla sürüyor.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            turnuvaHeroAksiyonButonu(
                              icon: Icons.flag,
                              renk: AppColors.accentGreen,
                              etiket: "Sonlandır",
                              onTap: () async =>
                                  _turnuvayiSonlandir(tekTurnuva),
                            ),
                            turnuvaHeroAksiyonButonu(
                              icon: Icons.edit,
                              renk: AppColors.textPrimary,
                              etiket: "Düzenle",
                              onTap: () => turnuvaFormuDiyalog(
                                context,
                                turnuva: tekTurnuva,
                              ),
                            ),
                            turnuvaHeroAksiyonButonu(
                              icon: Icons.delete,
                              renk: Colors.amber.shade700,
                              etiket: "Sil",
                              onTap: () async {
                                if (!mounted) return;
                                final onay = await showDialog<bool>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    backgroundColor: AppColors.cardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    title: const Text(
                                      'Emin misiniz?',
                                      style: AppTextStyles.bodyPrimary,
                                    ),
                                    content: const Text(
                                      'Aktif turnuvayı kalıcı olarak silmek istediğinize emin misiniz?',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, false),
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
                                if (onay == true && mounted) {
                                  await _turnuvayiKaliciSil(tekTurnuva);
                                }
                              },
                            ),
                          ],
                        ),
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

    final gosterilecekListe = _tumTurnuvalar
        .where(
          (t) => _gosterArsiv ? t.turKazanan != null : t.turKazanan == null,
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Eski Turnuvalar' : 'Aktif Turnuvalar',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: gosterilecekListe.isEmpty
                ? turnuvaBosDurum(_gosterArsiv)
                : _gosterArsiv
                ? _arsivListeGorunumu(gosterilecekListe)
                : _aktifHeroGorunumu(gosterilecekListe.first),
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
                  _gosterArsiv ? "Aktif Turnuvalara Dön" : "Eski Turnuvalar",
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
            if (_gosterArsiv) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Arşivdeki turnuvalar salt okunurdur; yeni turnuva eklenemez.",
                  ),
                  backgroundColor: Colors.blueGrey,
                ),
              );
              return;
            }
            final aktifSezon = await SezonServisi().aktifSezonBul();
            if (!mounted) return;
            if (aktifSezon == null) {
              if (!currentContext.mounted) return;
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text("⚠️ Önce aktif bir SEZON başlatmalısınız!"),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }
            final buGruptaAktifTurnuvaVar = _tumTurnuvalar.any(
              (t) => t.turKazanan == null,
            );
            if (!currentContext.mounted) return;
            if (buGruptaAktifTurnuvaVar && mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Bu grupta zaten devam eden aktif bir turnuva bulunuyor!",
                  ),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }
            if (!currentContext.mounted) return;
            turnuvaFormuDiyalog(currentContext);
          },
          backgroundColor: AppColors.accentAmber,
          child: const Icon(Icons.add, color: Color(0xFF1A1206)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _turnuvaStreamSub?.cancel();
    super.dispose();
  }
}
