import 'package:flutter/material.dart';
import 'package:yaz_boz/helper/database_helper.dart';

// Turnuva veri yapısı modeli (Veritabanı kolonlarınızla tam senkronize)
class Turnuva {
  final int? turId;
  final String turTarih;
  final String? turKazanan;
  final String? turKaybeden;
  final int tursonuc; // 1: Bitti, 0: Devam ediyor

  Turnuva({
    this.turId,
    required this.turTarih,
    this.turKazanan,
    this.turKaybeden,
    required this.tursonuc,
  });

  factory Turnuva.fromMap(Map<String, dynamic> map) {
    return Turnuva(
      turId: map['turId'],
      turTarih: map['turTarih'] ?? '',
      turKazanan: map['turKazanan'],
      turKaybeden: map['turKaybeden'],
      tursonuc: map['tursonuc'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (turId != null) 'turId': turId,
      'turTarih': turTarih,
      'turKazanan': turKazanan,
      'turKaybeden': turKaybeden,
      'tursonuc': tursonuc,
    };
  }
}

class TurnuvaSayfasi extends StatefulWidget {
  const TurnuvaSayfasi({super.key});

  @override
  State<TurnuvaSayfasi> createState() => _TurnuvaSayfasiState();
}

class _TurnuvaSayfasiState extends State<TurnuvaSayfasi> {
  final TextEditingController _tarihController = TextEditingController();
  final TextEditingController _kazananController = TextEditingController();
  final TextEditingController _kaybedenController = TextEditingController();

  late Future<List<Turnuva>> _turnuvalarFuture;
  bool _gosterArsiv = false; // Aktif/Arşiv görünüm filtresi

  @override
  void initState() {
    super.initState();
    _verileriYenile();
  }

  void _verileriYenile() {
    setState(() {
      _turnuvalarFuture = _tumTurnuvalariGetir();
    });
  }

