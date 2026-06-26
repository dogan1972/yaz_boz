import 'package:flutter/material.dart';
import 'package:yaz_boz/helper/database_helper.dart';
import 'package:yaz_boz/pages/sezon_detay_sayfasi.dart';

// Sezon veri yapısı modeli (Projenizdeki değişken isimleriyle senkronize edilmiştir)
class Sezon {
  final int? sezonId;
  final String sezonTarih;
  final String? sezonSampiyon;

  Sezon({this.sezonId, required this.sezonTarih, this.sezonSampiyon});

  factory Sezon.fromMap(Map<String, dynamic> map) {
    return Sezon(
      sezonId: map['sezonId'],
      sezonTarih: map['sezonTarih'] ?? '',
      sezonSampiyon: map['sezonSampiyon'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (sezonId != null) 'sezonId': sezonId,
      'sezonTarih': sezonTarih,
      'sezonSampiyon': sezonSampiyon,
    };
  }
}

class SezonlarSayfasi extends StatefulWidget {
  const SezonlarSayfasi({super.key});

  @override
  State<SezonlarSayfasi> createState() => _SezonlarSayfasiState();
}

class _SezonlarSayfasiState extends State<SezonlarSayfasi> {
  final TextEditingController _tarihController = TextEditingController();
  final TextEditingController _sampiyonController = TextEditingController();

  late Future<List<Sezon>> _sezonlarFuture;
  bool _gosterArsiv = false; // Aktif ve pasif sezon ayrımı için filtre bayrağı

  @override
  void initState() {
    super.initState();
    _verileriYenile();
  }

  void _verileriYenile() {
    setState(() {
      _sezonlarFuture = _tumSezonlariGetir();
    });
  }

