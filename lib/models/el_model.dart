// lib/models/el_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class El {
  final String id;
  final String oyunId;
  final int elNo;
  final Map<String, int> skorlar;
  final Map<String, int> gostergeMap; // Oyuncu bazlı gösterge
  final int? gosterge; // Eski kayıtlar için fallback
  final String? elTarih;

  // ✅ YENİ: Grup kimliği (Gizlilik ve güvenlik için)
  final String? grupId;

  const El({
    required this.id,
    required this.oyunId,
    required this.elNo,
    required this.skorlar,
    required this.gostergeMap,
    this.gosterge,
    this.elTarih,
    this.grupId,
  });

  factory El.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    // Skorlar map'ini güvenli parse et
    Map<String, int> parseSkor(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      );
    }

    return El(
      id: doc.id,
      oyunId: d['oyunId']?.toString() ?? '',
      elNo: (d['elNo'] as num?)?.toInt() ?? 0,
      skorlar: parseSkor(d['skorlar']),
      gostergeMap: parseSkor(d['gostergeler']),
      gosterge: (d['gosterge'] as num?)?.toInt(),
      elTarih: d['elTarih']?.toString(),
      grupId: d['grupId']?.toString(), // ✅ OKU
    );
  }

  // ✅ EKLENDİ: Firestore'a kayıt atmak için toMap metodu
  Map<String, dynamic> toMap() => {
    'oyunId': oyunId,
    'elNo': elNo,
    'skorlar': skorlar,
    'gostergeler': gostergeMap,
    'gosterge': gosterge,
    'elTarih': elTarih,
    'grupId': grupId, // ✅ KAYDET
  };
}
