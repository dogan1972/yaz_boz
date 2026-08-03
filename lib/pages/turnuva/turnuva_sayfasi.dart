import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/firestore_service.dart';
import 'package:yaz_boz/pages/turnuva/turnuva_detay_sayfasi.dart';

// ─────────────────────────────────────────────────────────────
// TURNUVA MODELİ  (+ numara)
// ─────────────────────────────────────────────────────────────
class Turnuva {
  final String id;
  final int? numara;
  final String sezonId;
  final String? turTarih;
  final String? turKazanan;
  final String? turIkinci;
  final String? turUcuncu;
  final String? turKaybeden;
  final int tursonuc;

  Turnuva({
    required this.id,
    this.numara,
    required this.sezonId,
    this.turTarih,
    this.turKazanan,
    this.turIkinci,
    this.turUcuncu,
    this.turKaybeden,
    required this.tursonuc,
  });

  factory Turnuva.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Turnuva(
      id: doc.id,
      numara: (data['numara'] as num?)?.toInt(),
      sezonId: data['sezonId'] ?? '',
      turTarih: data['turTarih'] ?? 'Tarih Yok',
      turKazanan: data['turKazanan'],
      turIkinci: data['turIkinci'],
      turUcuncu: data['turUcuncu'],
      turKaybeden: data['turKaybeden'],
      tursonuc: data['tursonuc'] ?? 0,
    );
  }
}

class TurnuvaSayfasi extends StatefulWidget {
  const TurnuvaSayfasi({super.key});

  @override
  State<TurnuvaSayfasi> createState() => _TurnuvaSayfasiState();
}

