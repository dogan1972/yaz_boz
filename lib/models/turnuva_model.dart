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
  final int tursonuc;
  final bool isLowestWins;

  // ✅ YENİ: Grup kimliği (Gizlilik ve güvenlik için)
  final String? grupId;

  const Turnuva({
    required this.id,
    this.numara,
    required this.sezonId,
    this.turTarih,
    this.turKazanan,
    this.turIkinci,
    this.turUcuncu,
    this.turKaybeden,
    required this.tursonuc,
    this.isLowestWins = true,
    this.grupId,
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
      tursonuc: (data['tursonuc'] as num?)?.toInt() ?? 0,
      isLowestWins: data['isLowestWins'] ?? true,
      grupId: data['grupId']?.toString(), // ✅ OKU
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
    'grupId': grupId, // ✅ KAYDET
  };
}
