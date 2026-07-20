import 'package:yaz_boz/helper/database_helper.dart';

class Oyun {
  final int? oyunId;
  final int turId;
  final String oyunTarih;
  final int elSayisi;
  final int oyuncuSayisi;
  final String oyuncu;
  final String? oyunKazanan;
  final String? oyunKaybeden;
  final int esliMi; //  YENİ ALAN: 1 = Eşli, 0 = Tekli

  Oyun({
    this.oyunId,
    required this.turId,
    required this.oyunTarih,
    required this.elSayisi,
    required this.oyuncuSayisi,
    required this.oyuncu,
    this.oyunKazanan,
    this.oyunKaybeden,
    this.esliMi = 0, // Varsayılan olarak tekli (0)
  });

  factory Oyun.fromMap(Map<String, dynamic> map) {
    return Oyun(
      oyunId: map['oyunId'],
      turId: map['turId'],
      oyunTarih: map['oyunTarih'],
      elSayisi: map['elSayisi'],
      oyuncuSayisi: map['oyuncuSayisi'],
      oyuncu: map['oyuncu'],
      oyunKazanan: map['oyunKazanan'],
      oyunKaybeden:
          map['oyunKaybeden'], // 🔧 DÜZELTME: Büyük harf hatası giderildi
      esliMi: map['esliMi'] ?? 0, // 🆕 Eşli bilgisi çekiliyor
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (oyunId != null) 'oyunId': oyunId,
      'turId': turId,
      'oyunTarih': oyunTarih,
      'elSayisi': elSayisi,
      'oyuncuSayisi': oyuncuSayisi,
      'oyuncu': oyuncu,
      'oyunKazanan': oyunKazanan,
      'oyunKaybeden': oyunKaybeden, // 🔧 DÜZELTME: Büyük harf hatası giderildi
      'esliMi': esliMi, // 🆕 Eşli bilgisi kaydediliyor
    };
  }

  // ==========================================
  // CRUD OPERASYONLARI
  // ==========================================

  Future<int> save() async {
    final db = await DatabaseHelper().database;
    return await db.insert('oyunlar', toMap());
  }

  Future<int> update() async {
    if (oyunId == null) return 0;
    final db = await DatabaseHelper().database;
    return await db.update(
      'oyunlar',
      toMap(),
      where: 'oyunId = ?',
      whereArgs: [oyunId],
    );
  }

  /// Veritabanındaki en son başlatılan (aktif) oyunu getirir.
  static Future<Oyun?> enSonAktifOyunuGetir() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'oyunlar',
      where: 'oyunKazanan IS NULL',
      orderBy: 'oyunId DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Oyun.fromMap(maps.first);
  }

  static Future<List<Oyun>> getAll() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'oyunlar',
      orderBy: 'oyunId DESC',
    );
    return List.generate(maps.length, (i) => Oyun.fromMap(maps[i]));
  }

  static Future<int> delete(int oyunId) async {
    final db = await DatabaseHelper().database;
    return await db.delete('oyunlar', where: 'oyunId = ?', whereArgs: [oyunId]);
  }

  /// Oyuna ait ellerin toplam skorunu hesaplar ve sonucu belirler.
  /// [kaliciKapat] true ise oyunu arşivler, false ise sadece canlı hesaplama yapar.
  static Future<Map<String, String?>> oyunSonucunuHesapla({
    required int oyunId,
    required bool isHighestWins,
    bool kaliciKapat = false,
  }) async {
    final db = await DatabaseHelper().database;

    String orderDirection = isHighestWins ? 'DESC' : 'ASC';

    final List<Map<String, dynamic>> res = await db.rawQuery(
      '''
      SELECT Oyuncu1, SUM(elSkor + IFNULL(gosterge, 0)) as toplamSkor 
      FROM eller 
      WHERE oyunId = ? 
      GROUP BY Oyuncu1 
      ORDER BY toplamSkor $orderDirection
    ''',
      [oyunId],
    );

    if (res.isEmpty) return {'kazanan': null, 'kaybeden': null};

    String kazanan = res.first['Oyuncu1'] as String;
    String kaybeden = res.last['Oyuncu1'] as String;

    if (kaliciKapat) {
      await db.update(
        'oyunlar',
        {
          'oyunKazanan': kazanan,
          'oyunKaybeden': kaybeden, // 🔧 DÜZELTME: Büyük harf hatası giderildi
        },
        where: 'oyunId = ?',
        whereArgs: [oyunId],
      );
    }

    return {'kazanan': kazanan, 'kaybeden': kaybeden};
  }
}
