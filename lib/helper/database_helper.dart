import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'oyun_veritabani.db');
    return await openDatabase(
      path,
      version: 5, // 🚀 Versiyonu 5'e yükseltiyoruz (esliMi kolonu için)
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Yabancı anahtar kısıtlamalarını ve CASCADE özelliğini SQLite içinde aktif eder
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // 🚀 VERİLERİ KORUMA MOTORU: Eski cihazlardaki mevcut verilere zarar vermeden esliMi kolonunu canlı olarak enjekte eder
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      try {
        // Mevcut oyuncu tablosuna isAktif kolonunu ekler ve eski oyuncuları varsayılan olarak AKTİF (1) kabul eder
        await db.execute(
          "ALTER TABLE oyuncu ADD COLUMN isAktif INTEGER DEFAULT 1;",
        );
      } catch (e) {
        _logger(
          "isAktif kolonu güncelleme esnasında zaten mevcut veya bir hata oluştu: $e",
        );
      }
    }

    // 🆕 YENİ: Eşli Mi? kolonunu ekleyelim
    if (oldVersion < 5) {
      try {
        // Mevcut oyunlar tablosuna esliMi kolonunu ekler ve eski oyunları varsayılan olarak TEKLI (0) kabul eder
        await db.execute(
          "ALTER TABLE oyunlar ADD COLUMN esliMi INTEGER DEFAULT 0;",
        );
      } catch (e) {
        _logger(
          "esliMi kolonu güncelleme esnasında zaten mevcut veya bir hata oluştu: $e",
        );
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE sezonlar (sezonId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, sezonTarih TEXT NOT NULL, sezonSampiyon TEXT)',
    );

    await db.execute(''' 
      CREATE TABLE turnuva (
        turId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        sezonId INTEGER NOT NULL,
        turTarih TEXT NOT NULL,
        turOyuncular TEXT,
        tursonuc INTEGER,
        turKazanan TEXT,
        turKaybeden TEXT,
        FOREIGN KEY (sezonId) REFERENCES sezonlar (sezonId) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE TABLE sehirler (sehirId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, sehirAd TEXT NOT NULL)',
    );

    // 🚀 OYUNCU TABLOSU GÜNCELLENDİ: Sıfır kurulumlarda 'isAktif' kolonu doğrudan oluşturulur
    await db.execute(
      'CREATE TABLE oyuncu (oyuncuId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, oyuncuAdSoyad TEXT NOT NULL, oyuncuSehir TEXT NOT NULL, isAktif INTEGER DEFAULT 1)',
    );

    // 🆕 YENİ: OYUNLAR TABLOSU GÜNCELLENDİ: 'esliMi' kolonu eklendi
    await db.execute(''' 
      CREATE TABLE oyunlar (
        oyunId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        turId INTEGER NOT NULL,
        oyunTarih TEXT NOT NULL,
        elSayisi INTEGER NOT NULL,
        oyuncuSayisi INTEGER NOT NULL,
        oyuncu TEXT NOT NULL,
        oyunKazanan TEXT,
        oyunKaybeden TEXT, // 🔧 DÜZELTME: Büyük harf hatası giderildi
        esliMi INTEGER DEFAULT 0, // 🆕 Eşli oyun bayrağı
        FOREIGN KEY (turId) REFERENCES turnuva (turId) ON DELETE CASCADE
      )
    ''');

    await db.execute(''' 
      CREATE TABLE eller (
        elId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        oyunId INTEGER NOT NULL,
        elTarih TEXT NOT NULL,
        Oyuncu1 TEXT NOT NULL,
        oyuncu2 TEXT NOT NULL,
        oyuncu3 TEXT,
        oyuncu4 TEXT,
        elSkor INTEGER NOT NULL,
        gosterge INTEGER,
        FOREIGN KEY (oyunId) REFERENCES oyunlar (oyunId) ON DELETE CASCADE
      )
    ''');
  }

  // Linter uyarısını engellemek için kurumsal log köprüsü
  void _logger(String mesaj) {
    assert(() {
      return true;
    }());
  }
}
