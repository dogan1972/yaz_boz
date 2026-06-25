import 'package:yaz_boz/helper/database_helper.dart';

class El {
  final int? elId;
  final int oyunId;
  final String elTarih;
  final String oyuncu1;
  final String oyuncu2;
  final String? oyuncu3;
  final String? oyuncu4;
  final int elSkor;
  final int? gosterge; // 👈 1. MODEL DEĞİŞKENİ BURAYA EKLENDİ

  El({
    this.elId,
    required this.oyunId,
    required this.elTarih,
    required this.oyuncu1,
    required this.oyuncu2,
    this.oyuncu3,
    this.oyuncu4,
    required this.elSkor,
    this.gosterge, // 👈 2. CONSTRUCTOR PARAMETRESİ BURAYA EKLENDİ
  });

  // 🚀 Arayüzde elleri listelerken katılımcıları tek satırda birleştiren yardımcı getter
  String get elKatilimci {
    List<String> list = [oyuncu1, oyuncu2];
    if (oyuncu3 != null && oyuncu3!.isNotEmpty) list.add(oyuncu3!);
    if (oyuncu4 != null && oyuncu4!.isNotEmpty) list.add(oyuncu4!);
    return list.join(', ');
  }

  factory El.fromMap(Map<String, dynamic> map) {
    return El(
      elId: map['elId'] as int?,
      oyunId: map['oyunId'] as int,
      elTarih: map['elTarih'] as String,
      oyuncu1: map['Oyuncu1'] as String, // Veritabanındaki 'O' harfi büyüktür
      oyuncu2: map['oyuncu2'] as String,
      oyuncu3: map['oyuncu3'] as String?,
      oyuncu4: map['oyuncu4'] as String?,
      elSkor: map['elSkor'] as int,
      gosterge:
          map['gosterge'] as int?, // 👈 3. VERİTABANINDAN OKUMA ALANI EKLENDİ
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (elId != null) 'elId': elId,
      'oyunId': oyunId,
      'elTarih': elTarih,
      'Oyuncu1': oyuncu1,
      'oyuncu2': oyuncu2,
      'oyuncu3': oyuncu3,
      'oyuncu4': oyuncu4,
      'elSkor': elSkor,
      'gosterge': gosterge, // 👈 4. VERİTABANINA YAZMA ALANI EKLENDİ
    };
  }

  // ==========================================
  // CRUD OPERASYONLARI
  // ==========================================

  Future<int> save() async {
    final db = await DatabaseHelper().database;
    return await db.insert('eller', toMap());
  }

  Future<int> update() async {
    if (elId == null) return 0;
    final db = await DatabaseHelper().database;
    return await db.update(
      'eller',
      toMap(),
      where: 'elId = ?',
      whereArgs: [elId],
    );
  }

  static Future<List<El>> getAll() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'eller',
      orderBy: 'elId DESC',
    );
    return List.generate(maps.length, (i) => El.fromMap(maps[i]));
  }

  static Future<int> delete(int elId) async {
    final db = await DatabaseHelper().database;
    return await db.delete('eller', where: 'elId = ?', whereArgs: [elId]);
  }

  // 🚀 OYUN BAZLI FİLTRELEME VE ARŞİVLEME SAĞLAYAN KRİTİK FONKSİYON:
  static Future<List<El>> oyunaGoreGetir(int oyunId) async {
    final db = await DatabaseHelper().database;
    // Sadece parametre olarak gelen oyunId değerine ait satırları çeker
    final List<Map<String, dynamic>> maps = await db.query(
      'eller',
      where: 'oyunId = ?',
      whereArgs: [oyunId],
      orderBy: 'elId ASC', // Kronolojik sıra: 1. El, 2. El dizilimi için
    );
    return List.generate(maps.length, (i) => El.fromMap(maps[i]));
  }

  // Aynı tarihe (aynı ele) ait farklı oyuncu skorlarını toplu günceller
  static Future<void> topluGuncelle(
    String elTarih,
    Map<String, int> oyuncuSkorlari,
  ) async {
    final db = await DatabaseHelper().database;
    for (var entry in oyuncuSkorlari.entries) {
      await db.update(
        'eller',
        {'elSkor': entry.value},
        where: 'elTarih = ? AND Oyuncu1 = ?',
        whereArgs: [elTarih, entry.key],
      );
    }
  }
}
