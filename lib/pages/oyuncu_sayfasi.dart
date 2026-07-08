import 'package:flutter/material.dart';
import 'package:yaz_boz/helper/database_helper.dart';

// İstatistik kolonları entegre edilmiş güncel Oyuncu Modeli
class Oyuncu {
  final int? oyuncuId;
  final String oyuncuAdSoyad;
  final String oyuncuSehir;

  // 📊 YENİ EKLENEN CANLI İSTATİSTİK DEĞİŞKENLERİ
  final int toplamOyun;
  final int kazanilanOyun;
  final int kaybedilenOyun;

  Oyuncu({
    this.oyuncuId,
    required this.oyuncuAdSoyad,
    required this.oyuncuSehir,
    this.toplamOyun = 0,
    this.kazanilanOyun = 0,
    this.kaybedilenOyun = 0,
  });

  factory Oyuncu.fromMap(Map<String, dynamic> map) {
    return Oyuncu(
      oyuncuId: map['oyuncuId'],
      oyuncuAdSoyad: map['oyuncuAdSoyad'] ?? '',
      oyuncuSehir: map['oyuncuSehir'] ?? '',
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
    };
  }

  // 🚀 GELİŞMİŞ SQL MOTORU: Oyuncunun tüm kariyer istatistiklerini alt sorgularla tek seferde hesaplar
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

  late Future<List<Oyuncu>> _oyuncularFuture;
  List<String> _sehirlerListesi = [];

  @override
  void initState() {
    super.initState();
    _verileriYenile();
    _sehirleriYukle();
  }

  void _verileriYenile() {
    setState(() {
      _oyuncularFuture =
          Oyuncu.getAllWithStats(); // İstatistikli veriyi tetikler
    });
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

              final veri = {
                'oyuncuAdSoyad': _adController.text.trim(),
                'oyuncuSehir': _sehirController.text.trim(),
              };

              if (oyuncu == null) {
                await db.insert('oyuncular', veri);
              } else {
                await db.update(
                  'oyuncular',
                  veri,
                  where: 'oyuncuId = ?',
                  whereArgs: [oyuncu.oyuncuId],
                );
              }

              navigator.pop();
              _verileriYenile();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyuncular Yönetimi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Oyuncu>>(
        future: _oyuncularFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Henüz hiç oyuncu eklenmemiş.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final oyuncular = snapshot.data!;

          return ListView.builder(
            itemCount: oyuncular.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (itemContext, index) {
              final oyuncu = oyuncular[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      oyuncu.oyuncuAdSoyad,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // 🎯 TAZELENEN ALT BİLGİ ALANI: Şehir bilgisinin hemen altına şık bir maç karnesi barı ekler
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.pin_drop,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Şehir: ${oyuncu.oyuncuSehir}",
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 📊 MAÇ KARNESİ PANELİ
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Maç: ${oyuncu.toplamOyun}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "|",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "🏆 ${oyuncu.kazanilanOyun}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "|",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "📉 ${oyuncu.kaybedilenOyun}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.orange,
                            size: 22,
                          ),
                          onPressed: () => _oyuncuFormuGoster(oyuncu: oyuncu),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          onPressed: () async {
                            bool? onay = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Oyuncuyu Sil'),
                                content: Text(
                                  '${oyuncu.oyuncuAdSoyad} isimli oyuncuyu silmek istediğinize emin misiniz?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('İptal'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text(
                                      'Sil',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (onay == true) {
                              final db = await DatabaseHelper().database;
                              await db.delete(
                                'oyuncular',
                                where: 'oyuncuId = ?',
                                whereArgs: [oyuncu.oyuncuId],
                              );
                              _verileriYenile();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _oyuncuFormuGoster(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _adController.dispose();
    _sehirController.dispose();
    super.dispose();
  }
}
