// lib/models/turnuva_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Turnuva {
  final String id;
  final int? numara;
  final String sezonId;
  final String? turTarih;
  final String? turKazanan;
  final String? turIkinci;
  final String? turUcuncu;
  final String? turKaybeden;
  final int? tursonuc; // ✅ Nullable yapıldı
  final bool isLowestWins;
  final String? grupId;

  // ✅ YENİ: Aktif/Pasif durumu
  final bool aktifMi;

  const Turnuva({
    required this.id,
    this.numara,
    required this.sezonId,
    this.turTarih,
    this.turKazanan,
    this.turIkinci,
    this.turUcuncu,
    this.turKaybeden,
    this.tursonuc,
    this.isLowestWins = true,
    this.grupId,
    this.aktifMi = true, // ✅ Varsayılan olarak aktif
  });

  factory Turnuva.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Turnuva(
      id: doc.id,
      numara: (data['numara'] as num?)?.toInt(),
      sezonId: data['sezonId']?.toString() ?? '',
      turTarih: data['turTarih']?.toString(),
      turKazanan: data['turKazanan']?.toString(),
      turIkinci: data['turIkinci']?.toString(),
      turUcuncu: data['turUcuncu']?.toString(),
      turKaybeden: data['turKaybeden']?.toString(),
      tursonuc: (data['tursonuc'] as num?)?.toInt(),
      isLowestWins: data['isLowestWins'] ?? true,
      grupId: data['grupId']?.toString(),
      // ✅ Firestore'dan oku, yoksa varsayılan true
      aktifMi: data['aktifMi'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'numara': numara,
    'sezonId': sezonId,
    'turTarih': turTarih,
    'turKazanan': turKazanan,
    'turIkinci': turIkinci,
    'turUcuncu': turUcuncu,
    'turKaybeden': turKaybeden,
    'tursonuc': tursonuc,
    'isLowestWins': isLowestWins,
    'grupId': grupId,
    'aktifMi': aktifMi, // ✅ Kaydet
  };
}
