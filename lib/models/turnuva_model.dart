import 'package:yaz_boz/helper/database_helper.dart';

class Turnuva {
  final int? turId;
  final int sezonId;
  final String turTarih;
  final String? turOyuncular;
  final int? tursonuc;
  final String? turKazanan;
  final String? turKaybeden;

  Turnuva({
    this.turId,
    required this.sezonId,
    required this.turTarih,
    this.turOyuncular,
    this.tursonuc,
    this.turKazanan,
    this.turKaybeden,
  });

  factory Turnuva.fromMap(Map<String, dynamic> map) {
    return Turnuva(
      turId: map['turId'],
      sezonId: map['sezonId'],
      turTarih: map['turTarih'],
      turOyuncular: map['turOyuncular'],
      tursonuc: map['tursonuc'],
      turKazanan: map['turKazanan'],
      turKaybeden: map['turKaybeden'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (turId != null) 'turId': turId,
      'sezonId': sezonId,
      'turTarih': turTarih,
      'turOyuncular': turOyuncular,
      'tursonuc': tursonuc,
      'turKazanan': turKazanan,
      'turKaybeden': turKaybeden,
    };
  }

  // ==========================================
  // CRUD OPERASYONLARI
  // ==========================================

  // Kaydetme / Ekleme
  Future<int> save() async {
    final db = await DatabaseHelper().database;
    return await db.insert('turnuva', toMap());
  }

  // Güncelleme
  Future<int> update() async {
    if (turId == null) return 0;
    final db = await DatabaseHelper().database;
    return await db.update(
      'turnuva',
      toMap(),
      where: 'turId = ?',
      whereArgs: [turId],
    );
  }

  // Statik Metotlar (Nesne oluşturmadan tüm listeyi çekmek için)
  static Future<List<Turnuva>> getAll() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'turnuva',
      orderBy: 'turId DESC',
    );
    return List.generate(maps.length, (i) => Turnuva.fromMap(maps[i]));
  }

  static Future<List<Turnuva>> sezonaGoreGetir(int sezonId) async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'turnuva',
      where: 'sezonId = ?',
      whereArgs: [sezonId],
      orderBy: 'turId ASC',
    );
    return List.generate(maps.length, (i) => Turnuva.fromMap(maps[i]));
  }

  static Future<int> delete(int turId) async {
    final db = await DatabaseHelper().database;
    // Sadece turnuvayı siler; altındaki oyunlar ve eller otomatik silinir!
    return await db.delete('turnuva', where: 'turId = ?', whereArgs: [turId]);
  }
}
