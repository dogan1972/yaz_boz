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
      version: 3, // 🚀 Versiyonu 3'e yükseltiyoruz (Yeni şema için)
      onConfigure: _onConfigure, // 👈 Zincirleme silme için bu tetikleyici şart
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Yabancı anahtar kısıtlamalarını ve CASCADE özelliğini SQLite içinde aktif eder
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Veritabanı versiyonu yükseldiğinde mevcut tabloya yeni sütunu ekler
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Not: SQLite'ta mevcut tabloya doğrudan ON DELETE CASCADE eklenemez.
      // Bu yüzden en sağlıklı yöntem uygulamayı temiz kurmaktır (Bkz. 3. Adım).
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE sezonlar (sezonId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, sezonTarih TEXT NOT NULL, sezonSampiyon TEXT)',
    );

    // 🚀 TURNUVA TABLOSU GÜNCELLENDİ: Sezon silindiğinde turnuva da silinir
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
    await db.execute(
      'CREATE TABLE oyuncu (oyuncuId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, oyuncuAdSoyad TEXT NOT NULL, oyuncuSehir TEXT NOT NULL)',
    );

    // 🚀 OYUNLAR TABLOSU GÜNCELLENDİ: Turnuva silindiğinde oyunlar da silinir
    await db.execute('''
      CREATE TABLE oyunlar (
        oyunId INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        turId INTEGER NOT NULL,
        oyunTarih TEXT NOT NULL,
        elSayisi INTEGER NOT NULL,
        oyuncuSayisi INTEGER NOT NULL,
        oyuncu TEXT NOT NULL,
        oyunKazanan TEXT,
        OyunKaybeden TEXT,
        FOREIGN KEY (turId) REFERENCES turnuva (turId) ON DELETE CASCADE
      )
    ''');

    // 🚀 ELLER TABLOSU GÜNCELLENDİ: Oyun silindiğinde eller de silinir
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
}