class _TurnuvaSayfasiState extends State<TurnuvaSayfasi> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _tarihController = TextEditingController();
  final TextEditingController _kazananController = TextEditingController();
  final TextEditingController _ikinciController = TextEditingController();
  final TextEditingController _ucuncuController = TextEditingController();
  final TextEditingController _kaybedenController = TextEditingController();

  List<Turnuva> _tumTurnuvalar = [];
  bool _isLoading = true;
  bool _gosterArsiv = false;
  Map<String, int> _sezonNumara = {};

  @override
  void initState() {
    super.initState();
    _verileriDinle();
    _sezonlariYukle();
  }

  void _verileriDinle() {
    _firestoreService.getCollectionStream('turnuva').listen((snapshot) {
      if (!mounted) return;
      final yeni = snapshot.docs.map((d) => Turnuva.fromFirestore(d)).toList()
        ..sort((a, b) => (b.turTarih ?? '').compareTo(a.turTarih ?? ''));
      if (yeni.length != _tumTurnuvalar.length ||
          !_listelerEsitMi(yeni, _tumTurnuvalar)) {
        setState(() {
          _tumTurnuvalar = yeni;
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
      final snap = await _firestoreService.getCollection('sezonlar');
      if (!mounted) return;
      final m = <String, int>{};
      for (final d in snap.docs) {
        final n = ((d.data() as Map<String, dynamic>)['numara'] as num?)
            ?.toInt();
        if (n != null) m[d.id] = n;
      }
      setState(() => _sezonNumara = m);
    } catch (e) {
      debugPrint('Sezon numaraları yüklenemedi: $e');
    }
  }

  Widget _ciftRozet(
    int? sezonNo,
    int? turnuvaNo, {
    required bool koyu,
    bool yatay = false,
  }) {
    final sezon = _rozetSatir(
      'Sezon No',
      sezonNo,
      renk: koyu ? Colors.cyan.shade200 : const Color(0xFF60A5FA),
      koyu: koyu,
    );
    final turnuva = _rozetSatir(
      'Turnuva No',
      turnuvaNo,
      renk: koyu ? Colors.amber.shade200 : const Color(0xFFA78BFA),
      koyu: koyu,
    );
    if (yatay) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [sezon, const SizedBox(width: 14), turnuva],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [sezon, const SizedBox(height: 5), turnuva],
    );
  }

  Widget _rozetSatir(
    String etiket,
    int? n, {
    required Color renk,
    required bool koyu,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiket,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: koyu
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 6),
        n == null
            ? Text(
                '—',
                style: TextStyle(
                  color: koyu ? Colors.white70 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              )
            : _numaraRozeti(n, renk: renk, font: 12),
      ],
    );
  }

  Widget _numaraRozeti(int? n, {Color renk = Colors.purple, double? font}) {
    if (n == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: renk.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: renk.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '#$n',
        style: TextStyle(
          color: renk,
          fontWeight: FontWeight.w800,
          fontSize: font ?? 13,
          letterSpacing: 0.6,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _blokAyirac([double h = 22]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: 1.5,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFF94A3B8).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _sonucSutunu(String emoji, String etiket, String? ad, Color renk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              etiket,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          (ad == null || ad.isEmpty) ? '—' : ad,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: renk,
            letterSpacing: -0.2,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  InputDecoration _formDeco(String label) {
    return InputDecoration(
      labelText: label,
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
    );
  }

  void _turnuvaFormuGoster({Turnuva? turnuva}) {
    if (turnuva != null) {
      _tarihController.text = turnuva.turTarih ?? '';
      _kazananController.text = turnuva.turKazanan ?? '';
      _ikinciController.text = turnuva.turIkinci ?? '';
      _ucuncuController.text = turnuva.turUcuncu ?? '';
      _kaybedenController.text = turnuva.turKaybeden ?? '';
    } else {
      _tarihController.text = DateTime.now().toString().substring(0, 10);
      _kazananController.clear();
      _ikinciController.clear();
      _ucuncuController.clear();
      _kaybedenController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          turnuva == null ? 'Yeni Turnuva Ekle' : 'Turnuvayı Düzenle',
          style: const TextStyle(color: Color(0xFFF8FAFC)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _tarihController,
                style: const TextStyle(color: Color(0xFFE2E8F0)),
                decoration: _formDeco('Turnuva Tarihi / Adı'),
              ),
              if (turnuva != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _kazananController,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  decoration: _formDeco('🏆 Şampiyon'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ikinciController,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  decoration: _formDeco('🥈 İkinci'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ucuncuController,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  decoration: _formDeco('🥉 Üçüncü'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _kaybedenController,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  decoration: _formDeco('📉 Sonuncu'),
                ),
              ],
            ],
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
              if (_tarihController.text.trim().isEmpty) return;
              try {
                final sezonSnapshot = await _firestoreService.getCollection(
                  'sezonlar',
                );
                final aktifSezonDoc = sezonSnapshot.docs.firstWhere(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['sezonSampiyon'] ==
                      null,
                  orElse: () => throw Exception('Aktif sezon bulunamadı!'),
                );

                final data = <String, dynamic>{
                  'sezonId': aktifSezonDoc.id,
                  'turTarih': _tarihController.text.trim(),
                  'turKazanan': _kazananController.text.trim().isEmpty
                      ? null
                      : _kazananController.text.trim(),
                  'turIkinci': _ikinciController.text.trim().isEmpty
                      ? null
                      : _ikinciController.text.trim(),
                  'turUcuncu': _ucuncuController.text.trim().isEmpty
                      ? null
                      : _ucuncuController.text.trim(),
                  'turKaybeden': _kaybedenController.text.trim().isEmpty
                      ? null
                      : _kaybedenController.text.trim(),
                  'tursonuc': _kazananController.text.trim().isNotEmpty ? 1 : 0,
                };

                if (turnuva == null) {
                  data['numara'] = await _firestoreService.nextNumber(
                    'turnuva',
                  );
                  await _firestoreService.setDocument(
                    'turnuva',
                    FirebaseFirestore.instance.collection('turnuva').doc().id,
                    data,
                  );
                } else {
                  await _firestoreService.updateDocument(
                    'turnuva',
                    turnuva.id,
                    data,
                  );
                }
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              } catch (e) {
                debugPrint("Turnuva form hatası: $e");
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text("Hata: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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

  Future<void> _turnuvayiSonlandir(Turnuva tekTurnuva) async {
    try {
      if (!mounted) return;

      final tumOyunlarSnap = await _firestoreService.getCollection('oyunlar');
      if (!mounted) return;

      final turnuvaOyunlari = tumOyunlarSnap.docs
          .where(
            (d) => (d.data() as Map<String, dynamic>)['turId'] == tekTurnuva.id,
          )
          .toList();

      final aktifOyun = turnuvaOyunlari
          .where(
            (d) => (d.data() as Map<String, dynamic>)['oyunKazanan'] == null,
          )
          .length;
      if (aktifOyun > 0) {
        if (!mounted) return;
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

      if (turnuvaOyunlari.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu turnuvada hiç oyun oynanmamış!")),
        );
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );

      Map<String, int> oyuncuGalibiyet = {};
      Map<String, int> oyuncuMaglubiyet = {};
      Set<String> tumOyuncularSet = {};

      for (var doc in turnuvaOyunlari) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['oyuncu'] != null) {
          for (var s in data['oyuncu'].toString().split(RegExp(r'[,\n]'))) {
            final o = s.trim();
            if (o.isNotEmpty) tumOyuncularSet.add(o);
          }
        }
        final kaybeden = data['oyunKaybeden'];
        if (kaybeden != null && kaybeden.toString().isNotEmpty) {
          final k = kaybeden.toString();
          oyuncuMaglubiyet[k] = (oyuncuMaglubiyet[k] ?? 0) + 1;
          for (var oyuncu in tumOyuncularSet) {
            if (oyuncu != k) {
              oyuncuGalibiyet[oyuncu] = (oyuncuGalibiyet[oyuncu] ?? 0) + 1;
            }
          }
        }
      }

      var siraliListe = oyuncuGalibiyet.entries.toList();
      siraliListe.sort((a, b) => b.value.compareTo(a.value));

      String? sampiyon = siraliListe.isNotEmpty
          ? siraliListe.first.key
          : (tumOyuncularSet.isNotEmpty ? tumOyuncularSet.first : null);
      String? sonuncu = oyuncuMaglubiyet.isNotEmpty
          ? oyuncuMaglubiyet.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key
          : null;

      if (!mounted) return;
      Navigator.pop(context);

      final onay = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: const Color(0xFF111A2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: Color(0xFFFCD34D), size: 26),
              SizedBox(width: 8),
              Text(
                'Turnuvayı Sonlandır',
                style: TextStyle(color: Color(0xFFF8FAFC)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hesaplanan Şampiyon: ${sampiyon ?? 'Belirsiz'}",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              if (sonuncu != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Sonuncu: $sonuncu",
                    style: const TextStyle(color: Color(0xFFF87171)),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                "Emin misiniz?",
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text(
                'İptal',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(d, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF1A1206),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Sonlandır',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

      if (onay != true || !mounted) return;

      await _firestoreService.updateDocument('turnuva', tekTurnuva.id, {
        'turKazanan': sampiyon,
        'turKaybeden': sonuncu,
        'tursonuc': 1,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Turnuva Bitti! Şampiyon: $sampiyon"),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("Sonlandırma hatası: $e");
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
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
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );

      final tumOyunlarSnap = await _firestoreService.getCollection('oyunlar');
      final silinecekOyunlar = tumOyunlarSnap.docs
          .where(
            (d) => (d.data() as Map<String, dynamic>)['turId'] == tekTurnuva.id,
          )
          .toList();
      for (var oyunDoc in silinecekOyunlar) {
        final oyunId = oyunDoc.id;
        final tumEllerSnap = await _firestoreService.getCollection('eller');
        final silinecekEller = tumEllerSnap.docs
            .where(
              (d) => (d.data() as Map<String, dynamic>)['oyunId'] == oyunId,
            )
            .map((d) => d.id)
            .toList();
        for (var elId in silinecekEller) {
          await _firestoreService.deleteDocument('eller', elId);
        }
        await _firestoreService.deleteDocument('oyunlar', oyunId);
      }
      await _firestoreService.deleteDocument('turnuva', tekTurnuva.id);

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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _heroAksiyonButonu({
    required IconData icon,
    required Color renk,
    required String etiket,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: Colors.white.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: renk, size: 24),
            const SizedBox(height: 4),
            Text(
              etiket,
              style: TextStyle(
                color: renk.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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

    final gosterilecekListe = _tumTurnuvalar
        .where(
          (t) => _gosterArsiv ? t.turKazanan != null : t.turKazanan == null,
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Eski Turnuvalar' : 'Aktif Turnuvalar',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: gosterilecekListe.isEmpty
                ? _bosDurum()
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
                  color: const Color(0xFFE2E8F0),
                ),
                label: Text(
                  _gosterArsiv ? "Aktif Turnuvalara Dön" : "Eski Turnuvalar",
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF334155), width: 1.5),
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
            final messenger = ScaffoldMessenger.of(context);

            if (_gosterArsiv) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    "Arşivdeki turnuvalar salt okunurdur; yeni turnuva eklenemez.",
                  ),
                  backgroundColor: Colors.blueGrey,
                ),
              );
              return;
            }

            try {
              final snap = await _firestoreService.getCollection('sezonlar');
              final aktifSezonVar = snap.docs.any(
                (d) =>
                    (d.data() as Map<String, dynamic>)['sezonSampiyon'] == null,
              );
              if (!mounted) return;
              if (!aktifSezonVar) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("⚠️ Önce aktif bir SEZON başlatmalısınız!"),
                    backgroundColor: Colors.orangeAccent,
                    duration: Duration(seconds: 4),
                  ),
                );
                return;
              }
            } catch (e) {
              debugPrint("Aktif sezon kontrolü hatası: $e");
              if (!mounted) return;
            }

            _turnuvaFormuGoster();
          },
          backgroundColor: const Color(0xFFF59E0B),
          child: const Icon(Icons.add, color: Color(0xFF1A1206)),
        ),
      ),
    );
  }

  Widget _bosDurum() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _gosterArsiv
                ? Icons.inventory_2_outlined
                : Icons.emoji_events_outlined,
            size: 64,
            color: const Color(0xFF334155),
          ),
          const SizedBox(height: 14),
          Text(
            _gosterArsiv ? 'Arşivde turnuva yok.' : 'Aktif turnuva bulunmuyor.',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _gosterArsiv
                ? 'Sonlanan turnuvalar burada listelenecek.'
                : 'Yeni turnuva başlatmak için + butonuna dokun.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
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
            color: const Color(0xFF111A2B),
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
                  border: Border.all(color: const Color(0xFF1E293B)),
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
                      // altın cilt — korundu
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
                                      _rozetSatir(
                                        'Sezon No',
                                        _sezonNumara[tekTurnuva.sezonId],
                                        renk: const Color(0xFF60A5FA),
                                        koyu: true,
                                      ),
                                      _blokAyirac(22),
                                      Expanded(
                                        child: Text(
                                          tekTurnuva.turTarih ?? 'Tarih Yok',
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFFF8FAFC),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      _blokAyirac(22),
                                      _rozetSatir(
                                        'Turnuva No',
                                        tekTurnuva.numara,
                                        renk: const Color(0xFFA78BFA),
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
                                        child: _sonucSutunu(
                                          '🏆',
                                          'KAZANAN',
                                          tekTurnuva.turKazanan,
                                          const Color(0xFFFCD34D),
                                        ),
                                      ),
                                      _blokAyirac(34),
                                      Expanded(
                                        child: _sonucSutunu(
                                          '📉',
                                          'KAYBEDEN',
                                          tekTurnuva.turKaybeden,
                                          const Color(0xFFF87171),
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
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // amber ambient — kupa/ödül teması (korundu)
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
                                _ciftRozet(
                                  _sezonNumara[tekTurnuva.sezonId],
                                  tekTurnuva.numara,
                                  koyu: true,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  tekTurnuva.turTarih ?? 'Tarih Yok',
                                  style: const TextStyle(
                                    color: Color(0xFFF8FAFC),
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
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.emoji_events,
                              color: Color(0xFFFCD34D),
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _Kivilcim(),
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
                              color: Color(0xFF94A3B8),
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
                            _heroAksiyonButonu(
                              icon: Icons.flag,
                              renk: const Color(0xFF4ADE80),
                              etiket: "Sonlandır",
                              onTap: () async =>
                                  _turnuvayiSonlandir(tekTurnuva),
                            ),
                            _heroAksiyonButonu(
                              icon: Icons.edit,
                              renk: const Color(0xFFE2E8F0),
                              etiket: "Düzenle",
                              onTap: () =>
                                  _turnuvaFormuGoster(turnuva: tekTurnuva),
                            ),
                            _heroAksiyonButonu(
                              icon: Icons.delete,
                              renk: Colors.amber.shade700,
                              etiket: "Sil",
                              onTap: () async {
                                final onay = await showDialog<bool>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    backgroundColor: const Color(0xFF111A2B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    title: const Text(
                                      'Emin misiniz?',
                                      style: TextStyle(
                                        color: Color(0xFFF8FAFC),
                                      ),
                                    ),
                                    content: const Text(
                                      'Aktif turnuvayı kalıcı olarak silmek istediğinize emin misiniz?',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, false),
                                        child: const Text(
                                          'İptal',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        child: const Text(
                                          'Sil',
                                          style: TextStyle(
                                            color: Color(0xFFFCD34D),
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
  void dispose() {
    _tarihController.dispose();
    _kazananController.dispose();
    _ikinciController.dispose();
    _ucuncuController.dispose();
    _kaybedenController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// KIVILCIM — hero'nun ortasında nabız atan turuncu çekirdek (KORUNDU)
// ─────────────────────────────────────────────────────────────
class _Kivilcim extends StatefulWidget {
  const _Kivilcim();
  @override
  State<_Kivilcim> createState() => _KivilcimState();
}

class _KivilcimState extends State<_Kivilcim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return Container(
          width: 64 + 12 * t,
          height: 64 + 12 * t,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orangeAccent.withValues(alpha: 0.18 + 0.12 * t),
            boxShadow: [
              BoxShadow(
                color: Colors.orangeAccent.withValues(alpha: 0.5 * t),
                blurRadius: 24 + 10 * t,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.local_fire_department,
            color: Colors.orangeAccent,
            size: 40 + 6 * t,
          ),
        );
      },
    );
  }
}
