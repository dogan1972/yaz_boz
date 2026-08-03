import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/firestore_service.dart';
import 'package:yaz_boz/pages/sezon/sezon_detay_sayfasi.dart';

// ─────────────────────────────────────────────────────────────
// SEZON MODELİ  (+ numara)
// ─────────────────────────────────────────────────────────────
class Sezon {
  final String id;
  final int? numara;
  final String sezonTarih;
  final String? sezonSampiyon;

  Sezon({
    required this.id,
    this.numara,
    required this.sezonTarih,
    this.sezonSampiyon,
  });

  factory Sezon.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sezon(
      id: doc.id,
      numara: (data['numara'] as num?)?.toInt(),
      sezonTarih: data['sezonTarih'] ?? '',
      sezonSampiyon: data['sezonSampiyon'],
    );
  }

  Map<String, dynamic> toMap() => {
    'numara': numara,
    'sezonTarih': sezonTarih,
    'sezonSampiyon': sezonSampiyon,
  };
}

// ✅ Detaylı sezon istatistiği (sonlandırma sıralaması için)
class OyuncuSezonIstatistigi {
  final String ad;
  int trvKazanma = 0;
  int trvKatilim = 0;
  int oyunGalibiyet = 0;
  double enIyiElSkoru;

  OyuncuSezonIstatistigi(this.ad, {required bool isLowestWins})
    : enIyiElSkoru = isLowestWins ? double.infinity : double.negativeInfinity;
}

class SezonlarSayfasi extends StatefulWidget {
  const SezonlarSayfasi({super.key});

  @override
  State<SezonlarSayfasi> createState() => _SezonlarSayfasiState();
}

