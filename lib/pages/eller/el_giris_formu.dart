// lib/pages/eller/el_giris_formu.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/services/el_servisi.dart';
import 'package:yaz_boz/models/oyun_model.dart';
import 'package:yaz_boz/models/el_giris_model.dart';
import 'package:yaz_boz/pages/eller/el_giris_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

class ElGirisFormu extends StatefulWidget {
  final String oyunId;
  final List<String> aktifOyuncular;
  final Oyun? seciliOyun;
  final int mevcutElSayisi;
  final int sonrakiElNo;
  final String? duzenlemeTarih;
  final Map<String, int>? duzenlemeSkorlar;
  final int? duzenlemeGosterge;
  final Map<String, int>? duzenlemeGostergeler;
  final String? duzenlemeElId;

  const ElGirisFormu({
    super.key,
    required this.oyunId,
    required this.aktifOyuncular,
    required this.seciliOyun,
    required this.mevcutElSayisi,
    required this.sonrakiElNo,
    this.duzenlemeTarih,
    this.duzenlemeSkorlar,
    this.duzenlemeGosterge,
    this.duzenlemeGostergeler,
    this.duzenlemeElId,
  });

  bool get duzenlemeModu => duzenlemeElId != null && duzenlemeSkorlar != null;

  @override
  State<ElGirisFormu> createState() => _ElGirisFormuState();
}

class _ElGirisFormuState extends State<ElGirisFormu> {
  final _tarih = TextEditingController();
  late final List<OyuncuSkorVerisi> _oyuncuVerileri;
  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    _oyuncuVerileri = widget.aktifOyuncular
        .map(
          (ad) => OyuncuSkorVerisi(
            ad: ad,
            karController: TextEditingController(),
            zararController: TextEditingController(),
            gostergeController: TextEditingController(text: '0'),
          ),
        )
        .toList();

    if (widget.duzenlemeModu) {
      _tarih.text = widget.duzenlemeTarih ?? '';
      final s = widget.duzenlemeSkorlar!;
      for (var i = 0; i < _oyuncuVerileri.length; i++) {
        final net = s[widget.aktifOyuncular[i]] ?? 0;
        if (net < 0) {
          _oyuncuVerileri[i].karController.text = (-net).toString();
        } else {
          _oyuncuVerileri[i].zararController.text = net.toString();
        }
      }
      final gm = widget.duzenlemeGostergeler ?? const {};
      for (var i = 0; i < _oyuncuVerileri.length; i++) {
        final o = widget.aktifOyuncular[i];
        final g = gm[o] ?? widget.duzenlemeGosterge ?? 0;
        _oyuncuVerileri[i].gostergeController.text = (-g).toString();
      }
    } else {
      _tarih.text = DateTime.now().toString().substring(0, 19);
    }
  }

  @override
  void dispose() {
    _tarih.dispose();
    for (final v in _oyuncuVerileri) {
      v.karController.dispose();
      v.zararController.dispose();
      v.gostergeController.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_kaydediyor || !mounted) return;
    final nav = Navigator.of(context);
    final hedef = widget.seciliOyun?.elSayisi ?? 8;

    if (!widget.duzenlemeModu && widget.mevcutElSayisi >= hedef) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hedef el sayısına ($hedef) ulaşıldı.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      nav.pop();
      return;
    }

    setState(() => _kaydediyor = true);

    try {
      final skorlar = <String, int>{};
      final gostergeMap = <String, int>{};

      for (final v in _oyuncuVerileri) {
        skorlar[v.ad] = v.netSkor;
        final g = v.gostergeDegeri;
        if (g != 0) gostergeMap[v.ad] = g;
      }

      final svc = ElServisi();

      if (widget.duzenlemeModu) {
        await svc.elGuncelle(widget.duzenlemeElId!, {
          'skorlar': skorlar,
          'gostergeler': gostergeMap,
        });
      } else {
        await svc.yeniElOlustur(
          oyunId: widget.oyunId,
          elNo: widget.sonrakiElNo,
          skorlar: skorlar,
          gostergeMap: gostergeMap,
          elTarih: _tarih.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.duzenlemeModu
                    ? 'El güncellendi'
                    : '${widget.sonrakiElNo}. el kaydedildi',
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      nav.pop();
    } catch (e) {
      debugPrint('❌ el kaydetme hatası: $e');
      if (!mounted) return;
      setState(() => _kaydediyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Widget _govde(BuildContext context) {
    final yatay = MediaQuery.of(context).orientation == Orientation.landscape;

    final ustBilgi = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!yatay) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.35),
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.sports_esports,
                color: AppColors.accentCyan,
              ),
              title: Text(
                'Aktif Oyun: #${widget.oyunId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tarih,
            enabled: false,
            style: const TextStyle(color: AppColors.textSecondary),
            decoration: InputDecoration(
              labelText: 'El Zaman Damgası',
              labelStyle: const TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Kar, Zarar ve Gösterge Dağılımı',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Divider(color: AppColors.divider),
        ],

        // ✅ YENİ: OYUNCU KUTULARI BÖLÜMÜ
        if (_oyuncuVerileri.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: yatay
                ? Table(
                    children: List.generate(
                      (_oyuncuVerileri.length / 2).ceil(),
                      (r) => TableRow(
                        children: [
                          oyuncuKutu(_oyuncuVerileri[r * 2]),
                          if (r * 2 + 1 < _oyuncuVerileri.length)
                            oyuncuKutu(_oyuncuVerileri[r * 2 + 1])
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  )
                : Column(
                    // ✅ DİKEY MODDA COLUMN İLE SAR
                    children: List.generate(
                      _oyuncuVerileri.length,
                      (i) => oyuncuKutu(_oyuncuVerileri[i]),
                    ),
                  ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Oyuncu bulunamadı!',
                style: TextStyle(color: AppColors.accentRed),
              ),
            ),
          ),
      ],
    );

    if (yatay) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: SingleChildScrollView(child: ustBilgi)),
          const VerticalDivider(
            width: 12,
            thickness: 1,
            color: AppColors.divider,
          ),
          Expanded(
            flex: 1,
            child: elSagPanel(
              oyunId: widget.oyunId,
              duzenlemeModu: widget.duzenlemeModu,
              kaydediyor: _kaydediyor,
              onKaydet: _kaydet,
            ),
          ),
        ],
      );
    }
    return ustBilgi;
  }

  @override
  Widget build(BuildContext context) {
    final yatay = MediaQuery.of(context).orientation == Orientation.landscape;
    final baslik = widget.duzenlemeModu
        ? 'El Skorlarını Düzenle'
        : 'Yeni El Skoru Girişi';

    if (yatay) {
      return Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.inputBg,
            foregroundColor: AppColors.textPrimary,
            title: Text(
              baslik,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton.icon(
                onPressed: _kaydediyor ? null : _kaydet,
                icon: _kaydediyor
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A1206),
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text(
                  'KAYDET',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: _govde(context),
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        baslik,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width - 20,
        child: SingleChildScrollView(child: _govde(context)),
      ),
      actions: [
        TextButton(
          onPressed: _kaydediyor ? null : () => Navigator.pop(context),
          child: const Text('İptal', style: AppTextStyles.bodySecondary),
        ),
        ElevatedButton(
          onPressed: _kaydediyor ? null : _kaydet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentAmber,
            foregroundColor: const Color(0xFF1A1206),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _kaydediyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1A1206),
                  ),
                )
              : const Text(
                  'Kaydet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}
