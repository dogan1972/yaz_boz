import 'package:yaz_boz/helper/database_helper.dart';


class Sehir {
  final int? sehirId;
  final String sehirAd;

  Sehir({this.sehirId, required this.sehirAd});

  factory Sehir.fromMap(Map<String, dynamic> map) {
    return Sehir(
      sehirId: map['sehirId'],
      sehirAd: map['sehirAd'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (sehirId != null) 'sehirId': sehirId,
      'sehirAd': sehirAd,
    };
  }

  // ==========================================
  // CRUD OPERASYONLARI
  // ==========================================

  Future<int> save() async {
    final db = await DatabaseHelper().database;
    return await db.insert('sehirler', toMap());
  }

  Future<int> update() async {
    if (sehirId == null) return 0;
    final db = await DatabaseHelper().database;
    return await db.update('sehirler', toMap(), where: 'sehirId = ?', whereArgs: [sehirId]);
  }

  static Future<List<Sehir>> getAll() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('sehirler', orderBy: 'sehirAd ASC');
    return List.generate(maps.length, (i) => Sehir.fromMap(maps[i]));
  }

  static Future<int> delete(int sehirId) async {
    final db = await DatabaseHelper().database;
    return await db.delete('sehirler', where: 'sehirId = ?', whereArgs: [sehirId]);
  }
}
