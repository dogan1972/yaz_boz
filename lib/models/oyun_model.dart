// lib/models/oyun_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Oyuncu {
  final String id;
  final String oyuncuAdSoyad;
  const Oyuncu({required this.id, required this.oyuncuAdSoyad});

  factory Oyuncu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Oyuncu(
      id: doc.id,
      oyuncuAdSoyad: data['oyuncuAdSoyad']?.toString() ?? '',
    );
  }
}

// lib/models/turnuva_model.dart içindeki TurBilgisi sınıfı

class TurBilgisi {
  final String id;
  final String turTarih;
  final String? turKazanan;
  final bool aktifMi; // ✅ YENİ ALAN EKLENDİ

  const TurBilgisi({
    required this.id,
    required this.turTarih,
    this.turKazanan,
    this.aktifMi = true, // ✅ Varsayılan true
  });

  factory TurBilgisi.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return TurBilgisi(
      id: doc.id,
      turTarih: d['turTarih']?.toString() ?? '',
      turKazanan: d['turKazanan']?.toString(),
      aktifMi: d['aktifMi'] == true, // ✅ Firestore'dan oku
    );
  }
}

class Oyun {
  final String id;
  final int? numara;
  final String turId;
  final String oyunTarih;
  final int elSayisi;
  final int oyuncuSayisi;
  final String oyuncu;

  // ✅ YENİ ALANLAR: UID LİSTESİ VE KAZANAN/KAYBEDEN UID'LERİ
  final List<String>? oyuncuIds;
  final String? oyunKazananUid;
  final String? oyunKaybedenUid;

  final String? oyunKazanan;
  final String? oyunKaybeden;
  final bool esliMi;
  final bool yuksekSkorKazanir;
  final String? grupId;

  // ✅ ZİNCİRLEME SONLANDIRMA İÇİN EKLENDİ
  final bool aktifMi;

  const Oyun({
    required this.id,
    this.numara,
    required this.turId,
    required this.oyunTarih,
    required this.elSayisi,
    required this.oyuncuSayisi,
    required this.oyuncu,
    this.oyuncuIds,
    this.oyunKazananUid,
    this.oyunKaybedenUid,
    this.oyunKazanan,
    this.oyunKaybeden,
    required this.esliMi,
    this.yuksekSkorKazanir = false,
    this.grupId,
    this.aktifMi = true, // ✅ Varsayılan olarak aktif
  });

  factory Oyun.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // ✅ OYUNCU IDS LİSTESİNİ GÜVENLİ ŞEKİLDE PARSE ET
    List<String>? parsedOyuncuIds;
    if (data['oyuncuIds'] is List) {
      parsedOyuncuIds = (data['oyuncuIds'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return Oyun(
      id: doc.id,
      numara: (data['numara'] as num?)?.toInt(),
      turId: data['turId']?.toString() ?? '',
      oyunTarih: data['oyunTarih']?.toString() ?? '',
      elSayisi: (data['elSayisi'] as num?)?.toInt() ?? 8,
      oyuncuSayisi: (data['oyuncuSayisi'] as num?)?.toInt() ?? 4,
      oyuncu: data['oyuncu']?.toString() ?? '',

      // ✅ YENİ ALANLARI OKU
      oyuncuIds: parsedOyuncuIds,
      oyunKazananUid: data['oyunKazananUid']?.toString(),
      oyunKaybedenUid: data['oyunKaybedenUid']?.toString(),

      oyunKazanan: data['oyunKazanan']?.toString(),
      oyunKaybeden: data['oyunKaybeden']?.toString(),
      esliMi: data['esliMi'] == true || data['esliMi'] == 1,
      yuksekSkorKazanir:
          data['yuksekSkorKazanir'] == true || data['yuksekSkorKazanir'] == 1,
      grupId: data['grupId']?.toString(),

      // ✅ AKTİF Mİ ALANINI OKU (Eski kayıtlar için fallback: true)
      aktifMi: data['aktifMi'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'numara': numara,
    'turId': turId,
    'oyunTarih': oyunTarih,
    'elSayisi': elSayisi,
    'oyuncuSayisi': oyuncuSayisi,
    'oyuncu': oyuncu,

    // ✅ YENİ ALANLARI MAP'E EKLE
    'oyuncuIds': oyuncuIds,
    'oyunKazananUid': oyunKazananUid,
    'oyunKaybedenUid': oyunKaybedenUid,

    'oyunKazanan': oyunKazanan,
    'oyunKaybeden': oyunKaybeden,
    'esliMi': esliMi ? 1 : 0,
    'yuksekSkorKazanir': yuksekSkorKazanir ? 1 : 0,
    'grupId': grupId,

    // ✅ AKTİF Mİ ALANINI KAYDET
    'aktifMi': aktifMi,
  };
}
