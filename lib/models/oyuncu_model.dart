import 'package:yaz_boz/helper/database_helper.dart';


class Oyuncu {
  final int? oyuncuId;
  final String oyuncuAdSoyad;
  final String oyuncuSehir;

  Oyuncu({this.oyuncuId, required this.oyuncuAdSoyad, required this.oyuncuSehir});

  factory Oyuncu.fromMap(Map<String, dynamic> map) {
    return Oyuncu(
      oyuncuId: map['oyuncuId'],
      oyuncuAdSoyad: map['oyuncuAdSoyad'],
      oyuncuSehir: map['oyuncuSehir'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (oyuncuId != null) 'oyuncuId': oyuncuId,
      'oyuncuAdSoyad': oyuncuAdSoyad,
      'oyuncuSehir': oyuncuSehir,
    };
  }

  // ==========================================
  // CRUD OPERASYONLARI
  // ==========================================

  Future<int> save() async {
    final db = await DatabaseHelper().database;
    return await db.insert('oyuncu', toMap());
  }

  Future<int> update() async {
    if (oyuncuId == null) return 0;
    final db = await DatabaseHelper().database;
    return await db.update('oyuncu', toMap(), where: 'oyuncuId = ?', whereArgs: [oyuncuId]);
  }

  static Future<List<Oyuncu>> getAll() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('oyuncu', orderBy: 'oyuncuAdSoyad ASC');
    return List.generate(maps.length, (i) => Oyuncu.fromMap(maps[i]));
  }

  static Future<int> delete(int oyuncuId) async {
    final db = await DatabaseHelper().database;
    return await db.delete('oyuncu', where: 'oyuncuId = ?', whereArgs: [oyuncuId]);
  }
}
