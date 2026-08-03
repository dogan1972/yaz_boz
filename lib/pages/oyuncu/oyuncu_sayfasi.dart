import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/firestore_service.dart';

// ─────────────────────────────────────────────────────────────
// OYUNCU MODELİ  (sade — sayaçlar artık canlı hesaplanıyor)
// ─────────────────────────────────────────────────────────────
class Oyuncu {
  final String id;
  final String oyuncuAdSoyad;
  final String oyuncuSehir;
  final int isAktif; // 1 aktif, 0 pasif/arşiv

  Oyuncu({
    required this.id,
    required this.oyuncuAdSoyad,
    required this.oyuncuSehir,
    this.isAktif = 1,
  });

  factory Oyuncu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Oyuncu(
      id: doc.id,
      oyuncuAdSoyad: data['oyuncuAdSoyad'] ?? '',
      oyuncuSehir: data['oyuncuSehir'] ?? '',
      isAktif: (data['isAktif'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'oyuncuAdSoyad': oyuncuAdSoyad,
    'oyuncuSehir': oyuncuSehir,
    'isAktif': isAktif,
  };
}

// ✅ CANLI İSTATİSTİK — oyunlar + turnuvalardan türetilir, modele yazılmaz
class _OyuncuIstatistik {
  int oyunOynadi = 0;
  int oyunKazandi = 0;
  int oyunKaybetti = 0;
  int turnuvaKatildi = 0;
  int turnuvaKazandi = 0;

  bool get bos => oyunOynadi == 0 && turnuvaKatildi == 0 && turnuvaKazandi == 0;
}

class OyuncuSayfasi extends StatefulWidget {
  const OyuncuSayfasi({super.key});

  @override
  State<OyuncuSayfasi> createState() => _OyuncuSayfasiState();
}

class _OyuncuSayfasiState extends State<OyuncuSayfasi> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _sehirController = TextEditingController();
  final TextEditingController _aramaController = TextEditingController();

  // üç canlı kaynak
  List<Oyuncu> _tumOyuncular = [];
  List<dynamic> _oyunlar = []; // DocumentSnapshot
  List<dynamic> _turnuvalar = []; // DocumentSnapshot

  // türetilmiş
  Map<String, _OyuncuIstatistik> _istatistikler = {};
  List<Oyuncu> _filtrelenmisOyuncular = [];
  List<String> _sehirlerListesi = [];

  String? _seciliSehir; // null = tüm şehirler
  bool _aramaYapiliyorMu = false;
  bool _gosterPasifArsiv = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sehirleriYukle();
    _oyunculariDinle();
    _oyunlariDinle();
    _turnuvalariDinle();
  }

  // ── stream'ler: her biri cache'ini güncelleyip ortak rebuild'i çağırır ──
  void _oyunculariDinle() {
    _firestoreService.getCollectionStream('oyuncular').listen((snap) {
      if (!mounted) return;
      _tumOyuncular = snap.docs.map(Oyuncu.fromFirestore).toList();
      _rebuild();
    });
  }

  void _oyunlariDinle() {
    _firestoreService.getCollectionStream('oyunlar').listen((snap) {
      if (!mounted) return;
      _oyunlar = snap.docs;
      _rebuild();
    });
  }

  void _turnuvalariDinle() {
    _firestoreService.getCollectionStream('turnuva').listen((snap) {
      if (!mounted) return;
      _turnuvalar = snap.docs;
      _rebuild();
    });
  }

  Future<void> _sehirleriYukle() async {
    try {
      final snap = await _firestoreService.getCollection('sehirler');
      if (!mounted) return;
      setState(() {
        _sehirlerListesi =
            snap.docs
                .map(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['sehirAd']
                          ?.toString() ??
                      '',
                )
                .where((s) => s.isNotEmpty)
                .toList()
              ..sort();
      });
    } catch (e) {
      debugPrint("Şehirler yüklenirken hata: $e");
    }
  }

