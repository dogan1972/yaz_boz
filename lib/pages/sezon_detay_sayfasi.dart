import 'package:flutter/material.dart';
import 'package:yaz_boz/helper/database_helper.dart';

// Tabloda listelenecek her bir oyuncunun sezon dokum modeli
class SezonOyuncuIstatistigi {
  final String oyuncuAdi;
  final int oynadigiOyun;
  final int kazandigiOyun;
  final int kaybettigiOyun;

  SezonOyuncuIstatistigi({
    required this.oyuncuAdi,
    required this.oynadigiOyun,
    required this.kazandigiOyun,
    required this.kaybettigiOyun,
  });
}

class SezonDetaySayfasi extends StatefulWidget {
  final int sezonId;
  final String sezonAdi;

  const SezonDetaySayfasi({
    super.key,
    required this.sezonId,
    required this.sezonAdi,
  });

  @override
  State<SezonDetaySayfasi> createState() => _SezonDetaySayfasiState();
}

class _SezonDetaySayfasiState extends State<SezonDetaySayfasi> {
  late Future<Map<String, dynamic>> _istatistikFuture;

  @override
  void initState() {
    super.initState();
    _istatistikFuture = _sezonVerileriniHesapla(widget.sezonId);
  }

  // 📊 TÜM SEZON VE OYUNCU MATRİSİNİ HESAPLAYAN GELİŞMİŞ SQL MOTORU
  Future<Map<String, dynamic>> _sezonVerileriniHesapla(int sId) async {
    final db = await DatabaseHelper().database;

    // 1. Toplam oynanmis oyun sayisi
    final List<Map<String, dynamic>> oyunSayisiRes = await db.rawQuery(
      '''
      SELECT COUNT(*) as toplam FROM oyunlar WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?)
    ''',
      [sId],
    );
    int toplamOyun = oyunSayisiRes.isNotEmpty
        ? oyunSayisiRes.first['toplam'] as int
        : 0;

    // 2. En cok kazanan oyuncu
    final List<Map<String, dynamic>> enCokKazananRes = await db.rawQuery(
      '''
      SELECT oyunKazanan, COUNT(oyunKazanan) as adet FROM oyunlar 
      WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?) AND oyunKazanan IS NOT NULL AND oyunKazanan != ''
      GROUP BY oyunKazanan ORDER BY adet DESC LIMIT 1
    ''',
      [sId],
    );
    String enCokKazanan = enCokKazananRes.isNotEmpty
        ? "${enCokKazananRes.first['oyunKazanan']} (${enCokKazananRes.first['adet']} Galibiyet)"
        : "Veri Yok";

    // 3. En cok yenilen oyuncu sorgusu ve maglubiyet adedi odakli yedek plan motoru (MÜKERRER TANIM TEMİZLENDİ)
    final List<Map<String, dynamic>> enCokYenilenRes = await db.rawQuery(
      '''
      SELECT oyunKaybeden, COUNT(oyunKaybeden) as adet FROM oyunlar 
      WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?) AND oyunKaybeden IS NOT NULL AND oyunKaybeden != ''
      GROUP BY oyunKaybeden ORDER BY adet DESC LIMIT 1
    ''',
      [sId],
    );

    String enCokYenilen = "Veri Yok";

    if (enCokYenilenRes.isNotEmpty &&
        enCokYenilenRes.first['oyunKaybeden'] != null) {
      enCokYenilen =
          "${enCokYenilenRes.first['oyunKaybeden']} (${enCokYenilenRes.first['adet']} Maglubiyet)";
    } else {
      final List<Map<String, dynamic>> yedekYenilenRes = await db.rawQuery(
        '''
        SELECT Oyuncu1, 
               (SELECT COUNT(*) FROM (
                  SELECT oyunId, Oyuncu1, SUM(elSkor + IFNULL(gosterge, 0)) as elToplam 
                  FROM eller 
                  GROUP BY oyunId, Oyuncu1
                ) as altTablo 
                WHERE altTablo.Oyuncu1 = anaTablo.Oyuncu1 
                  AND altTablo.oyunId IN (SELECT oyunId FROM oyunlar WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?))
                  AND altTablo.elToplam = (
                    SELECT MAX(icTablo.icToplam) FROM (
                      SELECT oyunId, SUM(elSkor + IFNULL(gosterge, 0)) as icToplam 
                      FROM eller GROUP BY oyunId, Oyuncu1
                    ) as icTablo WHERE icTablo.oyunId = altTablo.oyunId
                  )
               ) as maglubiyetAdedi
        FROM eller as anaTablo
        WHERE oyunId IN (SELECT oyunId FROM oyunlar WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?))
        GROUP BY Oyuncu1
        ORDER BY SUM(elSkor + IFNULL(gosterge, 0)) DESC
        LIMIT 1
      ''',
        [sId, sId],
      );

      if (yedekYenilenRes.isNotEmpty &&
          yedekYenilenRes.first['Oyuncu1'] != null) {
        final int kayipSayisi = yedekYenilenRes.first['maglubiyetAdedi'] ?? 1;
        enCokYenilen =
            "${yedekYenilenRes.first['Oyuncu1']} ($kayipSayisi Maglubiyet)";
      }
    }

    // 4. Sezon baslangic ve bitis tarihi araligi
    final List<Map<String, dynamic>> tarihRes = await db.rawQuery(
      '''
      SELECT MIN(elTarih) as baslangic, MAX(elTarih) as bitis FROM eller 
      WHERE oyunId IN (SELECT oyunId FROM oyunlar WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?))
    ''',
      [sId],
    );
    String baslangicTarihi =
        (tarihRes.isNotEmpty && tarihRes.first['baslangic'] != null)
        ? tarihRes.first['baslangic'].toString().substring(0, 10)
        : "Baslatilmadi";
    String bitisTarihi =
        (tarihRes.isNotEmpty && tarihRes.first['bitis'] != null)
        ? tarihRes.first['bitis'].toString().substring(0, 10)
        : "Devam Ediyor";

    // 5. En iyi skorla oyun kazanan oyuncu ve skoru
    final List<Map<String, dynamic>> enIyiSkorRes = await db.rawQuery(
      '''
      SELECT Oyuncu1, SUM(elSkor + IFNULL(gosterge, 0)) as toplamPuan FROM eller 
      WHERE oyunId IN (SELECT oyunId FROM oyunlar WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?))
      GROUP BY oyunId, Oyuncu1 ORDER BY toplamPuan ASC LIMIT 1
    ''',
      [sId],
    );
    String enIyiSkor = enIyiSkorRes.isNotEmpty
        ? "${enIyiSkorRes.first['Oyuncu1']} (Skor: ${enIyiSkorRes.first['toplamPuan']})"
        : "Veri Yok";

    // 6. En kotu skorla oyun kaybeden oyuncu ve skoru
    final List<Map<String, dynamic>> enKotuSkorRes = await db.rawQuery(
      '''
      SELECT Oyuncu1, SUM(elSkor + IFNULL(gosterge, 0)) as toplamPuan FROM eller 
      WHERE oyunId IN (SELECT oyunId FROM oyunlar WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?))
      GROUP BY Oyuncu1 ORDER BY toplamPuan DESC LIMIT 1
    ''',
      [sId],
    );
    String enKotuSkor = enKotuSkorRes.isNotEmpty
        ? "${enKotuSkorRes.first['Oyuncu1']} (Skor: ${enKotuSkorRes.first['toplamPuan']})"
        : "Veri Yok";

    // 7. SEZON BOYUNCA MAÇ YAPMIŞ TÜM OYUNCULARIN DETAYLI MATRİS ANALİZİ
    final List<Map<String, dynamic>> oyuncularHamRes = await db.rawQuery(
      '''
      SELECT Oyuncu1 FROM eller 
      WHERE oyunId IN (SELECT oyunId FROM oyunlar WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?))
      GROUP BY Oyuncu1
    ''',
      [sId],
    );

    List<SezonOyuncuIstatistigi> oyuncuIstatistikListesi = [];

    for (var satir in oyuncularHamRes) {
      String oAd = satir['Oyuncu1'].toString();

      final List<Map<String, dynamic>> oOyunRes = await db.rawQuery(
        '''
        SELECT COUNT(*) as adet FROM oyunlar 
        WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?) 
          AND (oyuncu LIKE ? OR oyuncu LIKE ? OR oyuncu LIKE ?)
      ''',
        [sId, '$oAd,%', '%, $oAd,%', '%, $oAd'],
      );
      int oOyunCount = oOyunRes.isNotEmpty ? oOyunRes.first['adet'] as int : 0;

      final List<Map<String, dynamic>> oKazanRes = await db.rawQuery(
        '''
        SELECT COUNT(*) as adet FROM oyunlar 
        WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?) AND oyunKazanan = ?
      ''',
        [sId, oAd],
      );
      int oKazanCount = oKazanRes.isNotEmpty
          ? oKazanRes.first['adet'] as int
          : 0;

      final List<Map<String, dynamic>> oKayipRes = await db.rawQuery(
        '''
        SELECT COUNT(*) as adet FROM oyunlar 
        WHERE turId IN (SELECT turId FROM turnuva WHERE SezonId = ?) AND oyunKaybeden = ?
      ''',
        [sId, oAd],
      );
      int oKayipCount = oKayipRes.isNotEmpty
          ? oKayipRes.first['adet'] as int
          : 0;

      oyuncuIstatistikListesi.add(
        SezonOyuncuIstatistigi(
          oyuncuAdi: oAd,
          oynadigiOyun: oOyunCount,
          kazandigiOyun: oKazanCount,
          kaybettigiOyun: oKayipCount,
        ),
      );
    }

    return {
      'toplamOyun': toplamOyun,
      'enCokKazanan': enCokKazanan,
      'enCokYenilen': enCokYenilen,
      'baslangicTarihi': baslangicTarihi,
      'bitisTarihi': bitisTarihi,
      'enIyiSkor': enIyiSkor,
      'enKotuSkor': enKotuSkor,
      'oyuncuIstatistikleri': oyuncuIstatistikListesi,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sezonAdi} Detayları'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _istatistikFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata oluştu: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(
              child: Text('İstatistik verileri yüklenemedi.'),
            );
          }

          final data = snapshot.data!;
          final oyuncuListesi =
              data['oyuncuIstatistikleri'] as List<SezonOyuncuIstatistigi>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SEZON PERİYOD BANDI
                Card(
                  color: Colors.blue.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _tarihBlokuOlustur(
                          "Baslangic Tarihi",
                          data['baslangicTarihi'],
                          Icons.play_circle_outline,
                          Colors.green,
                        ),
                        const SizedBox(
                          height: 40,
                          child: VerticalDivider(
                            width: 20,
                            thickness: 1,
                            color: Colors.grey,
                          ),
                        ),
                        _tarihBlokuOlustur(
                          "Bitis Tarihi",
                          data['bitisTarihi'],
                          Icons.stop_circle_outlined,
                          Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  "Sezon Rekor Verileri",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueGrey,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                // LİDERLİK VE REKOR KARTLARI
                _detayKartiOlustur(
                  icon: Icons.tag,
                  renk: Colors.purple,
                  baslik: "Toplam Oynanan Oyun",
                  deger: "${data['toplamOyun']} Mac",
                ),
                _detayKartiOlustur(
                  icon: Icons.emoji_events,
                  renk: Colors.green,
                  baslik: "En Cok Kazanan Oyuncu",
                  deger: data['enCokKazanan'],
                ),
                _detayKartiOlustur(
                  icon: Icons.trending_down,
                  renk: Colors.redAccent,
                  baslik: "En Cok Yenilen Oyuncu",
                  deger: data['enCokYenilen'],
                ),
                _detayKartiOlustur(
                  icon: Icons.star,
                  renk: Colors.amber.shade800,
                  baslik: "En Iyi Skorla Kazanan (En Dusuk Puan)",
                  deger: data['enIyiSkor'],
                ),
                _detayKartiOlustur(
                  icon: Icons.gavel,
                  renk: Colors.brown,
                  baslik: "En Kotu Skorla Kaybeden (En Yuksek Ceza)",
                  deger: data['enKotuSkor'],
                ),

                const SizedBox(height: 24),
                const Text(
                  "Sezon Oyuncu İstatistikleri (Oynadı/Kazandı/Kaybetti)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                // SÜTUNLARI EŞİT MATRİS OYUNCU TABLOSU
                oyuncuListesi.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "Bu sezona ait oyuncu verisi bulunmuyor.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          border: const TableBorder(
                            horizontalInside: BorderSide(
                              color: Colors.black,
                              width: 1,
                            ),
                            verticalInside: BorderSide(
                              color: Colors.black,
                              width: 1,
                            ),
                          ),
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Oyuncu',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Oynadı',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Kazandı',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Kaybetti',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            ...oyuncuListesi.map(
                              (istatistik) => TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      istatistik.oyuncuAdi,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      istatistik.oynadigiOyun.toString(),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      istatistik.kazandigiOyun.toString(),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      istatistik.kaybettigiOyun.toString(),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Başlangıç ve bitiş tarih periyot kutularını hizalayan şık alt şablon metot
  Widget _tarihBlokuOlustur(
    String baslik,
    String deger,
    IconData icon,
    Color renk,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: renk, size: 16),
            const SizedBox(width: 4),
            Text(
              baslik,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          deger,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Sezonun şampiyonlarını ve rekorlarını tek tek listeleyen kompakt kart bileşeni
  Widget _detayKartiOlustur({
    required IconData icon,
    required Color renk,
    required String baslik,
    required String deger,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: renk.withValues(alpha: 0.1),
              child: Icon(icon, color: renk, size: 18),
            ),
            title: Text(
              baslik,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            trailing: Text(
              deger,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
} // 👈 Dosyayı ve '_SezonDetaySayfasiState' sınıfını hatasız kapatan son süslü parantez
