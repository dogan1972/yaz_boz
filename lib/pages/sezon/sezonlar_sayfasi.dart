// lib/pages/sezon/sezonlar_sayfasi.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yaz_boz/services/sezon_servisi.dart';
import 'package:yaz_boz/pages/sezon/sezon_detay_sayfasi.dart';
import 'package:yaz_boz/models/sezon_model.dart';
import 'package:yaz_boz/pages/sezon/sezon_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class SezonlarSayfasi extends StatefulWidget {
  const SezonlarSayfasi({super.key});
  @override
  State<SezonlarSayfasi> createState() => _SezonlarSayfasiState();
}

class _SezonlarSayfasiState extends State<SezonlarSayfasi> {
  bool _gosterArsiv = false;
  List<Sezon> _tumSezonlar = [];
  bool _yukleniyor = false;
  bool _isLoading = true;
  StreamSubscription<List<Sezon>>? _sezonStreamSub;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
  }

  void _verileriDinle() {
    _sezonStreamSub = SezonServisi().tumSezonlarStreami().listen((yeniListe) {
      if (!mounted) return;

      // ✅ AKTİF Mİ ALANI DA EŞİTLİK KONTROLÜNE EKLENDİ
      if (yeniListe.length != _tumSezonlar.length ||
          !_listelerEsitMi(yeniListe, _tumSezonlar)) {
        setState(() {
          _tumSezonlar = yeniListe;
          _isLoading = false;
        });
      } else if (_isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  // ✅ AKTİF Mİ KARŞILAŞTIRMAYA DAHİL EDİLDİ
  bool _listelerEsitMi(List<Sezon> a, List<Sezon> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].numara != b[i].numara ||
          a[i].sezonTarih != b[i].sezonTarih ||
          a[i].sezonSampiyon != b[i].sezonSampiyon ||
          a[i].aktifMi != b[i].aktifMi) {
        // ✅ YENİ
        return false;
      }
    }
    return true;
  }

  Future<void> _sezonuSil(Sezon tekSezon) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      await SezonServisi().sezonuSil(tekSezon.id);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sezon ve tüm alt verileri tamamen silindi."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Zincirleme silme hatası: $e");
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

  Future<void> _sezonuSonlandir(Sezon tekSezon) async {
    try {
      if (!mounted) return;

      final stats = await SezonServisi().sezonIstatistikHesapla(tekSezon.id);
      if (!mounted) return;

      final toplamOyun = stats['toplamOyun'] as int? ?? 0;

      if (toplamOyun == 0) {
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
                Text('Sezon Boş!', style: AppTextStyles.bodyPrimary),
              ],
            ),
            content: const Text(
              'Bu sezonda hiç oyun oynanmamış. Yine de sonlandırmak istiyor musunuz?',
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

      String sampiyonAd = '';
      if (toplamOyun > 0) {
        final oyuncuListesiRaw = stats['oyuncuIstatistikleri'];
        if (oyuncuListesiRaw is List && oyuncuListesiRaw.isNotEmpty) {
          int maxKazanan = -1;
          String enIyiOyuncu = '';
          for (var item in oyuncuListesiRaw) {
            try {
              final kazanilan = item.kazandigiOyun as int? ?? 0;
              final ad = item.oyuncuAdi as String? ?? '';
              if (kazanilan > maxKazanan) {
                maxKazanan = kazanilan;
                enIyiOyuncu = ad;
              }
            } catch (_) {}
          }
          sampiyonAd = enIyiOyuncu;
        }
      } else {
        sampiyonAd = '-';
      }

      if (!mounted) return;
      final controller = TextEditingController(text: sampiyonAd);
      final manuel = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            toplamOyun == 0 ? 'Boş Sezonu Kapat' : 'Sezonu Sonlandır',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                toplamOyun == 0
                    ? "Bu sezon boş olarak kapatılacak. Şampiyon alanına '-' veya iptal notu girebilirsiniz:"
                    : "Şampiyon adını onaylayın veya değiştirin:",
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Şampiyon / Durum',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: AppColors.textHint),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, null),
              child: const Text('İptal', style: AppTextStyles.bodySecondary),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(d, controller.text.trim()),
              child: const Text('Onayla'),
            ),
          ],
        ),
      );

      if (manuel == null || manuel.isEmpty || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // ✅ ZİNCİRLEME PASİFE ALMA SERVİS METODU ÇAĞRILIYOR
      await SezonServisi().sezonuSonlandir(tekSezon.id, manuel);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            toplamOyun == 0
                ? "Boş sezon kapatıldı."
                : "Sezon bitti! Şampiyon: $manuel",
          ),
          backgroundColor: Colors.indigo.shade800,
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

  Widget _arsivListeGorunumu(List<Sezon> sezonlar) {
    return ListView.builder(
      itemCount: sezonlar.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (itemContext, index) {
        final tekSezon = sezonlar[index];
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
                  builder: (c) => SezonDetaySayfasi(
                    sezonId: tekSezon.id,
                    sezonAdi: tekSezon.sezonTarih,
                    sezonNumara: tekSezon.numara,
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
                                  // ✅ DÜZELTME: n parametresi isimli olarak gönderildi
                                  sezonNumaraRozeti(
                                    n: tekSezon.numara,
                                    renk: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tekSezon.sezonTarih,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
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
                              const SizedBox(height: 12),
                              const Text(
                                'ŞAMPİYON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Text(
                                    ' ',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Expanded(
                                    child: Text(
                                      tekSezon.sezonSampiyon ?? '—',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.accentAmber,
                                        letterSpacing: -0.2,
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
                      sezonSilDugmesi(
                        onTap: () async {
                          final onay = await showDialog<bool>(
                            context: itemContext,
                            builder: (d) => AlertDialog(
                              backgroundColor: AppColors.cardBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: const Text(
                                'Sezonu Sil',
                                style: AppTextStyles.bodyPrimary,
                              ),
                              content: const Text(
                                'Bu sezonu ve altındaki TÜM verileri kalıcı olarak silmek istediğinize emin misiniz?',
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
                                  child: Text(
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
                            await _sezonuSil(tekSezon);
                          }
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

  Widget _aktifHeroGorunumu(Sezon tekSezon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24.0),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => SezonDetaySayfasi(
                sezonId: tekSezon.id,
                sezonAdi: tekSezon.sezonTarih,
                sezonNumara: tekSezon.numara,
              ),
            ),
          ),
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.45,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ DÜZELTME: n parametresi isimli olarak gönderildi
                            sezonNumaraRozeti(
                              n: tekSezon.numara,
                              renk: AppColors.accentAmber,
                              font: 15,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tekSezon.sezonTarih,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
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
                          Icons.calendar_month,
                          color: AppColors.accentAmber,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: AppColors.accentAmber,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "SEZON DEVAM EDİYOR",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Masada rekabet tüm hızıyla sürüyor.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
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
                        sezonHeroAksiyonButonu(
                          icon: Icons.gavel,
                          renk: AppColors.accentAmber,
                          etiket: "Sonlandır",
                          onTap: () async => _sezonuSonlandir(tekSezon),
                        ),
                        sezonHeroAksiyonButonu(
                          icon: Icons.edit,
                          renk: AppColors.textPrimary,
                          etiket: "Düzenle",
                          onTap: () =>
                              sezonFormuDiyalog(context, sezon: tekSezon),
                        ),
                        sezonHeroAksiyonButonu(
                          icon: Icons.delete,
                          renk: Colors.amber.shade700,
                          etiket: "Sil",
                          onTap: () async {
                            final onay = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                backgroundColor: AppColors.cardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                title: const Text(
                                  'Sezonu Sil',
                                  style: AppTextStyles.bodyPrimary,
                                ),
                                content: const Text(
                                  'Bu sezonu ve altındaki TÜM verileri kalıcı olarak silmek istediğinize emin misiniz?',
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
                                    child: Text(
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
                              await _sezonuSil(tekSezon);
                            }
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentAmber),
        ),
      );
    }

    // ✅ FİLTRELEME MANTIĞI AKTİF Mİ ALANINA GÖRE GÜNCELLENDİ
    final liste = _tumSezonlar
        .where(
          (s) => _gosterArsiv
              ? !s.aktifMi || s.sezonSampiyon != null
              : s.aktifMi && s.sezonSampiyon == null,
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuçlanan Sezonlar' : 'Aktif Sezonlar',
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
            child: liste.isEmpty
                ? sezonBosDurum(_gosterArsiv)
                : _gosterArsiv
                ? _arsivListeGorunumu(liste)
                : _aktifHeroGorunumu(liste.first),
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
                  _gosterArsiv ? "Aktif Sezonlara Dön" : "Eski Sezonlar",
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
          onPressed: _yukleniyor
              ? null
              : () async {
                  final safeContext = context;

                  setState(() => _yukleniyor = true);

                  try {
                    // ✅ AKTİF TURNUVA KONTROLÜ AKTİF Mİ ALANINA GÖRE YAPILIYOR
                    final buGruptaAktifVar = _tumSezonlar.any(
                      (s) => s.aktifMi && s.sezonSampiyon == null,
                    );

                    if (!mounted) return;

                    if (buGruptaAktifVar) {
                      ScaffoldMessenger.of(safeContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Bu grupta zaten devam eden aktif bir sezon bulunuyor!",
                          ),
                          backgroundColor: Colors.orangeAccent,
                          duration: Duration(seconds: 4),
                        ),
                      );
                      return;
                    }

                    await SezonServisi().yeniSezonOlustur(
                      tarih: DateTime.now().toString().substring(0, 10),
                      isLowestWins: true,
                    );
                  } catch (e) {
                    if (safeContext.mounted) {
                      ScaffoldMessenger.of(safeContext).showSnackBar(
                        SnackBar(
                          content: Text('Sezon oluşturulamadı: $e'),
                          backgroundColor: AppColors.accentRed,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _yukleniyor = false);
                  }
                },
          backgroundColor: AppColors.accentAmber,
          child: const Icon(Icons.add, color: Color(0xFF1A1206)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sezonStreamSub?.cancel();
    super.dispose();
  }
}