  // ✅ CANLI HESAP — oyunlar + turnuvalar üzerinden, ad anahtarlı
  Map<String, _OyuncuIstatistik> _istatistikleriHesapla() {
    final map = <String, _OyuncuIstatistik>{};
    _OyuncuIstatistik of(String ad) =>
        map.putIfAbsent(ad, () => _OyuncuIstatistik());

    // her oyuncunun hangi turnuvalarda (turId) oynadığını saymak için
    final oyunTurSeti = <String, Set<String>>{};

    for (final doc in _oyunlar) {
      final data = doc.data() as Map<String, dynamic>;
      final turId = data['turId']?.toString() ?? '';
      final kaybeden = data['oyunKaybeden']?.toString();
      final raw = data['oyuncu']?.toString() ?? '';
      final adlar = raw
          .split(RegExp(r'[,\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (final ad in adlar) {
        of(ad).oyunOynadi++;
        if (turId.isNotEmpty) {
          oyunTurSeti.putIfAbsent(ad, () => {}).add(turId);
        }
        if (kaybeden != null && kaybeden.isNotEmpty) {
          if (ad == kaybeden) {
            of(ad).oyunKaybetti++;
          } else {
            of(ad).oyunKazandi++;
          }
        }
      }
    }

    // turnuva katılımı = adı geçen distinct turId sayısı
    oyunTurSeti.forEach((ad, set) => of(ad).turnuvaKatildi = set.length);

    // turnuva kazanma = turKazanan eşleşmesi
    for (final doc in _turnuvalar) {
      final data = doc.data() as Map<String, dynamic>;
      final kazanan = data['turKazanan']?.toString();
      if (kazanan != null && kazanan.isNotEmpty) {
        of(kazanan).turnuvaKazandi++;
      }
    }

    return map;
  }

  // ortak güncelleme: istatistik + filtre + tek setState
  void _rebuild() {
    _istatistikler = _istatistikleriHesapla();
    _filtrele(_aramaController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ── birleşik filtre: arama + şehir + aktif/pasif ──
  void _filtrele(String arama) {
    final k = arama.toLowerCase().trim();
    _filtrelenmisOyuncular = _tumOyuncular.where((o) {
      final aramaTamam =
          k.isEmpty ||
          o.oyuncuAdSoyad.toLowerCase().contains(k) ||
          o.oyuncuSehir.toLowerCase().contains(k);
      final sehirTamam = _seciliSehir == null || o.oyuncuSehir == _seciliSehir;
      final durumTamam = _gosterPasifArsiv ? o.isAktif == 0 : o.isAktif == 1;
      return aramaTamam && sehirTamam && durumTamam;
    }).toList();
  }

  // ───────────────────────────────────────────────────────────
  // OYUNCU FORMU
  // ───────────────────────────────────────────────────────────
  void _oyuncuFormuGoster({Oyuncu? oyuncu}) {
    if (oyuncu != null) {
      _adController.text = oyuncu.oyuncuAdSoyad;
      _sehirController.text = oyuncu.oyuncuSehir;
    } else {
      _adController.clear();
      _sehirController.text = _sehirlerListesi.isNotEmpty
          ? _sehirlerListesi.first
          : '';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(oyuncu == null ? 'Yeni Oyuncu Ekle' : 'Oyuncuyu Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _adController,
              decoration: const InputDecoration(
                labelText: 'Oyuncu Adı Soyadı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _sehirlerListesi.isEmpty
                ? TextField(
                    controller: _sehirController,
                    decoration: const InputDecoration(
                      labelText: 'Şehir',
                      border: OutlineInputBorder(),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue:
                        _sehirlerListesi.contains(_sehirController.text)
                        ? _sehirController.text
                        : null,
                    hint: const Text('Şehir seçin'),
                    decoration: const InputDecoration(
                      labelText: 'Şehir Seçin',
                      border: OutlineInputBorder(),
                    ),
                    items: _sehirlerListesi
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _sehirController.text = val;
                    },
                  ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (_adController.text.trim().isEmpty) return;
              final data = {
                'oyuncuAdSoyad': _adController.text.trim(),
                'oyuncuSehir': _sehirController.text.trim(),
                'isAktif': oyuncu?.isAktif ?? 1,
              };
              if (oyuncu == null) {
                await _firestoreService.setDocument(
                  'oyuncular',
                  FirebaseFirestore.instance.collection('oyuncular').doc().id,
                  data,
                );
              } else {
                await _firestoreService.updateDocument(
                  'oyuncular',
                  oyuncu.id,
                  data,
                );
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isYatay =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final appBarBaslik = _aramaYapiliyorMu
        ? TextField(
            controller: _aramaController,
            autofocus: true,
            style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Oyuncu veya şehir ara...',
              hintStyle: TextStyle(color: Color(0xFF64748B)),
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _filtrele(v)),
          )
        : Text(
            _gosterPasifArsiv ? 'Oyuncular (Arşiv)' : 'Oyuncular',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          );

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F1C),
        appBar: AppBar(
          title: const Text('Oyuncular'),
          backgroundColor: const Color(0xFF0B1220),
          foregroundColor: const Color(0xFFF8FAFC),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: appBarBaslik,
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_aramaYapiliyorMu ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              if (_aramaYapiliyorMu) {
                _aramaController.clear();
                _filtrele('');
              }
              _aramaYapiliyorMu = !_aramaYapiliyorMu;
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _sehirFiltreCubugu(),
          Expanded(
            child: _filtrelenmisOyuncular.isEmpty
                ? _bosDurum()
                : ListView.builder(
                    itemCount: _filtrelenmisOyuncular.length,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    itemBuilder: (itemContext, index) {
                      final oyuncu = _filtrelenmisOyuncular[index];
                      final ist =
                          _istatistikler[oyuncu.oyuncuAdSoyad] ??
                          _OyuncuIstatistik();
                      return _oyuncuKarti(oyuncu, ist, isYatay);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 90, 80),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _gosterPasifArsiv = !_gosterPasifArsiv;
                  _filtrele(_aramaController.text);
                }),
                icon: Icon(
                  _gosterPasifArsiv ? Icons.group : Icons.archive_outlined,
                  color: const Color(0xFFE2E8F0),
                ),
                label: Text(
                  _gosterPasifArsiv
                      ? "Aktif Oyunculara Dön"
                      : "Oyuncular (Arşiv)",
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
          onPressed: () => _oyuncuFormuGoster(),
          backgroundColor: const Color(0xFFF59E0B),
          child: const Icon(Icons.add, color: Color(0xFF1A1206)),
        ),
      ),
    );
  }

  // ── Şehir filtre çubuğu ───────────────────────────────────
  Widget _sehirFiltreCubugu() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111A2B),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 8),
          const Text(
            'Şehir',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _seciliSehir,
              isExpanded: true,
              dropdownColor: const Color(0xFF111A2B),
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF0B1220),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Tüm Şehirler',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ..._sehirlerListesi.map(
                  (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
                ),
              ],
              onChanged: (v) => setState(() {
                _seciliSehir = v;
                _filtrele(_aramaController.text);
              }),
            ),
          ),
          if (_seciliSehir != null) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() {
                _seciliSehir = null;
                _filtrele(_aramaController.text);
              }),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, color: Color(0xFFF87171), size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bosDurum() {
    final filtreli = _aramaController.text.isNotEmpty || _seciliSehir != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_search, size: 56, color: Color(0xFF334155)),
          const SizedBox(height: 12),
          Text(
            filtreli
                ? 'Kriterlere uygun oyuncu bulunamadı.'
                : (_gosterPasifArsiv
                      ? 'Arşivde oyuncu yok.'
                      : 'Henüz oyuncu eklenmemiş.'),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Oyuncu kartı — canlı istatistik rozetleri ─────────────
  // ── Oyuncu kartı — dikey iki bölge: üstte kimlik+buton, altta tam genişlik karne
  Widget _oyuncuKarti(Oyuncu oyuncu, _OyuncuIstatistik ist, bool isYatay) {
    final pasif = _gosterPasifArsiv;

    final kimlik = Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: pasif
              ? const Color(0xFF1E293B)
              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
          child: Icon(
            Icons.person,
            color: pasif ? const Color(0xFF64748B) : const Color(0xFFF59E0B),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                oyuncu.oyuncuAdSoyad,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: pasif
                      ? const Color(0xFF64748B)
                      : const Color(0xFFF8FAFC),
                  decoration: pasif ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.pin_drop,
                    size: 13,
                    color: Color(0xFFF87171),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      "Şehir: ${oyuncu.oyuncuSehir}",
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
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
      ],
    );

    final ustSatir = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: kimlik),
        const SizedBox(width: 6),
        _aksiyonButonlari(oyuncu),
      ],
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      color: const Color(0xFF111A2B),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: pasif ? null : () => _oyuncuFormuGoster(oyuncu: oyuncu),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: isYatay
              ? ustSatir
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [ustSatir, const SizedBox(height: 10), _karne(ist)],
                ),
        ),
      ),
    );
  }

  // ✅ İki satırlı canlı karne — hiç kayıt yoksa dürüst boş-not

  Widget _karneSatir(IconData icon, Color renk, List<Widget> parcalar) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: renk.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // ✅ tam genişlikte dengeli
        children: [
          Icon(icon, size: 13, color: renk),
          const SizedBox(width: 6),
          ..._arayaAyirac(parcalar),
        ],
      ),
    );
  }

  Widget _karne(_OyuncuIstatistik ist) {
    if (ist.bos) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 6),
            Text(
              'Henüz kayıt yok',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _karneSatir(Icons.sports_esports, const Color(0xFF60A5FA), [
          _sayi('${ist.oyunOynadi}', 'maç', const Color(0xFF94A3B8)),
          _sayi('${ist.oyunKazandi}', 'galibiyet', const Color(0xFF4ADE80)),
          _sayi('${ist.oyunKaybetti}', 'mağlubiyet', const Color(0xFFF87171)),
        ]),
        const SizedBox(height: 5),
        _karneSatir(Icons.emoji_events, const Color(0xFFF59E0B), [
          _sayi('${ist.turnuvaKatildi}', 'katılım', const Color(0xFF94A3B8)),
          _sayi('${ist.turnuvaKazandi}', 'şampiyon', const Color(0xFFFCD34D)),
        ]),
      ],
    );
  }

  List<Widget> _arayaAyirac(List<Widget> w) {
    final out = <Widget>[];
    for (var i = 0; i < w.length; i++) {
      if (i > 0) {
        out.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: TextStyle(color: Color(0xFF475569), fontSize: 12),
            ),
          ),
        );
      }
      out.add(w[i]);
    }
    return out;
  }

  Widget _sayi(String deger, String etiket, Color renk) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          deger,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: renk,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          etiket,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
      ],
    );
  }

  // ── Arşiv/Geri + Sil ──────────────────────────────────────
  Widget _aksiyonButonlari(Oyuncu oyuncu) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _yuvarlakButon(
          icon: _gosterPasifArsiv
              ? Icons.settings_backup_restore
              : Icons.archive,
          renk: _gosterPasifArsiv ? Colors.green : Colors.blueGrey,
          onTap: () async {
            await _firestoreService.updateDocument('oyuncular', oyuncu.id, {
              'isAktif': _gosterPasifArsiv ? 1 : 0,
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _gosterPasifArsiv
                      ? "🎉 Oyuncu masaya geri döndü!"
                      : "📁 Oyuncu arşive kaldırıldı.",
                ),
                backgroundColor: _gosterPasifArsiv
                    ? Colors.green.shade800
                    : Colors.blueGrey.shade800,
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        _yuvarlakButon(
          icon: Icons.delete,
          renk: Colors.amber.shade800,
          onTap: () async {
            final onay = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('Oyuncuyu Kalıcı Sil'),
                content: Text(
                  '${oyuncu.oyuncuAdSoyad} isimli oyuncuyu tamamen silmek istiyor musunuz?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: Text(
                      'Kalıcı Sil',
                      style: TextStyle(color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            );
            if (onay == true && mounted) {
              await _firestoreService.deleteDocument('oyuncular', oyuncu.id);
            }
          },
        ),
      ],
    );
  }

  Widget _yuvarlakButon({
    required IconData icon,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: renk, size: 22),
      ),
    );
  }

  @override
  void dispose() {
    _adController.dispose();
    _sehirController.dispose();
    _aramaController.dispose();
    super.dispose();
  }
}