class _SezonlarSayfasiState extends State<SezonlarSayfasi> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _tarihController = TextEditingController();
  final TextEditingController _sampiyonController = TextEditingController();

  bool _gosterArsiv = false;
  List<Sezon> _tumSezonlar = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
  }

  // ✅ OPTİMİZE: veri değişmediyse setState yok → donma önlenir
  void _verileriDinle() {
    _firestoreService.getCollectionStream('sezonlar').listen((snapshot) {
      if (!mounted) return;
      final yeni = snapshot.docs.map((d) => Sezon.fromFirestore(d)).toList()
        ..sort((a, b) => b.sezonTarih.compareTo(a.sezonTarih));
      if (yeni.length != _tumSezonlar.length ||
          !_listelerEsitMi(yeni, _tumSezonlar)) {
        setState(() {
          _tumSezonlar = yeni;
          _isLoading = false;
        });
      } else if (_isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  bool _listelerEsitMi(List<Sezon> a, List<Sezon> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].numara != b[i].numara ||
          a[i].sezonTarih != b[i].sezonTarih ||
          a[i].sezonSampiyon != b[i].sezonSampiyon) {
        return false;
      }
    }
    return true;
  }

  // ✅ NUMARA ROZETİ — tablo rakamlı, gölgeli, tek yerden tutarlı
  Widget _numaraRozeti(int? n, {Color renk = Colors.blue, double? font}) {
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

  // ───────────────────────────────────────────────────────────
  // SEZON FORMU  (yeni kayıtta numara, düzenlemede dokunma)
  // ───────────────────────────────────────────────────────────
  void _sezonFormuGoster({Sezon? sezon}) {
    if (sezon != null) {
      _tarihController.text = sezon.sezonTarih;
      _sampiyonController.text = sezon.sezonSampiyon ?? '';
    } else {
      _tarihController.text = DateTime.now().toString().substring(0, 10);
      _sampiyonController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(sezon == null ? 'Yeni Sezon Ekle' : 'Sezonu Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tarihController,
              decoration: const InputDecoration(
                labelText: 'Sezon Tarihi / Adı',
                border: OutlineInputBorder(),
              ),
            ),
            if (sezon != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _sampiyonController,
                decoration: const InputDecoration(
                  labelText: 'Sezon Şampiyonu',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_tarihController.text.trim().isEmpty) return;

              if (sezon == null) {
                // ✅ YENİ KAYIT: atomik sıralı numara
                final data = <String, dynamic>{
                  'sezonTarih': _tarihController.text.trim(),
                  'sezonSampiyon': _sampiyonController.text.trim().isEmpty
                      ? null
                      : _sampiyonController.text.trim(),
                  'numara': await _firestoreService.nextNumber('sezonlar'),
                };
                await _firestoreService.setDocument(
                  'sezonlar',
                  FirebaseFirestore.instance.collection('sezonlar').doc().id,
                  data,
                );
              } else {
                // ✅ DÜZENLEME: numara'ya DOKUNMA
                await _firestoreService.updateDocument('sezonlar', sezon.id, {
                  'sezonTarih': _tarihController.text.trim(),
                  'sezonSampiyon': _sampiyonController.text.trim().isEmpty
                      ? null
                      : _sampiyonController.text.trim(),
                });
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
  // HİYERARŞİK SİLME  (sezon → turnuva → oyun → el)
  // ───────────────────────────────────────────────────────────
  Future<void> _sezonuSil(Sezon tekSezon) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final tumTurnuvalarSnap = await _firestoreService.getCollection(
        'turnuva',
      );
      final silinecekTurnuvalar = tumTurnuvalarSnap.docs
          .where(
            (d) =>
                (d.data() as Map<String, dynamic>)['sezonId'].toString() ==
                tekSezon.id,
          )
          .toList();

      for (var turDoc in silinecekTurnuvalar) {
        final turId = turDoc.id;
        final tumOyunlarSnap = await _firestoreService.getCollection('oyunlar');
        final silinecekOyunlar = tumOyunlarSnap.docs
            .where((d) => (d.data() as Map<String, dynamic>)['turId'] == turId)
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
        await _firestoreService.deleteDocument('turnuva', turId);
      }

      await _firestoreService.deleteDocument('sezonlar', tekSezon.id);

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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ───────────────────────────────────────────────────────────
  // SONLANDIRMA  (aktif kilit + katılım oyunlardan + en iyi skor eller'den)
  // ───────────────────────────────────────────────────────────
  Future<void> _sezonuSonlandir(Sezon tekSezon) async {
    try {
      if (!mounted) return;

      final tumTurnuvalarSnap = await _firestoreService.getCollection(
        'turnuva',
      );
      if (!mounted) return;
      final sezonTurnuvalari = tumTurnuvalarSnap.docs
          .where(
            (d) =>
                (d.data() as Map<String, dynamic>)['sezonId'].toString() ==
                tekSezon.id,
          )
          .toList();

      final tumOyunlarSnap = await _firestoreService.getCollection('oyunlar');
      if (!mounted) return;
      final sezonOyunlari = tumOyunlarSnap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['turId'].toString().isNotEmpty &&
            sezonTurnuvalari.any((t) => t.id == data['turId']);
      }).toList();

      // ✅ AKTİF TURNUVA + AKTİF OYUN KİLİDİ — spinner'dan ÖNCE
      final aktifTur = sezonTurnuvalari
          .where(
            (d) => (d.data() as Map<String, dynamic>)['turKazanan'] == null,
          )
          .length;
      final aktifOyun = sezonOyunlari
          .where(
            (d) => (d.data() as Map<String, dynamic>)['oyunKazanan'] == null,
          )
          .length;
      if (aktifTur > 0 || aktifOyun > 0) {
        if (!mounted) return;
        final parca = <String>[];
        if (aktifTur > 0) parca.add('$aktifTur aktif turnuva');
        if (aktifOyun > 0) parca.add('$aktifOyun aktif oyun');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "⚠️ Bu sezonda hâlâ devam eden ${parca.join(' ve ')} var — önce onları sonlandırın.",
            ),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      bool isLowestWins = false;
      Map<String, OyuncuSezonIstatistigi> statsMap = {};

      if (sezonTurnuvalari.isNotEmpty) {
        final ilkTurData =
            sezonTurnuvalari.first.data() as Map<String, dynamic>;
        isLowestWins = ilkTurData['isLowestWins'] == true;

        // turnuva katkısı: SADECE turnuva kazanma (katılım burada DEĞİL)
        for (var turDoc in sezonTurnuvalari) {
          final data = turDoc.data() as Map<String, dynamic>;
          final kazanan = data['turKazanan'];
          if (kazanan != null && kazanan.toString().isNotEmpty) {
            final a = kazanan.toString();
            statsMap.putIfAbsent(
              a,
              () => OyuncuSezonIstatistigi(a, isLowestWins: isLowestWins),
            );
            statsMap[a]!.trvKazanma++;
          }
        }

        // ✅ oyun katkısı: oyun galibiyet + KATILIM (distinct turId)
        final oyuncuTurSeti = <String, Set<String>>{};
        for (var oyunDoc in sezonOyunlari) {
          final data = oyunDoc.data() as Map<String, dynamic>;
          final kaybeden = data['oyunKaybeden'];
          final turId = data['turId']?.toString();
          if (data['oyuncu'] != null) {
            for (var s in data['oyuncu'].toString().split(RegExp(r'[,\n]'))) {
              final o = s.trim();
              if (o.isNotEmpty) {
                statsMap.putIfAbsent(
                  o,
                  () => OyuncuSezonIstatistigi(o, isLowestWins: isLowestWins),
                );
                if (turId != null && turId.isNotEmpty) {
                  oyuncuTurSeti.putIfAbsent(o, () => {}).add(turId);
                }
                if (kaybeden == null || kaybeden.toString() != o) {
                  statsMap[o]!.oyunGalibiyet++;
                }
              }
            }
          }
        }
        // katılım = oyuncunun adının geçtiği distinct turnuva sayısı
        oyuncuTurSeti.forEach((ad, set) {
          if (statsMap.containsKey(ad)) statsMap[ad]!.trvKatilim = set.length;
        });

        // ✅ EN İYİ EL SKORU — skorlar 'eller' koleksiyonunda, oyunId ile süz
        final sezonOyunIdSet = sezonOyunlari.map((d) => d.id).toSet();
        final ellerSnap = await _firestoreService.getCollection('eller');
        if (!mounted) return;
        for (var elDoc in ellerSnap.docs) {
          final elData = elDoc.data() as Map<String, dynamic>;
          if (!sezonOyunIdSet.contains(elData['oyunId']?.toString())) continue;
          final skorlar = elData['skorlar'];
          if (skorlar is! Map) continue;
          skorlar.forEach((oyuncu, skor) {
            final ad = oyuncu.toString();
            if (!statsMap.containsKey(ad)) return;
            final v = (skor is num)
                ? skor.toDouble()
                : (double.tryParse(skor.toString()) ?? 0.0);
            if (isLowestWins) {
              if (v < statsMap[ad]!.enIyiElSkoru) {
                statsMap[ad]!.enIyiElSkoru = v;
              }
            } else {
              if (v > statsMap[ad]!.enIyiElSkoru) {
                statsMap[ad]!.enIyiElSkoru = v;
              }
            }
          });
        }
      } else {
        // ✅ BOŞ SEZON: manuel şampiyon
        if (!mounted) return;
        Navigator.pop(context);
        final controller = TextEditingController();
        final manuel = await showDialog<String>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Sezonu Sonlandır'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Bu sezonda hiç turnuva bulunmuyor.\nLütfen şampiyon adını girin:",
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Şampiyon Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, null),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(d, controller.text.trim()),
                child: const Text('Onayla'),
              ),
            ],
          ),
        );
        if (manuel == null || manuel.isEmpty || !mounted) return;
        await _firestoreService.updateDocument('sezonlar', tekSezon.id, {
          'sezonSampiyon': manuel,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sezon bitti! Şampiyon: $manuel"),
            backgroundColor: Colors.indigo.shade800,
          ),
        );
        return;
      }

      final sirali = statsMap.values.toList();
      final lowestRef = isLowestWins;
      sirali.sort((a, b) {
        if (b.trvKazanma != a.trvKazanma) {
          return b.trvKazanma.compareTo(a.trvKazanma);
        }
        if (b.trvKatilim != a.trvKatilim) {
          return b.trvKatilim.compareTo(a.trvKatilim);
        }
        if (b.oyunGalibiyet != a.oyunGalibiyet) {
          return b.oyunGalibiyet.compareTo(a.oyunGalibiyet);
        }
        return lowestRef
            ? a.enIyiElSkoru.compareTo(b.enIyiElSkoru)
            : b.enIyiElSkoru.compareTo(a.enIyiElSkoru);
      });
      final sampiyon = sirali.isNotEmpty ? sirali.first.ad : null;

      if (!mounted) return;
      Navigator.pop(context);

      final onay = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Sezonu Sonlandır'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hesaplanan Sıralama (${lowestRef ? 'En Düşük Skor Kazanır' : 'En Yüksek Skor Kazanır'}):",
                ),
                const SizedBox(height: 8),
                ...sirali
                    .take(5)
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          "${s.ad}: ${s.trvKazanma} Trv. Kaz., ${s.trvKatilim} Kat., ${s.oyunGalibiyet} Oyun Gal., En İyi Skor: ${s.enIyiElSkoru}",
                        ),
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Onayla', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
      if (onay != true || !mounted) return;

      await _firestoreService.updateDocument('sezonlar', tekSezon.id, {
        'sezonSampiyon': sampiyon,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sezon bitti! Şampiyon: $sampiyon"),
          backgroundColor: Colors.indigo.shade800,
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

  Widget _heroAksiyonButonu({
    required IconData icon,
    required Color renk,
    required String etiket,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: renk, size: 22),
            const SizedBox(height: 2),
            Text(
              etiket,
              style: TextStyle(
                color: renk.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    final liste = _tumSezonlar
        .where(
          (s) =>
              _gosterArsiv ? s.sezonSampiyon != null : s.sezonSampiyon == null,
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuçlanan Sezonlar (Arşiv)' : 'Aktif Sezonlar',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
      ),
      body: Column(
        children: [
          Expanded(
            child: liste.isEmpty
                ? _bosDurum()
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
                  color: const Color(0xFFE2E8F0),
                ),
                label: Text(
                  _gosterArsiv
                      ? "Aktif Sezonlara Dön"
                      : "Eski Sezonlar (Arşiv)",
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
          onPressed: () {
            final aktifVar = _tumSezonlar.any((s) => s.sezonSampiyon == null);
            if (aktifVar && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "⚠️ Sistemde zaten devam eden AKTİF BİR SEZON bulunuyor!",
                  ),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }
            _sezonFormuGoster();
          },
          backgroundColor: const Color(0xFFF59E0B),
          child: const Icon(Icons.add, color: Color(0xFF1A1206)),
        ),
      ),
    );
  }

  // ✅ Karakterli boş durum (düz gri metin yerine ikonlu yönlendirme)
  Widget _bosDurum() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _gosterArsiv ? Icons.inventory_2_outlined : Icons.flag_outlined,
            size: 64,
            color: const Color(0xFF334155),
          ),
          const SizedBox(height: 14),
          Text(
            _gosterArsiv
                ? 'Arşivde hiç sezon bulunmuyor.'
                : 'Aktif (devam eden) sezon bulunmuyor.',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _gosterArsiv
                ? 'Sonlanan sezonlar burada listelenecek.'
                : 'Yeni sezon başlatmak için + butonuna dokun.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // ARŞİV LİSTESİ  (rozet + tıklanınca detay)
  // ───────────────────────────────────────────────────────────
  Widget _arsivListeGorunumu(List<Sezon> sezonlar) {
    return ListView.builder(
      itemCount: sezonlar.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (itemContext, index) {
        final tekSezon = sezonlar[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFF111A2B),
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
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF334155),
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
                                  _numaraRozeti(
                                    tekSezon.numara,
                                    renk: const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tekSezon.sezonTarih,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Color(0xFFF8FAFC),
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
                                          color: const Color(
                                            0xFF64748B,
                                          ).withValues(alpha: 0.55),
                                          width: 1.4,
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        'ARŞİV',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
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
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Text(
                                    '🏆 ',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Expanded(
                                    child: Text(
                                      tekSezon.sezonSampiyon ?? '—',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFCD34D),
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
                      _silDugmesi(
                        onTap: () async {
                          final onay = await showDialog<bool>(
                            context: itemContext,
                            builder: (d) => AlertDialog(
                              backgroundColor: const Color(0xFF111A2B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: const Text(
                                'Sezonu Sil',
                                style: TextStyle(color: Color(0xFFF8FAFC)),
                              ),
                              content: const Text(
                                'Bu sezonu ve altındaki TÜM verileri kalıcı olarak silmek istediğinize emin misiniz?',
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
                                  child: Text(
                                    'Sil',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
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

  // ✅ Ortak sil butonu — basınca kırmızıya dönen, tehlike hissi veren yüzey
  Widget _silDugmesi({required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.amber.shade800,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // AKTİF HERO KARTI  (canlı yüzey: ripple + amber rozet)
  // ───────────────────────────────────────────────────────────
  Widget _aktifHeroGorunumu(Sezon tekSezon) {
    final double h = MediaQuery.of(context).size.height;
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
            height: h * 0.55,
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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _numaraRozeti(
                              tekSezon.numara,
                              renk: const Color(0xFFFCD34D),
                              font: 15,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tekSezon.sezonTarih,
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
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
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Color(0xFFFCD34D),
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 54),
                      SizedBox(height: 8),
                      Text(
                        "SEZON DEVAM EDİYOR",
                        style: TextStyle(
                          color: Color(0xFFFCD34D),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Masada rekabet tüm hızıyla sürüyor.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
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
                        _heroAksiyonButonu(
                          icon: Icons.gavel,
                          renk: const Color(0xFFFCD34D),
                          etiket: "Sonlandır",
                          onTap: () async => _sezonuSonlandir(tekSezon),
                        ),
                        _heroAksiyonButonu(
                          icon: Icons.edit,
                          renk: const Color(0xFFE2E8F0),
                          etiket: "Düzenle",
                          onTap: () => _sezonFormuGoster(sezon: tekSezon),
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
                                  'Sezonu Sil',
                                  style: TextStyle(color: Color(0xFFF8FAFC)),
                                ),
                                content: const Text(
                                  'Bu sezonu ve altındaki TÜM verileri kalıcı olarak silmek istediğinize emin misiniz?',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text(
                                      'İptal',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: Text(
                                      'Sil',
                                      style: TextStyle(
                                        color: Colors.amber.shade700,
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
  void dispose() {
    _tarihController.dispose();
    _sampiyonController.dispose();
    super.dispose();
  }
}
