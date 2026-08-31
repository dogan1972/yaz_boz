// lib/models/sezon_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Sezon {
  final String id;
  final int? numara;
  final String sezonTarih;
  final String? sezonSampiyon;
  final bool isLowestWins;

  // ✅ YENİ: Grup kimliği (Gizlilik ve güvenlik için)
  final String? grupId;

  const Sezon({
    required this.id,
    this.numara,
    required this.sezonTarih,
    this.sezonSampiyon,
    this.isLowestWins = true,
    this.grupId,
  });

  factory Sezon.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Sezon(
      id: doc.id,
      numara: (data['numara'] as num?)?.toInt(),
      sezonTarih: data['sezonTarih']?.toString() ?? '',
      sezonSampiyon: data['sezonSampiyon']?.toString(),
      isLowestWins: data['isLowestWins'] ?? true,
      grupId: data['grupId']?.toString(), // ✅ OKU
    );
  }

  Map<String, dynamic> toMap() => {
    'numara': numara,
    'sezonTarih': sezonTarih,
    'sezonSampiyon': sezonSampiyon,
    'isLowestWins': isLowestWins,
    'grupId': grupId, // ✅ KAYDET
  };
}

class OyuncuSezonIstatistigi {
  final String ad;
  int trvKazanma = 0;
  int trvKatilim = 0;
  int oyunGalibiyet = 0;
  double enIyiElSkoru;

  OyuncuSezonIstatistigi(this.ad, {required bool isLowestWins})
    : enIyiElSkoru = isLowestWins ? double.infinity : double.negativeInfinity;
}
