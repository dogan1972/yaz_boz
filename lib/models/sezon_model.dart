import 'package:yaz_boz/helper/database_helper.dart';

class Sezon {
  final int? sezonId;
  final String sezonTarih;
  final String? sezonSampiyon;

  Sezon({this.sezonId, required this.sezonTarih, this.sezonSampiyon});

  factory Sezon.fromMap(Map<String, dynamic> map) {
    return Sezon(
      sezonId: map['sezonId'],
      sezonTarih: map['sezonTarih'],
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

  // ==========================================
  // CRUD OPERASYONLARI
  // ==========================================

  Future<int> save() async {
    final db = await DatabaseHelper().database;
    return await db.insert('sezonlar', toMap());
  }

  Future<int> update() async {
    if (sezonId == null) return 0;
    final db = await DatabaseHelper().database;
    return await db.update(
      'sezonlar',
      toMap(),
      where: 'sezonId = ?',
      whereArgs: [sezonId],
    );
  }

  static Future<List<Sezon>> getAll() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sezonlar',
      orderBy: 'sezonId DESC',
    );
    return List.generate(maps.length, (i) => Sezon.fromMap(maps[i]));
  }

  static Future<int> delete(int sezonId) async {
    final db = await DatabaseHelper().database;
    // Sadece sezonu siler; turnuva, oyun ve eller otomatik silinir!
    return await db.delete(
      'sezonlar',
      where: 'sezonId = ?',
      whereArgs: [sezonId],
    );
  }

  // lib/models/sezon_model.dart içerisindeki ilgili kısım
  static Future<Map<String, dynamic>> getSezonIstatistikleri(
    int sezonId,
  ) async {
    final db = await DatabaseHelper().database;

    // En çok kazanan oyuncu
    final List<Map<String, dynamic>> kazananRes = await db.rawQuery(
      '''
      SELECT o.oyunKazanan as oyuncu, COUNT(o.oyunId) as galibiyetSayisi
      FROM oyunlar o
      JOIN turnuva t ON o.turId = t.turId
      WHERE t.sezonId = ? AND o.oyunKazanan IS NOT NULL
      GROUP BY o.oyunKazanan
      ORDER BY galibiyetSayisi DESC
      LIMIT 1
    ''',
      [sezonId],
    );

    // En çok kaybeden oyuncu
    final List<Map<String, dynamic>> kaybedenRes = await db.rawQuery(
      '''
      SELECT o.OyunKaybeden as oyuncu, COUNT(o.oyunId) as maglubiyetSayisi
      FROM oyunlar o
      JOIN turnuva t ON o.turId = t.turId
      WHERE t.sezonId = ? AND o.OyunKaybeden IS NOT NULL
      GROUP BY o.OyunKaybeden
      ORDER BY maglubiyetSayisi DESC
      LIMIT 1
    ''',
      [sezonId],
    );

    return {
      'enCokKazanan': kazananRes.isNotEmpty
          ? kazananRes.first['oyuncu']
          : 'Veri Yok',
      'galibiyetSayisi': kazananRes.isNotEmpty
          ? kazananRes.first['galibiyetSayisi']
          : 0,
      'enCokKaybeden': kaybedenRes.isNotEmpty
          ? kaybedenRes.first['oyuncu']
          : 'Veri Yok',
      'maglubiyetSayisi': kaybedenRes.isNotEmpty
          ? kaybedenRes.first['maglubiyetSayisi']
          : 0,
    };
  }
}
