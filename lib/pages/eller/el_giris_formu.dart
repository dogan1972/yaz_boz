import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/firestore_service.dart';
import 'package:yaz_boz/pages/oyunlar/oyunlar_sayfasi.dart';

// ─────────────────────────────────────────────────────────────
// EL GİRİŞ FORMU — tek yönlü: sadece 'eller' koleksiyonuna yazar.
//   Yukarıya (oyunlar) veri GÖNDERMEZ. Oyunu sonlandırma burada yok.
// ─────────────────────────────────────────────────────────────
class ElGirisFormu extends StatefulWidget {
  final String oyunId;
  final List<String> aktifOyuncular;
  final Oyun? seciliOyun;
  final int mevcutElSayisi; // son-el engeli için
  final int sonrakiElNo;

  // düzenleme modu (El tipine BAĞIMLI DEĞİL → circular yok)
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
  final _fs = FirestoreService();
  final _tarih = TextEditingController();
  late final List<TextEditingController> _kar;
  late final List<TextEditingController> _zarar;
  late final List<TextEditingController> _gosterge;
  bool _kaydediyor = false; // ✅ çift basma kilidi + geri bildirim

  @override
  void initState() {
    super.initState();
    final n = widget.aktifOyuncular.length;
    _kar = List.generate(n, (_) => TextEditingController());
    _zarar = List.generate(n, (_) => TextEditingController());
    _gosterge = List.generate(n, (_) => TextEditingController(text: '0'));

    if (widget.duzenlemeModu) {
      _tarih.text = widget.duzenlemeTarih ?? '';
      final s = widget.duzenlemeSkorlar!;
      for (var i = 0; i < n; i++) {
        final net = s[widget.aktifOyuncular[i]] ?? 0;
        if (net < 0) {
          _kar[i].text = (-net).toString();
          _zarar[i].text = '0';
        } else {
          _kar[i].text = '0';
          _zarar[i].text = net.toString();
        }
      }
      final gm = widget.duzenlemeGostergeler ?? const {};
      for (var i = 0; i < n; i++) {
        final o = widget.aktifOyuncular[i];
        final g = gm[o] ?? widget.duzenlemeGosterge ?? 0;
        _gosterge[i].text = (-g).toString();
      }
    } else {
      _tarih.text = DateTime.now().toString().substring(0, 19);
    }
  }

  @override
  void dispose() {
    _tarih.dispose();
    for (final c in _kar) {
      c.dispose();
    }
    for (final c in _zarar) {
      c.dispose();
    }
    for (final c in _gosterge) {
      c.dispose();
    }
    super.dispose();
  }

  // ✅ TEK İŞ: skorları 'eller'e yaz. Yukarıya dokunma.
  Future<void> _kaydet() async {
    if (_kaydediyor || !mounted) return;
    final nav = Navigator.of(context);
    final hedef = widget.seciliOyun?.elSayisi ?? 8;

    // son-el engeli (yeni kayıtta) — hedefe ulaşıldıysa ekleme yok
    if (!widget.duzenlemeModu && widget.mevcutElSayisi >= hedef) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hedef el sayısına ($hedef) ulaşıldı — yeni el eklenemez.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      nav.pop();
      return;
    }

    setState(() => _kaydediyor = true);

    try {
      final skorlar = <String, int>{};
      for (var i = 0; i < widget.aktifOyuncular.length; i++) {
        final k = int.tryParse(_kar[i].text.trim()) ?? 0;
        final z = int.tryParse(_zarar[i].text.trim()) ?? 0;
        skorlar[widget.aktifOyuncular[i]] = z - k; // net = zarar - kar
      }
      final gostergeMap = <String, int>{};
      for (var i = 0; i < widget.aktifOyuncular.length; i++) {
        final g = (int.tryParse(_gosterge[i].text.trim()) ?? 0) * -1;
        if (g != 0) gostergeMap[widget.aktifOyuncular[i]] = g;
      }
      if (widget.duzenlemeModu) {
        await _fs.updateDocument('eller', widget.duzenlemeElId!, {
          'skorlar': skorlar,
          'gostergeler': gostergeMap,
        });
      } else {
        await _fs.setDocument(
          'eller',
          FirebaseFirestore.instance.collection('eller').doc().id,
          {
            'oyunId': widget.oyunId,
            'elTarih': _tarih.text.trim(),
            'skorlar': skorlar,
            'gostergeler': gostergeMap,
            'elNo': widget.sonrakiElNo,
          },
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _inputDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      hintStyle: const TextStyle(color: Color(0xFF475569)),
      filled: true,
      fillColor: const Color(0xFF0B1220),
      isDense: true,
      contentPadding: const EdgeInsets.all(8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final yatay = MediaQuery.of(context).orientation == Orientation.landscape;

    final govde = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!yatay) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.35),
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.sports_esports,
                color: Color(0xFF2DD4BF),
              ),
              title: Text(
                'Aktif Oyun: #${widget.oyunId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE2E8F0),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tarih,
            enabled: false,
            style: const TextStyle(color: Color(0xFF94A3B8)),
            decoration: _inputDeco('El Zaman Damgası'),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Kar, Zarar ve Gösterge Dağılımı',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const Divider(color: Color(0xFF1E293B)),
        ],
        if (yatay)
          Table(
            children: List.generate(
              (widget.aktifOyuncular.length / 2).ceil(),
              (r) => TableRow(children: [_kutu(r * 2), _kutu(r * 2 + 1)]),
            ),
          )
        else
          ...List.generate(widget.aktifOyuncular.length, _kutu),
      ],
    );

    if (yatay) {
      return Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0F1C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B1220),
            foregroundColor: const Color(0xFFF8FAFC),
            title: Text(
              widget.duzenlemeModu
                  ? 'El Skorlarını Düzenle'
                  : 'Yeni El Skoru Girişi',
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
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: SingleChildScrollView(child: govde)),
                const VerticalDivider(
                  width: 12,
                  thickness: 1,
                  color: Color(0xFF1E293B),
                ),
                Expanded(flex: 1, child: _sagPanel),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF111A2B),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.duzenlemeModu ? 'El Skorlarını Düzenle' : 'Yeni El Skoru Girişi',
        style: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width - 20,
        child: SingleChildScrollView(child: govde),
      ),
      actions: [
        TextButton(
          onPressed: _kaydediyor ? null : () => Navigator.pop(context),
          child: const Text(
            'İptal',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
        ElevatedButton(
          onPressed: _kaydediyor ? null : _kaydet,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
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

  Widget get _sagPanel => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.sports_esports,
                  color: Color(0xFF2DD4BF),
                  size: 18,
                ),
                const SizedBox(height: 2),
                Text(
                  'Oyun: #${widget.oyunId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.duzenlemeModu ? 'Düzenleme' : 'Yeni Kayıt',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kar, Zarar ve\nGösterge Dağılımı',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
          const Divider(height: 12, color: Color(0xFF1E293B)),
          ElevatedButton.icon(
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
                : const Icon(Icons.save, color: Color(0xFF1A1206), size: 16),
            label: const Text(
              'KAYDET',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1206),
                fontSize: 12,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _kutu(int i) {
    if (i >= widget.aktifOyuncular.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border.all(color: const Color(0xFF1E293B)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.aktifOyuncular[i],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kar[i],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFFE2E8F0)),
                    decoration: _inputDeco('Kar'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _zarar[i],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFFE2E8F0)),
                    decoration: _inputDeco('Zarar'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _gosterge[i],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFFE2E8F0)),
                    decoration: _inputDeco('Gost.', hint: '0'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
