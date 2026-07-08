import 'package:flutter/material.dart';
import 'package:yaz_boz/helper/database_helper.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // 🚀 SADECE AKTİF SEZONLARI KONTROL EDEN MOTOR
  Future<bool> _aktifSezonVarMi() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('sezonlar');
    final aktifSezonlar = maps
        .where((s) => s['sezonSampiyon'] == null)
        .toList();
    return aktifSezonlar.isNotEmpty;
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
                final List<Map<String, dynamic>> enSonSezonRes = await db.query(
                  'sezonlar',
                  orderBy: 'sezonId DESC',
                  limit: 1,
                );

                int aktifSezonId = enSonSezonRes.isNotEmpty
                    ? enSonSezonRes.first['sezonId'] as int
                    : 1;

                final yeniTurnuva = {
                  'sezonId': aktifSezonId,
                  'turTarih': _tarihController.text.trim(),
                  'turKazanan': null,
                  'turKaybeden': null,
                  'tursonuc': 0,
                };

                await db.insert('turnuva', yeniTurnuva);
              } else {
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

  // 🚀 ASLA BOŞ KALMAYAN TURNUVA SONU HESAPLAMA MOTORU
  Future<Map<String, String?>> _turnuvaIstatistikleriniHesapla(
    int turnuvaId,
  ) async {
    final db = await DatabaseHelper().database;

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

  // Hero tasarımı için buton yardımcı bileşeni
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
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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

                // 📊 1. GÖRÜNÜM: ESKİ TURNUVALAR (ARŞİV) MODUNDA LİSTE HALİNDE GÖSTERİLİR
                if (_gosterArsiv) {
                  return ListView.builder(
                    itemCount: turnuvalarListesi.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (itemContext, index) {
                      final tekTurnuva = turnuvalarListesi[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(
                            Icons.emoji_events,
                            color: Colors.blueGrey,
                            size: 32,
                          ),
                          title: Text(
                            "Turnuva #${tekTurnuva.turId} - ${tekTurnuva.turTarih}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "🏆 Kazanan: ${tekTurnuva.turKazanan} | 📉 Sonuncu: ${tekTurnuva.turKaybeden}",
                              style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                ),
                                onPressed: () =>
                                    _turnuvaFormuGoster(turnuva: tekTurnuva),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  bool? onay = await showDialog<bool>(
                                    context: itemContext,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Turnuvayı Sil'),
                                      content: const Text(
                                        'Bu turnuvayı sildiğinizde turnuvaya ait tüm kayıtlar kaybolacaktır. Onaylıyor musunuz?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: const Text('İptal'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
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
                }

                // 🚀 2. GÖRÜNÜM: AKTİF TURNUVA MODUNDA EKRANIN DEVASAL 2/3 ALANINI KAPLAYAN HERO KART TASARIMI
                final tekTurnuva = turnuvalarListesi
                    .first; // Eş zamanlı tek aktif turnuva gelebilir
                final double ekranYuksekligi = MediaQuery.of(
                  context,
                ).size.height;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: ekranYuksekligi * 0.55,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade600,
                              Colors.indigo.shade900,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Üst Başlık ve İkon Alanı
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Turnuva #${tekTurnuva.turId}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tekTurnuva.turTarih,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      Icons.emoji_events,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                              // Orta Canlı Bilgilendirme ve Efekt Alanı
                              const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: Colors.orangeAccent,
                                    size: 54,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "TURNUVA DEVAM EDİYOR",
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Masada kıyasıya rekabet tüm hızıyla sürüyor.\nSkorları oyunlar listesinden takip edebilirsiniz.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                              // Alt İşlem Butonları Barı
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _heroAksiyonButonu(
                                      icon: Icons.share,
                                      renk: Colors.cyanAccent,
                                      etiket: "Paylaş",
                                      onTap: () async {
                                        String paylasimMetni =
                                            "🔥 YAZ BOZ TURNUVASI DEVAM EDİYOR 🔥\n"
                                            "📅 Tarih: ${tekTurnuva.turTarih}\n"
                                            "🆔 Turnuva No: #${tekTurnuva.turId}\n"
                                            "-----------------------------------\n"
                                            "Masada rekabet tam gaz sürüyor! Güncel skorlar için uygulamayı takip edin. ⚡";
                                        final Uri whatsappUrl = Uri.parse(
                                          "whatsapp://send?text=${Uri.encodeComponent(paylasimMetni)}",
                                        );
                                        if (await canLaunchUrl(whatsappUrl)) {
                                          await launchUrl(
                                            whatsappUrl,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } else {
                                          final Uri webUrl = Uri.parse(
                                            "whatsapp.com{Uri.encodeComponent(paylasimMetni)}",
                                          );
                                          await launchUrl(
                                            webUrl,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                    ),
                                    _heroAksiyonButonu(
                                      icon: Icons.gavel,
                                      renk: Colors.amber,
                                      etiket: "Sonlandır",
                                      onTap: () async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        final sonuclar =
                                            await _turnuvaIstatistikleriniHesapla(
                                              tekTurnuva.turId!,
                                            );
                                        if (!context.mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (dialogContext) {
                                            final TextEditingController
                                            tempKazananCtrl =
                                                TextEditingController(
                                                  text:
                                                      sonuclar['enCokKazanan'] ??
                                                      '',
                                                );
                                            final TextEditingController
                                            tempKaybedenCtrl =
                                                TextEditingController(
                                                  text:
                                                      sonuclar['enCokKaybeden'] ??
                                                      '',
                                                );
                                            return AlertDialog(
                                              title: const Row(
                                                children: [
                                                  Icon(
                                                    Icons.gavel,
                                                    color: Colors.amber,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Turnuvayı Sonlandır'),
                                                ],
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(
                                                    controller: tempKazananCtrl,
                                                    decoration: const InputDecoration(
                                                      labelText:
                                                          'Turnuva Şampiyonu Kim?',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextField(
                                                    controller:
                                                        tempKaybedenCtrl,
                                                    decoration: const InputDecoration(
                                                      labelText:
                                                          'Turnuva Sonuncusu Kim?',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                      ),
                                                  child: const Text('İptal'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    if (tempKazananCtrl.text
                                                            .trim()
                                                            .isNotEmpty &&
                                                        tempKaybedenCtrl.text
                                                            .trim()
                                                            .isNotEmpty) {
                                                      final db =
                                                          await DatabaseHelper()
                                                              .database;
                                                      await db.update(
                                                        'turnuva',
                                                        {
                                                          'turKazanan':
                                                              tempKazananCtrl
                                                                  .text
                                                                  .trim(),
                                                          'turKaybeden':
                                                              tempKaybedenCtrl
                                                                  .text
                                                                  .trim(),
                                                          'tursonuc': 1,
                                                        },
                                                        where: 'turId = ?',
                                                        whereArgs: [
                                                          tekTurnuva.turId,
                                                        ],
                                                      );
                                                      if (!dialogContext
                                                          .mounted) {
                                                        return;
                                                      }
                                                      Navigator.pop(
                                                        dialogContext,
                                                      );
                                                      messenger.showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            "🏆 Turnuva #${tekTurnuva.turId} Sonlandırıldı! Şampiyon: ${tempKazananCtrl.text.trim()}",
                                                          ),
                                                          backgroundColor:
                                                              Colors
                                                                  .indigo
                                                                  .shade800,
                                                        ),
                                                      );
                                                      _verileriYenile();
                                                    }
                                                  },
                                                  child: const Text(
                                                    'Sonlandır',
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    _heroAksiyonButonu(
                                      icon: Icons.edit,
                                      renk: Colors.white,
                                      etiket: "Düzenle",
                                      onTap: () => _turnuvaFormuGoster(
                                        turnuva: tekTurnuva,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Alt panel görünüm değiştirme butonu
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
      // Eş zamanlı tek aktif turnuva kontrol bariyerli buton (Linter / Async emniyetli)
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);

          final bool sezonKontrol = await _aktifSezonVarMi();
          if (!context.mounted) return;

          if (!sezonKontrol) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  "⚠️ Sistemde devam eden aktif bir sezon bulunmuyor! Yeni turnuva açabilmek için önce 'Sezonlar' sayfasından yeni bir sezon başlatmalısınız.",
                ),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }

          final db = await DatabaseHelper().database;
          final List<Map<String, dynamic>> aktifTurnuvalar = await db.query(
            'turnuva',
            where: 'turKazanan IS NULL',
          );

          if (!context.mounted) return;

          if (aktifTurnuvalar.isNotEmpty) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  "⚠️ Masada zaten devam eden AKTİF BİR TURNUVA bulunuyor! Yenisini açmak için önce mevcut turnuvayı bitirmelisiniz.",
                ),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }

          _turnuvaFormuGoster();
        },
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