  Future<List<Sezon>> _tumSezonlariGetir() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sezonlar',
      orderBy: 'sezonId DESC',
    );
    return List.generate(maps.length, (i) => Sezon.fromMap(maps[i]));
  }

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
        title: Text(sezon == null ? 'Yeni Sezon Ekle' : 'Sezonu Duzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tarihController,
              decoration: const InputDecoration(
                labelText: 'Sezon Tarihi / Adi',
                border: OutlineInputBorder(),
              ),
            ),
            if (sezon != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _sampiyonController,
                decoration: const InputDecoration(
                  labelText: 'Sezon Sampiyonu',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_tarihController.text.trim().isEmpty) return;
              final navigator = Navigator.of(dialogContext);
              final db = await DatabaseHelper().database;

              if (sezon == null) {
                final yeniSezon = Sezon(
                  sezonTarih: _tarihController.text.trim(),
                );
                await db.insert('sezonlar', yeniSezon.toMap());
              } else {
                final guncelSezon = Sezon(
                  sezonId: sezon.sezonId,
                  sezonTarih: _tarihController.text.trim(),
                  sezonSampiyon: _sampiyonController.text.trim().isEmpty
                      ? null
                      : _sampiyonController.text.trim(),
                );
                await db.update(
                  'sezonlar',
                  guncelSezon.toMap(),
                  where: 'sezonId = ?',
                  whereArgs: [sezon.sezonId],
                );
              }

              if (!dialogContext.mounted) return;
              navigator.pop();
              _verileriYenile();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // 🚀 SEZONDA EN ÇOK OYUN KAZANAN OYUNCUYU BULAN MATEMATİK MOTORU
  Future<String?> _sezonIstatistikleriniHesapla(int sezonId) async {
    final db = await DatabaseHelper().database;

    // Sezona bağlı turnuvalardaki oyunlardan en çok kazanan (oyunKazanan) oyuncuyu buluyoruz
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT oyunKazanan, COUNT(oyunKazanan) as adet 
      FROM oyunlar 
      WHERE turId IN (SELECT turId FROM turnuva WHERE turId IS NOT NULL) 
        AND oyunKazanan IS NOT NULL 
        AND oyunKazanan != ''
      GROUP BY oyunKazanan 
      ORDER BY adet DESC 
      LIMIT 1
    ''', []);

    if (res.isNotEmpty && res.first['oyunKazanan'] != null) {
      return res.first['oyunKazanan'].toString();
    }

    // Yedek Plan: Eğer oyunlar tablosunda kazanan yoksa, eller tablosundan en başarılı (en az puanlı) olanı arar
    final List<Map<String, dynamic>> yedekRes = await db.rawQuery('''
      SELECT Oyuncu1, SUM(elSkor + IFNULL(gosterge, 0)) as toplamCeza
      FROM eller 
      GROUP BY Oyuncu1
      ORDER BY toplamCeza ASC
      LIMIT 1
    ''', []);

    if (yedekRes.isNotEmpty && yedekRes.first['Oyuncu1'] != null) {
      return yedekRes.first['Oyuncu1'].toString();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuclanan Sezonlar (Arsiv)' : 'Aktif Sezonlar',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Sezon>>(
              future: _sezonlarFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henuz hic sezon tanimlanmamis.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // 🚀 GÜNCELLEME: 'Sezonlar' ismi küçük harfle 'sezonlarListesi' yapıldı
                final tumSezonlar = snapshot.data!;
                final sezonlarListesi = tumSezonlar.where((s) {
                  return _gosterArsiv
                      ? s.sezonSampiyon != null
                      : s.sezonSampiyon == null;
                }).toList();

                if (sezonlarListesi.isEmpty) {
                  return Center(
                    child: Text(
                      _gosterArsiv
                          ? 'Arsivde hic sezon bulunmuyor.'
                          : 'Aktif (devam eden) sezon bulunmuyor.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: sezonlarListesi.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (itemContext, index) {
                    // 🚀 GÜNCELLEME: 'Sezon' ismi küçük harfle 'tekSezon' yapıldı
                    final tekSezon = sezonlarListesi[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SezonDetaySayfasi(
                                sezonId: tekSezon.sezonId!,
                                sezonAdi: "Sezon #${tekSezon.sezonId}",
                              ),
                            ),
                          );
                        },

                        leading: Icon(
                          Icons.calendar_month,
                          color: _gosterArsiv ? Colors.blueGrey : Colors.orange,
                          size: 32,
                        ),
                        title: Text(
                          "Sezon #${tekSezon.sezonId} - ${tekSezon.sezonTarih}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: tekSezon.sezonSampiyon != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "🏆 Sezon Şampiyonu: ${tekSezon.sezonSampiyon}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "⚡ Sezon devam ediyor...",
                                  style: TextStyle(color: Colors.blueGrey),
                                ),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🚀 GÜNCELLEME: SEZON SONLANDIRMA BUTONU (OTOMATİK ŞAMPİYON GELECEK ŞEKİLDE YENİLENDİ)
                            if (tekSezon.sezonSampiyon == null)
                              IconButton(
                                icon: const Icon(
                                  Icons.gavel,
                                  color: Colors.indigo,
                                ),
                                tooltip: 'Sezonu Sonlandır',
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );

                                  // Pop-up açılmadan önce sezonda en çok kazanan oyuncu otomatik hesaplanır
                                  final otomatikSampiyon =
                                      await _sezonIstatistikleriniHesapla(
                                        tekSezon.sezonId!,
                                      );

                                  if (!context.mounted) return;

                                  String?
                                  secilenSampiyon = await showDialog<String>(
                                    context: context,
                                    builder: (dialogContext) {
                                      final TextEditingController
                                      tempSampiyonCtrl = TextEditingController(
                                        text:
                                            otomatikSampiyon ??
                                            '', // 🎯 Hesaplanan şampiyon otomatik yazılır
                                      );
                                      return AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.emoji_events,
                                              color: Colors.amber,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Sezonu Sonlandır'),
                                          ],
                                        ),
                                        content: TextField(
                                          controller: tempSampiyonCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Sezon Şampiyonu Kim?',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              null,
                                            ),
                                            child: const Text('İptal'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              if (tempSampiyonCtrl.text
                                                  .trim()
                                                  .isNotEmpty) {
                                                Navigator.pop(
                                                  dialogContext,
                                                  tempSampiyonCtrl.text.trim(),
                                                );
                                              }
                                            },
                                            child: const Text('Sonlandır'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (secilenSampiyon != null) {
                                    final db = await DatabaseHelper().database;
                                    await db.update(
                                      'sezonlar',
                                      {'sezonSampiyon': secilenSampiyon},
                                      where: 'sezonId = ?',
                                      whereArgs: [tekSezon.sezonId],
                                    );

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "🏆 Sezon #${tekSezon.sezonId} Sonlandırıldı! Şampiyon: $secilenSampiyon",
                                        ),
                                        backgroundColor: Colors.indigo.shade800,
                                      ),
                                    );
                                    _verileriYenile();
                                  }
                                },
                              ),

                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () =>
                                  _sezonFormuGoster(sezon: tekSezon),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                bool? onay = await showDialog<bool>(
                                  context: itemContext,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Sezonu Sil'),
                                    content: const Text(
                                      'Bu sezonu sildiğinizde sezona ait tüm kayıtlar kaybolacaktır. Onaylıyor musunuz?',
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
                                    'sezonlar',
                                    where: 'sezonId = ?',
                                    whereArgs: [tekSezon.sezonId],
                                  );
                                  _verileriYenile();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

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
                    _gosterArsiv = !_gosterArsiv;
                  });
                },
                icon: Icon(
                  _gosterArsiv ? Icons.play_circle_outline : Icons.history,
                  color: Colors.black87,
                ),
                label: Text(
                  _gosterArsiv
                      ? "Aktif Sezonlara Dön"
                      : "Eski Sezonlar (Arsiv)",
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
        onPressed: () => _sezonFormuGoster(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