  Future<List<Turnuva>> _tumTurnuvalariGetir() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'turnuva',
      orderBy: 'turId DESC',
    );
    return List.generate(maps.length, (i) => Turnuva.fromMap(maps[i]));
  }

  void _turnuvaFormuGoster({Turnuva? turnuva}) {
    if (turnuva != null) {
      _tarihController.text = turnuva.turTarih;
      _kazananController.text = turnuva.turKazanan ?? '';
      _kaybedenController.text = turnuva.turKaybeden ?? '';
    } else {
      _tarihController.text = DateTime.now().toString().substring(0, 10);
      _kazananController.clear();
      _kaybedenController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          turnuva == null ? 'Yeni Turnuva Ekle' : 'Turnuvayı Düzenle',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tarihController,
              decoration: const InputDecoration(
                labelText: 'Turnuva Tarihi / Adı',
                border: OutlineInputBorder(),
              ),
            ),
            if (turnuva != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _kazananController,
                decoration: const InputDecoration(
                  labelText: 'Turnuva Kazananı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _kaybedenController,
                decoration: const InputDecoration(
                  labelText: 'Turnuva Sonuncusu',
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
              final navigator = Navigator.of(dialogContext);
              final db = await DatabaseHelper().database;

              if (turnuva == null) {
                // 🚀 HATA ÇÖZÜMÜ: En son oluşturulan aktif sezonun ID'sini otomatik sorguluyoruz
                final List<Map<String, dynamic>> enSonSezonRes = await db.query(
                  'sezonlar',
                  orderBy: 'sezonId DESC',
                  limit: 1,
                );

                // Eğer veritabanında hiç sezon yoksa kilitlenmeyi önlemek için varsayılan 1 atıyoruz
                int aktifSezonId = enSonSezonRes.isNotEmpty
                    ? enSonSezonRes.first['sezonId'] as int
                    : 1;

                // 🎯 KRİTİK ADIM: 'sezonId' veritabanı şemasının zorunlu kuralına uygun olarak ekleniyor
                final yeniTurnuva = {
                  'sezonId':
                      aktifSezonId, // 👈 NOT NULL hatasını çözen zorunlu kolon
                  'turTarih': _tarihController.text.trim(),
                  'turKazanan': null,
                  'turKaybeden': null,
                  'tursonuc': 0,
                };

                await db.insert('turnuva', yeniTurnuva);
              } else {
                // Düzenleme (Edit) modu alanı aynen kalıyor
                final guncelTurnuva = Turnuva(
                  turId: turnuva.turId,
                  turTarih: _tarihController.text.trim(),
                  turKazanan: _kazananController.text.trim().isEmpty
                      ? null
                      : _kazananController.text.trim(),
                  turKaybeden: _kaybedenController.text.trim().isEmpty
                      ? null
                      : _kaybedenController.text.trim(),
                  tursonuc: _kazananController.text.trim().isNotEmpty ? 1 : 0,
                );
                await db.update(
                  'turnuva',
                  guncelTurnuva.toMap(),
                  where: 'turId = ?',
                  whereArgs: [turnuva.turId],
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

  // 🚀 ASLA BOŞ KALMAYAN GELİŞMİŞ İSTATİSTİK MOTORU
  Future<Map<String, String?>> _turnuvaIstatistikleriniHesapla(
    int turnuvaId,
  ) async {
    final db = await DatabaseHelper().database;

    // 1. En çok oyun kazanan oyuncuyu buluyoruz
    final List<Map<String, dynamic>> kazananRes = await db.rawQuery(
      '''
      SELECT oyunKazanan, COUNT(oyunKazanan) as adet 
      FROM oyunlar 
      WHERE turId = ? AND oyunKazanan IS NOT NULL AND oyunKazanan != ''
      GROUP BY oyunKazanan 
      ORDER BY adet DESC 
      LIMIT 1
    ''',
      [turnuvaId],
    );

    // 2. En çok oyun kaybeden oyuncuyu buluyoruz
    final List<Map<String, dynamic>> kaybedenRes = await db.rawQuery(
      '''
      SELECT oyunKaybeden, COUNT(oyunKaybeden) as adet 
      FROM oyunlar 
      WHERE turId = ? AND oyunKaybeden IS NOT NULL AND oyunKaybeden != ''
      GROUP BY oyunKaybeden 
      ORDER BY adet DESC 
      LIMIT 1
    ''',
      [turnuvaId],
    );

    String? otomatikKazanan;
    if (kazananRes.isNotEmpty && kazananRes.first['oyunKazanan'] != null) {
      otomatikKazanan = kazananRes.first['oyunKazanan'].toString();
    }

    String? otomatikKaybeden;
    if (kaybedenRes.isNotEmpty && kaybedenRes.first['oyunKaybeden'] != null) {
      otomatikKaybeden = kaybedenRes.first['oyunKaybeden'].toString();
    }

    // 🎯 YEDEK PLAN MOTORU: Eğer üstteki oyunlar tablosunda kaybeden kolonları doldurulmadıysa,
    // turnuvadaki tüm ellerin (eller tablosunun) puanlarını toplar ve en çok ceza puanı biriktiren sonuncuyu bulur.
    if (otomatikKaybeden == null || otomatikKaybeden.isEmpty) {
      final List<Map<String, dynamic>> yedekKaybedenRes = await db.rawQuery(
        '''
        SELECT Oyuncu1, SUM(elSkor + IFNULL(gosterge, 0)) as toplamCeza
        FROM eller 
        WHERE oyunId IN (SELECT oyunId FROM oyunlar WHERE turId = ?)
        GROUP BY Oyuncu1
        ORDER BY toplamCeza DESC
        LIMIT 1
      ''',
        [turnuvaId],
      );

      if (yedekKaybedenRes.isNotEmpty &&
          yedekKaybedenRes.first['Oyuncu1'] != null) {
        otomatikKaybeden = yedekKaybedenRes.first['Oyuncu1'].toString();
      }
    }

    // 🎯 YEDEK PLAN KAZANAN (Önlem amaçlı): Kazanan da boş kalırsa en az puan alanı bulur
    if (otomatikKazanan == null || otomatikKazanan.isEmpty) {
      final List<Map<String, dynamic>> yedekKazananRes = await db.rawQuery(
        '''
        SELECT Oyuncu1, SUM(elSkor + IFNULL(gosterge, 0)) as toplamCeza
        FROM eller 
        WHERE oyunId IN (SELECT oyunId FROM oyunlar WHERE turId = ?)
        GROUP BY Oyuncu1
        ORDER BY toplamCeza ASC
        LIMIT 1
      ''',
        [turnuvaId],
      );

      if (yedekKazananRes.isNotEmpty &&
          yedekKazananRes.first['Oyuncu1'] != null) {
        otomatikKazanan = yedekKazananRes.first['Oyuncu1'].toString();
      }
    }

    return {'enCokKazanan': otomatikKazanan, 'enCokKaybeden': otomatikKaybeden};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuçlanan Turnuvalar (Arşiv)' : 'Aktif Turnuvalar',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Turnuva>>(
              future: _turnuvalarFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz hiç turnuva tanımlanmamış.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Aktif/Arşiv filtreleme motoru (Linter standartlarına tam uyumlu)
                final tumTurnuvalar = snapshot.data!;
                final turnuvalarListesi = tumTurnuvalar.where((t) {
                  return _gosterArsiv
                      ? t.turKazanan != null
                      : t.turKazanan == null;
                }).toList();

                if (turnuvalarListesi.isEmpty) {
                  return Center(
                    child: Text(
                      _gosterArsiv
                          ? 'Arşivde hiç turnuva bulunmuyor.'
                          : 'Aktif (devam eden) turnuva bulunmuyor.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: turnuvalarListesi.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (itemContext, index) {
                    final tekTurnuva = turnuvalarListesi[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          Icons.emoji_events,
                          color: _gosterArsiv
                              ? Colors.blueGrey
                              : Colors.amber.shade700,
                          size: 32,
                        ),
                        title: Text(
                          "Turnuva #${tekTurnuva.turId} - ${tekTurnuva.turTarih}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: tekTurnuva.turKazanan != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "🏆 Kazanan: ${tekTurnuva.turKazanan}  |  📉 Sonuncu: ${tekTurnuva.turKaybeden}",
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "🔥 Turnuva devam ediyor...",
                                  style: TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🚀 GÜNCELLEME: TURNUVA SONLANDIRMA BUTONU (OTOMATİK OYUNCU GELECEK ŞEKİLDE YENİLENDİ)
                            if (tekTurnuva.turKazanan == null)
                              IconButton(
                                icon: const Icon(
                                  Icons.gavel,
                                  color: Colors.teal,
                                ),
                                tooltip: 'Turnuvayı Sonlandır',
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );

                                  // 🎯 KRİTİK ADIM: Pop-up açılmadan önce arka planda en çok kazanan/kaybeden hesaplanır
                                  final istatistikler =
                                      await _turnuvaIstatistikleriniHesapla(
                                        tekTurnuva.turId!,
                                      );

                                  if (!context.mounted) return;

                                  Map<String, String>?
                                  sonuc = await showDialog<Map<String, String>>(
                                    context: context,
                                    builder: (dialogContext) {
                                      final TextEditingController
                                      tempKazananCtrl = TextEditingController(
                                        text:
                                            istatistikler['enCokKazanan'] ??
                                            '', // En çok kazanan otomatik doldurulur
                                      );
                                      final TextEditingController
                                      tempKaybedenCtrl = TextEditingController(
                                        text:
                                            istatistikler['enCokKaybeden'] ??
                                            '', // En çok kaybeden otomatik doldurulur
                                      );

                                      return AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.stars,
                                              color: Colors.amber,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Turnuvayı Bitir'),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: tempKazananCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Turnuva Kazananı',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: tempKaybedenCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Turnuva Sonuncusu',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ],
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
                                              if (tempKazananCtrl.text
                                                      .trim()
                                                      .isNotEmpty &&
                                                  tempKaybedenCtrl.text
                                                      .trim()
                                                      .isNotEmpty) {
                                                Navigator.pop(dialogContext, {
                                                  'kazanan': tempKazananCtrl
                                                      .text
                                                      .trim(),
                                                  'kaybeden': tempKaybedenCtrl
                                                      .text
                                                      .trim(),
                                                });
                                              }
                                            },
                                            child: const Text('Bitir'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (sonuc != null) {
                                    final db = await DatabaseHelper().database;
                                    await db.update(
                                      'turnuva',
                                      {
                                        'turKazanan': sonuc['kazanan'],
                                        'turKaybeden': sonuc['kaybeden'],
                                        'tursonuc':
                                            1, // Turnuva pasife (arşive) çekilir
                                      },
                                      where: 'turId = ?',
                                      whereArgs: [tekTurnuva.turId],
                                    );

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "🎉 Turnuva #${tekTurnuva.turId} Sonuçlandı!\n🏆 Kazanan: ${sonuc['kazanan']} | 📉 Sonuncu: ${sonuc['kaybeden']}",
                                        ),
                                        backgroundColor: Colors.teal.shade800,
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
                                  _turnuvaFormuGoster(turnuva: tekTurnuva),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                bool? onay = await showDialog<bool>(
                                  context: itemContext,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Turnuvayı Sil'),
                                    content: const Text(
                                      'Bu turnuvayı sildiğinizde turnuvaya bağlı tüm kayıtlar kaybolacaktır. Onaylıyor musunuz?',
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
                                    'turnuva',
                                    where: 'turId = ?',
                                    whereArgs: [tekTurnuva.turId],
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
                      ? "Aktif Turnuvalara Dön"
                      : "Eski Turnuvalar (Arşiv)",
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
        onPressed: () => _turnuvaFormuGoster(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _tarihController.dispose();
    _kazananController.dispose();
    _kaybedenController.dispose();
    super.dispose();
  }
}
