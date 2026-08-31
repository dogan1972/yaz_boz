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

class TurBilgisi {
  final String id;
  final String turTarih;
  final String? turKazanan;
  const TurBilgisi({required this.id, required this.turTarih, this.turKazanan});

  factory TurBilgisi.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TurBilgisi(
      id: doc.id,
      turTarih: data['turTarih']?.toString() ?? '',
      turKazanan: data['turKazanan']?.toString(),
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

  const Oyun({
    required this.id,
    this.numara,
    required this.turId,
    required this.oyunTarih,
    required this.elSayisi,
    required this.oyuncuSayisi,
    required this.oyuncu,
    this.oyuncuIds, // ✅ YENİ
    this.oyunKazananUid, // ✅ YENİ
    this.oyunKaybedenUid, // ✅ YENİ
    this.oyunKazanan,
    this.oyunKaybeden,
    required this.esliMi,
    this.yuksekSkorKazanir = false,
    this.grupId,
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
  };
}
