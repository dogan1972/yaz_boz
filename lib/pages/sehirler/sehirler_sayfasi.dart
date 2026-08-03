import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/firestore_service.dart';

// ─────────────────────────────────────────────────────────────
// ŞEHİR MODELİ
// ─────────────────────────────────────────────────────────────
class Sehir {
  final String id;
  final String sehirAd;

  Sehir({required this.id, required this.sehirAd});

  factory Sehir.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sehir(id: doc.id, sehirAd: data['sehirAd'] ?? '');
  }

  Map<String, dynamic> toMap() => {'sehirAd': sehirAd};
}

class SehirlerSayfasi extends StatefulWidget {
  const SehirlerSayfasi({super.key});

  @override
  State<SehirlerSayfasi> createState() => _SehirlerSayfasiState();
}

class _SehirlerSayfasiState extends State<SehirlerSayfasi> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _sehirAdController = TextEditingController();
  final TextEditingController _aramaController = TextEditingController();

  List<Sehir> _tumSehirler = [];
  List<dynamic> _oyuncular = [];

  String _sehirImza = '';
  String _oyuncuImza = '';

  bool _isLoading = true;

  // ✅ Deterministik kimlik paleti — KORUNDU (her şehir hep aynı renk)
  static const List<Color> _palet = [
    Color(0xFF0F766E),
    Color(0xFFC2410C),
    Color(0xFF1D4ED8),
    Color(0xFFB45309),
    Color(0xFF15803D),
    Color(0xFF0E7490),
    Color(0xFF92400E),
    Color(0xFF475569),
    Color(0xFFBE123C),
    Color(0xFF6D28D9),
  ];

  Color _renk(String ad) => _palet[ad.hashCode.abs() % _palet.length];

  @override
  void initState() {
    super.initState();
    _sehirleriDinle();
    _oyunculariDinle();
  }

  void _sehirleriDinle() {
    _firestoreService.getCollectionStream('sehirler').listen((snap) {
      if (!mounted) return;
      final yeni = snap.docs.map(Sehir.fromFirestore).toList()
        ..sort(
          (a, b) => a.sehirAd.toLowerCase().compareTo(b.sehirAd.toLowerCase()),
        );
      final imza = yeni.map((s) => '${s.id}|${s.sehirAd}').join(';');
      if (imza == _sehirImza) return;
      _sehirImza = imza;
      setState(() {
        _tumSehirler = yeni;
        _isLoading = false;
      });
    });
  }

  void _oyunculariDinle() {
    _firestoreService.getCollectionStream('oyuncular').listen((snap) {
      if (!mounted) return;
      final docs = snap.docs;
      final sb = StringBuffer();
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        sb
          ..write(d.id)
          ..write('|')
          ..write(data['isAktif'])
          ..write('|')
          ..write(data['oyuncuSehir'])
          ..write(';');
      }
      final imza = sb.toString();
      if (imza == _oyuncuImza) return;
      _oyuncuImza = imza;
      setState(() => _oyuncular = docs);
    });
  }

  Map<String, List<int>> _sayaclariKur() {
    final m = <String, List<int>>{};
    for (final d in _oyuncular) {
      final data = d.data() as Map<String, dynamic>;
      final sehir = data['oyuncuSehir']?.toString() ?? '';
      final aktif = (data['isAktif'] as num?)?.toInt() ?? 1;
      final s = m.putIfAbsent(sehir, () => [0, 0]);
      if (aktif == 1) {
        s[0]++;
      } else {
        s[1]++;
      }
    }
    return m;
  }

  void _sehirFormuGoster({Sehir? sehir}) {
    if (sehir != null) {
      _sehirAdController.text = sehir.sehirAd;
    } else {
      _sehirAdController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          sehir == null ? 'Yeni Şehir Ekle' : 'Şehri Düzenle',
          style: const TextStyle(color: Color(0xFFF8FAFC)),
        ),
        content: TextField(
          controller: _sehirAdController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE2E8F0)),
          decoration: InputDecoration(
            labelText: 'Şehir Adı',
            labelStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0B1220),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF1A1206),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (_sehirAdController.text.trim().isEmpty) return;
              final data = {'sehirAd': _sehirAdController.text.trim()};
              if (sehir == null) {
                await _firestoreService.setDocument(
                  'sehirler',
                  FirebaseFirestore.instance.collection('sehirler').doc().id,
                  data,
                );
              } else {
                await _firestoreService.updateDocument(
                  'sehirler',
                  sehir.id,
                  data,
                );
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sehriSil(Sehir sehir) async {
    try {
      await _firestoreService.deleteDocument('sehirler', sehir.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${sehir.sehirAd} silindi."),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      debugPrint("Şehir silinirken hata: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Silme sırasında hata oluştu: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    final arama = _aramaController.text.toLowerCase().trim();
    final filtreli = _tumSehirler
        .where((s) => arama.isEmpty || s.sehirAd.toLowerCase().contains(arama))
        .toList();
    final sayac = _sayaclariKur();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text(
          'Şehirler',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: Column(
        children: [
          _aramaKutusu(),
          Expanded(
            child: filtreli.isEmpty
                ? _bosDurum(arama.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                    itemCount: filtreli.length,
                    itemBuilder: (context, index) {
                      final sehir = filtreli[index];
                      final s = sayac[sehir.sehirAd] ?? const [0, 0];
                      return _bolgeKarti(sehir, s[0], s[1]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _sehirFormuGoster(),
        backgroundColor: const Color(0xFFF59E0B),
        child: const Icon(Icons.add, color: Color(0xFF1A1206)),
      ),
    );
  }

  Widget _aramaKutusu() {
    return Container(
      color: const Color(0xFF0B1220),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111A2B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: TextField(
          controller: _aramaController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Color(0xFFE2E8F0)),
          decoration: InputDecoration(
            hintText: 'Şehir ara…',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
            suffixIcon: _aramaController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: const Color(0xFFF87171),
                    onPressed: () => setState(() => _aramaController.clear()),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bosDurum(bool arandi) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            arandi ? Icons.search_off : Icons.location_city_outlined,
            size: 60,
            color: const Color(0xFF334155),
          ),
          const SizedBox(height: 14),
          Text(
            arandi ? 'Bu aramaya uygun şehir yok.' : 'Henüz şehir eklenmemiş.',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            arandi
                ? 'Farklı bir anahtar kelime deneyin.'
                : 'İlk bölgeyi eklemek için + butonuna dokun.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _bolgeKarti(Sehir sehir, int aktif, int pasif) {
    final renk = _renk(sehir.sehirAd);
    final toplam = aktif + pasif;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          hoverColor: renk.withValues(alpha: 0.10),
          onTap: () => _sehirFormuGoster(sehir: sehir),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: renk,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sehir.sehirAd,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              color: Color(0xFFF8FAFC),
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _sayacCipi(
                                'AKTİF',
                                '$aktif',
                                const Color(0xFF4ADE80),
                              ),
                              const SizedBox(width: 8),
                              _sayacCipi(
                                'PASİF',
                                '$pasif',
                                const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$toplam',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 30,
                            color: renk,
                            height: 1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'OYUNCU',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _duzenleButonu(sehir),
                  _silButonu(sehir),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sayacCipi(String etiket, String deger, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            deger,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: renk,
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            etiket,
            style: TextStyle(
              color: renk.withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _duzenleButonu(Sehir sehir) {
    return _kareButon(
      icon: Icons.edit_outlined,
      renk: const Color(0xFFFCD34D),
      onTap: () => _sehirFormuGoster(sehir: sehir),
    );
  }

  Widget _silButonu(Sehir sehir) {
    return _kareButon(
      icon: Icons.delete_outline,
      renk: const Color(0xFFF87171),
      onTap: () async {
        final onay = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: const Color(0xFF111A2B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Şehri Sil',
              style: TextStyle(color: Color(0xFFF8FAFC)),
            ),
            content: const Text(
              'Bu şehri silmek istediğinize emin misiniz?',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text(
                  'Sil',
                  style: TextStyle(color: Color(0xFFFCD34D)),
                ),
              ),
            ],
          ),
        );
        if (onay == true && mounted) await _sehriSil(sehir);
      },
    );
  }

  Widget _kareButon({
    required IconData icon,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: renk, size: 20),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sehirAdController.dispose();
    _aramaController.dispose();
    super.dispose();
  }
}
