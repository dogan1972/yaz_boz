import 'package:flutter/material.dart';
import 'package:yaz_boz/helper/database_helper.dart';

// Kariyer istatistikleri entegre edilmiş evrensel Oyuncu Modeli
class Oyuncu {
  final int? oyuncuId;
  final String oyuncuAdSoyad;
  final String oyuncuSehir;
  final int isAktif; // 1: Aktif, 0: Pasif/Arşiv

  final int toplamOyun;
  final int kazanilanOyun;
  final int kaybedilenOyun;

  Oyuncu({
    this.oyuncuId,
    required this.oyuncuAdSoyad,
    required this.oyuncuSehir,
    this.isAktif = 1,
    this.toplamOyun = 0,
    this.kazanilanOyun = 0,
    this.kaybedilenOyun = 0,
  });

  factory Oyuncu.fromMap(Map<String, dynamic> map) {
    return Oyuncu(
      oyuncuId: map['oyuncuId'],
      oyuncuAdSoyad: map['oyuncuAdSoyad'] ?? '',
      oyuncuSehir: map['oyuncuSehir'] ?? '',
      isAktif: map['isAktif'] ?? 1,
      toplamOyun: map['toplamOyun'] ?? 0,
      kazanilanOyun: map['kazanilanOyun'] ?? 0,
      kaybedilenOyun: map['kaybedilenOyun'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (oyuncuId != null) 'oyuncuId': oyuncuId,
      'oyuncuAdSoyad': oyuncuAdSoyad,
      'oyuncuSehir': oyuncuSehir,
      'isAktif': isAktif,
    };
  }

  // 🚀 SQL MOTORU: 'oyuncu' tablosundan canlı kariyer karnesini hatasız çeker
  static Future<List<Oyuncu>> getAllWithStats() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        o.*,
        (SELECT COUNT(*) FROM oyunlar WHERE ',' || oyuncu || ',' LIKE '% ' || o.oyuncuAdSoyad || ',%' OR ',' || oyuncu || ',' LIKE '% ' || o.oyuncuAdSoyad || '%') as toplamOyun,
        (SELECT COUNT(*) FROM oyunlar WHERE oyunKazanan = o.oyuncuAdSoyad) as kazanilanOyun,
        (SELECT COUNT(*) FROM oyunlar WHERE oyunKaybeden = o.oyuncuAdSoyad) as kaybedilenOyun
      FROM oyuncu o
      ORDER BY o.oyuncuAdSoyad ASC
    ''');
    return List.generate(maps.length, (i) => Oyuncu.fromMap(maps[i]));
  }
}

class OyuncuSayfasi extends StatefulWidget {
  const OyuncuSayfasi({super.key});

  @override
  State<OyuncuSayfasi> createState() => _OyuncuSayfasiState();
}

class _OyuncuSayfasiState extends State<OyuncuSayfasi> {
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _sehirController = TextEditingController();
  final TextEditingController _aramaController = TextEditingController();

  List<Oyuncu> _tumOyuncularYedek = [];
  List<Oyuncu> _filtrelenmisOyuncular = [];
  List<String> _sehirlerListesi = [];

  bool _aramaYapiliyorMu = false;
  bool _gosterPasifArsiv =
      false; // false: Aktifler, true: Pasifler/Arşivtekiler
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
    _sehirleriYukle();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
    });
    try {
      final liste = await Oyuncu.getAllWithStats();
      setState(() {
        _tumOyuncularYedek = liste;
        _listeFiltrele(_aramaController.text);
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint("Oyuncular yüklenirken hata: $e");
      setState(() {
        _yukleniyor = false;
      });
    }
  }

  Future<void> _sehirleriYukle() async {
    try {
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> maps = await db.query(
        'sehirler',
        orderBy: 'sehirAd ASC',
      );
      setState(() {
        _sehirlerListesi = List.generate(
          maps.length,
          (i) => maps[i]['sehirAd'].toString(),
        );
      });
    } catch (e) {
      debugPrint("Şehirler yüklenirken hata: $e");
    }
  }

  // 🎯 ANLIK ARAMA VE SEKME FİLTRELEME MOTORU
  void _listeFiltrele(String aramaKelimesi) {
    setState(() {
      final aramaKucuk = aramaKelimesi.toLowerCase().trim();

      // İlk olarak arama kutusuna göre eşleşen isim ve şehirleri buluyoruz
      List<Oyuncu> geciciListe = _tumOyuncularYedek.where((oyuncu) {
        final adEslesmesi = oyuncu.oyuncuAdSoyad.toLowerCase().contains(
          aramaKucuk,
        );
        final sehirEslesmesi = oyuncu.oyuncuSehir.toLowerCase().contains(
          aramaKucuk,
        );
        return adEslesmesi || sehirEslesmesi;
      }).toList();

      // Ardından isAktif bayrağına göre aktif veya pasif/arşiv sekmesine dağıtıyoruz
      if (_gosterPasifArsiv) {
        _filtrelenmisOyuncular = geciciListe
            .where((o) => o.isAktif == 0)
            .toList();
      } else {
        _filtrelenmisOyuncular = geciciListe
            .where((o) => o.isAktif == 1)
            .toList();
      }
    });
  }

  void _oyuncuFormuGoster({Oyuncu? oyuncu}) {
    if (oyuncu != null) {
      _adController.text = oyuncu.oyuncuAdSoyad;
      _sehirController.text = oyuncu.oyuncuSehir;
    } else {
      _adController.clear();
      _sehirController.text = _sehirlerListesi.isNotEmpty
          ? _sehirlerListesi.first
          : 'Istanbul';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                        : _sehirlerListesi.first,
                    decoration: const InputDecoration(
                      labelText: 'Şehir Seçin',
                      border: OutlineInputBorder(),
                    ),
                    items: _sehirlerListesi
                        .map(
                          (sehir) => DropdownMenuItem(
                            value: sehir,
                            child: Text(sehir),
                          ),
                        )
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
            onPressed: () async {
              if (_adController.text.trim().isEmpty) return;
              final navigator = Navigator.of(dialogContext);
              final db = await DatabaseHelper().database;

              final Map<String, dynamic> veri = {
                'oyuncuAdSoyad': _adController.text.trim(),
                'oyuncuSehir': _sehirController.text.trim(),
              };

              if (oyuncu == null) {
                veri['isAktif'] = 1;
                await db.insert('oyuncu', veri);
              } else {
                veri['isAktif'] = oyuncu.isAktif;
                await db.update(
                  'oyuncu',
                  veri,
                  where: 'oyuncuId = ?',
                  whereArgs: [oyuncu.oyuncuId],
                );
              }

              navigator.pop();
              _verileriYukle();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 📱 Akıllı Yön Algılayıcı (Taşmayı önleyen ve dikey/yatay modları ayıran filtre)
    final bool isYatay =
        MediaQuery.of(context).orientation == Orientation.landscape;

    Widget appBarBaslikAlani = _aramaYapiliyorMu
        ? TextField(
            controller: _aramaController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Oyuncu veya şehir ara...',
              hintStyle: TextStyle(color: Colors.white60),
              border: InputBorder.none,
            ),
            onChanged: (deger) => _listeFiltrele(deger),
          )
        : Text(
            _gosterPasifArsiv
                ? 'Pasif Oyuncular (Arşiv)'
                : 'Oyuncular Yönetimi',
          );

    return Scaffold(
      appBar: AppBar(
        title: appBarBaslikAlani,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_aramaYapiliyorMu ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_aramaYapiliyorMu) {
                  _aramaController.clear();
                  _listeFiltrele('');
                }
                _aramaYapiliyorMu = !_aramaYapiliyorMu;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _filtrelenmisOyuncular.isEmpty
                      ? const Center(
                          child: Text(
                            'Aranan kriterlere uygun oyuncu bulunamadı.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtrelenmisOyuncular.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (itemContext, index) {
                            final oyuncu = _filtrelenmisOyuncular[index];
                            // 📊 YARI ÇAP VE GÖLGE EFEKTLİ KART TASARIMI
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                onTap: () {
                                  if (!_gosterPasifArsiv) {
                                    _oyuncuFormuGoster(oyuncu: oyuncu);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: isYatay
                                      ? Row(
                                          children: [
                                            // 🎯 YATAY MOD 1. SÜTUN: Oyuncu Genel Bilgileri
                                            Expanded(
                                              flex: 4,
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor:
                                                        _gosterPasifArsiv
                                                        ? Colors
                                                              .blueGrey
                                                              .shade100
                                                        : Colors
                                                              .orange
                                                              .shade100,
                                                    child: Icon(
                                                      Icons.person,
                                                      color: _gosterPasifArsiv
                                                          ? Colors.blueGrey
                                                          : Colors.orange,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          oyuncu.oyuncuAdSoyad,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 17,
                                                            decoration:
                                                                _gosterPasifArsiv
                                                                ? TextDecoration
                                                                      .lineThrough
                                                                : null,
                                                            color:
                                                                _gosterPasifArsiv
                                                                ? Colors.grey
                                                                : Colors
                                                                      .black87,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.pin_drop,
                                                              size: 14,
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                "Şehir: ${oyuncu.oyuncuSehir}",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade700,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
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

                                            // 🎯 YATAY MOD 2. SÜTUN: İstatistik Rozet Paneli (Tam Merkez)
                                            Expanded(
                                              flex: 4,
                                              child: Center(
                                                child:
                                                    _istatistikKarnesiOlustur(
                                                      oyuncu,
                                                    ),
                                              ),
                                            ),

                                            // 🎯 YATAY MOD 3. SÜTUN: Devasa Yuvarlak Aksiyon Butonları (En Sağ)
                                            Expanded(
                                              flex: 3,
                                              child: _aksiyonButonlariniOlustur(
                                                context,
                                                oyuncu,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          // 🎯 DİKEY MOD: Taşmayı %100 önlemek için istatistik panelini ismin altına indiren akıllı şablon
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor:
                                                        _gosterPasifArsiv
                                                        ? Colors
                                                              .blueGrey
                                                              .shade100
                                                        : Colors
                                                              .orange
                                                              .shade100,
                                                    child: Icon(
                                                      Icons.person,
                                                      color: _gosterPasifArsiv
                                                          ? Colors.blueGrey
                                                          : Colors.orange,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          oyuncu.oyuncuAdSoyad,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                            decoration:
                                                                _gosterPasifArsiv
                                                                ? TextDecoration
                                                                      .lineThrough
                                                                : null,
                                                            color:
                                                                _gosterPasifArsiv
                                                                ? Colors.grey
                                                                : Colors
                                                                      .black87,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.pin_drop,
                                                              size: 14,
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                "Şehir: ${oyuncu.oyuncuSehir}",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade700,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        // 🎯 DİKEY MOD EMNİYETİ: Rozet alt satıra alınarak sağ barın sıkışması önlendi
                                                        _istatistikKarnesiOlustur(
                                                          oyuncu,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _aksiyonButonlariniOlustur(
                                              context,
                                              oyuncu,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // 📊 SEKMELİ ALT PANEL GRUBU (AKTİF / PASİF AYRIMI)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 90.0,
                    top: 12.0,
                    bottom: 16.0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _gosterPasifArsiv = !_gosterPasifArsiv;
                          _listeFiltrele(_aramaController.text);
                        });
                      },
                      icon: Icon(
                        _gosterPasifArsiv
                            ? Icons.group
                            : Icons.archive_outlined,
                        color: Colors.black87,
                      ),
                      label: Text(
                        _gosterPasifArsiv
                            ? "Aktif Oyunculara Dön"
                            : "Pasif Oyuncular (Arşiv)",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _oyuncuFormuGoster(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 🎯 MERKEZİ İSTATİSTİK ROZET TASARIM ŞABLONU
  Widget _istatistikKarnesiOlustur(Oyuncu oyuncu) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Maç: ${oyuncu.toplamOyun}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          const Text("|", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            "🏆 ${oyuncu.kazanilanOyun}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          const Text("|", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            "📉 ${oyuncu.kaybedilenOyun}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 DEVASE DOKUNMA ALANLI DAİRESEL AKSİYON BUTONLARI ŞABLONU
  Widget _aksiyonButonlariniOlustur(BuildContext context, Oyuncu oyuncu) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 📁 Arşivleme / Geri Yükleme Butonu (Soft Dairesel Kutu)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final db = await DatabaseHelper().database;
            await db.update(
              'oyuncu',
              {'isAktif': _gosterPasifArsiv ? 1 : 0},
              where: 'oyuncuId = ?',
              whereArgs: [oyuncu.oyuncuId],
            );
            _verileriYukle();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _gosterPasifArsiv
                      ? "👤 Oyuncu masaya geri döndü!"
                      : "📁 Oyuncu arşive kaldırıldı.",
                ),
                backgroundColor: _gosterPasifArsiv
                    ? Colors.green.shade800
                    : Colors.blueGrey.shade800,
              ),
            );
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _gosterPasifArsiv
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.blueGrey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _gosterPasifArsiv ? Icons.settings_backup_restore : Icons.archive,
              color: _gosterPasifArsiv ? Colors.green : Colors.blueGrey,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 🗑️ Kalıcı Silme Butonu (Soft Kırmızı Dairesel Kutu)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            bool? onay = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Oyuncuyu Kalıcı Sil'),
                content: Text(
                  '${oyuncu.oyuncuAdSoyad} isimli oyuncuyu tamamen silmek istiyor musunuz?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text(
                      'Kalıcı Sil',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
            if (onay == true) {
              final db = await DatabaseHelper().database;
              await db.delete(
                'oyuncu',
                where: 'oyuncuId = ?',
                whereArgs: [oyuncu.oyuncuId],
              );
              _verileriYukle();
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete, color: Colors.redAccent, size: 26),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _adController.dispose();
    _sehirController.dispose();
    _aramaController.dispose();
    super.dispose();
  }
} // 👈 'oyuncu_sayfasi.dart' dosyasını ve ana sınıfı hatasız kapatan en son süslü parantez
