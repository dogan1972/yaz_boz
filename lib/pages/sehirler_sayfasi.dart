import 'package:flutter/material.dart';
import 'package:yaz_boz/helper/database_helper.dart';

// 🚀 ÇÖZÜM: Çakışmaları önlemek için projenizin orijinal şehir modelini ana kaynak alıyoruz
import 'package:yaz_boz/models/sehirler_model.dart';

class SehirlerSayfasi extends StatefulWidget {
  const SehirlerSayfasi({super.key});

  @override
  State<SehirlerSayfasi> createState() => _SehirlerSayfasiState();
}

class _SehirlerSayfasiState extends State<SehirlerSayfasi> {
  final TextEditingController _sehirController = TextEditingController();
  late Future<List<Sehir>> _sehirlerFuture;

  // 🎯 AKORDEON HAFIZA ANAHTARI: Hangi şehir kartının açık olduğunu ID bazlı hafızada tutar
  int? _acikSehirId;

  @override
  void initState() {
    super.initState();
    _verileriYenile();
  }

  void _verileriYenile() {
    setState(() {
      _sehirlerFuture = _sehirIstatistikleriniGetir();
    });
  }

  // 🚀 AKTİF OYUNCU VE SADECE TURNUVA ŞAMPİYONLUĞU ODAKLI JOKERLİ SQL MOTORU
  Future<List<Sehir>> _sehirIstatistikleriniGetir() async {
    final db = await DatabaseHelper().database;

    // isAktif = 1 filtresi eklenerek sadece masadaki aktif oyuncular kulvara dahil edildi
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        s.*,
        (
          SELECT COUNT(*) 
          FROM oyuncu 
          WHERE isAktif = 1 
            AND (LOWER(oyuncuSehir) LIKE '%' || LOWER(s.sehirAd) || '%'
                 OR LOWER(s.sehirAd) LIKE '%' || LOWER(oyuncuSehir) || '%')
        ) as toplamOyuncu,
        (
          SELECT COUNT(*) 
          FROM turnuva 
          WHERE LOWER(turKazanan) IN (
            SELECT LOWER(oyuncuAdSoyad) 
            FROM oyuncu 
            WHERE isAktif = 1 
              AND (LOWER(oyuncuSehir) LIKE '%' || LOWER(s.sehirAd) || '%'
                   OR LOWER(s.sehirAd) LIKE '%' || LOWER(oyuncuSehir) || '%')
          )
        ) as toplamSampiyonluk
      FROM sehirler s
      ORDER BY s.sehirAd ASC
    ''');

    return List.generate(maps.length, (i) => Sehir.fromMap(maps[i]));
  }

  void _sehirFormuGoster({Sehir? sehir}) {
    if (sehir != null) {
      _sehirController.text = sehir.sehirAd;
    } else {
      _sehirController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(sehir == null ? 'Yeni Şehir Ekle' : 'Şehri Düzenle'),
        content: TextField(
          controller: _sehirController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Şehir Adı',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_sehirController.text.trim().isEmpty) return;
              final navigator = Navigator.of(dialogContext);
              final db = await DatabaseHelper().database;

              if (sehir == null) {
                await db.insert('sehirler', {
                  'sehirAd': _sehirController.text.trim(),
                });
              } else {
                await db.update(
                  'sehirler',
                  {'sehirAd': _sehirController.text.trim()},
                  where: 'sehirId = ?',
                  whereArgs: [sehir.sehirId],
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
        title: const Text(
          'Şehirler Yönetimi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Sehir>>(
        future: _sehirlerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Henüz hiç şehir eklenmemiş.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final sehirlerListesi = snapshot.data!;

          return ListView.builder(
            itemCount: sehirlerListesi.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (itemContext, index) {
              final sehir = sehirlerListesi[index];
              final bool kartAcikMi = _acikSehirId == sehir.sehirId;

              // 🎯 toMap() ENGELİ KALKTI: Veriler doğrudan Sehir nesnesinin içinden taranıyor
              final int toplamOyuncuCount = sehir.toplamOyuncu;
              final int toplamSampiyonlukCount = sehir.toplamSampiyonluk;
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    // 🎯 ANA SATIR: Şehir adı ve sağ taraftaki silme butonu
                    ListTile(
                      onTap: () {
                        setState(() {
                          _acikSehirId = kartAcikMi ? null : sehir.sehirId;
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(
                          Icons.location_city,
                          color: Colors.blue.shade700,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        sehir.sehirAd,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            kartAcikMi
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          // 🗑️ PARMAK DOSTU VE BÜYÜTÜLMÜŞ DAİRESEL SİLME BUTONU
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              bool? onay = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Şehri Sil'),
                                  content: Text(
                                    '${sehir.sehirAd} şehrini sildiğinizde bu bölge kayıtları etkilenecektir. Onaylıyor musunuz?',
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
                                  'sehirler',
                                  where: 'sehirId = ?',
                                  whereArgs: [sehir.sehirId],
                                );
                                _verileriYenile();
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🚀 AKORDEON PANELİ: Kart açıldığında yumuşak geçişle süzülen alt alan
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          top: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 12, thickness: 0.5),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _istatistikSatiri(
                                  Icons.people_outline,
                                  "Toplam Oyuncu:",
                                  "$toplamOyuncuCount Kişi",
                                ),
                                _istatistikSatiri(
                                  Icons.emoji_events_outlined,
                                  "Şampiyonluklar:",
                                  "$toplamSampiyonlukCount Kupa",
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // ✏️ KALEM SİMGESİNİN YERİNE GELEN GENİŞ DÜZENLEME BUTONU
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _sehirFormuGoster(sehir: sehir),
                                icon: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                label: const Text(
                                  "Şehir İsmini Düzenle",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  side: BorderSide(
                                    color: Colors.orange.shade300,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: kartAcikMi
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _sehirFormuGoster(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 🎯 AKORDEON İÇİ SATIR TASARIM ŞABLONU
  Widget _istatistikSatiri(IconData icon, String baslik, String deger) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                baslik,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                deger,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sehirController.dispose();
    super.dispose();
  }
} // 👈 Sınıfı ve 'sehirler_sayfasi.dart' dosyasını sıfır hatayla kapatan son süslü parantez
