// lib/models/cagri_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Cagri {
  final String id;
  final String acanId;
  final String acanAd;
  final String durum;
  final int hedef;
  final List<String> davetliIds;

  // ✅ SAAT KALACAK + TARİH EKLENECEK
  final String? saat;
  final String? tarih; // YENİ
  final String? yer;
  final String? konumAd;
  final List<String> onaylar;
  final Timestamp? olusturma;

  const Cagri({
    required this.id,
    required this.acanId,
    required this.acanAd,
    required this.durum,
    required this.hedef,
    required this.davetliIds,
    this.saat,
    this.tarih,
    this.yer,
    this.konumAd,
    this.onaylar = const [],
    this.olusturma,
  });

  // ✅ Otomatik adlandırma için tarih getter'ı
  String get adlandirmaTarihi {
    if (tarih != null && tarih!.isNotEmpty) return tarih!;
    if (olusturma != null) {
      return DateFormat('dd.MM.yyyy').format(olusturma!.toDate());
    }
    return DateFormat('dd.MM.yyyy').format(DateTime.now());
  }

  bool get acik => durum == 'acik';
  bool get kilitli => durum == 'onaylandi';

  // ✅ detayDolu: saat VEYA tarih doluysa true
  bool get detayDolu =>
      (saat != null && saat!.isNotEmpty ||
          tarih != null && tarih!.isNotEmpty) &&
      yer != null &&
      yer!.isNotEmpty;

  bool get herkesOnayladi =>
      davetliIds.isNotEmpty && davetliIds.every((d) => onaylar.contains(d));

  factory Cagri.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    List<String> liste(dynamic raw) =>
        raw is List ? raw.map((e) => e.toString()).toList() : const [];

    return Cagri(
      id: doc.id,
      acanId: d['acanId']?.toString() ?? '',
      acanAd: d['acanAd']?.toString() ?? '',
      durum: d['durum']?.toString() ?? 'acik',
      hedef: (d['hedef'] as num?)?.toInt() ?? 4,
      davetliIds: liste(d['davetliIds']),
      saat: d['saat']?.toString(), // ✅ KALDI
      tarih: d['tarih']?.toString(), // ✅ EKLENDİ
      yer: d['yer']?.toString(),
      konumAd: d['konumAd']?.toString(),
      onaylar: liste(d['onaylar']),
      olusturma: d['olusturma'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'acanId': acanId,
    'acanAd': acanAd,
    'durum': durum,
    'hedef': hedef,
    'davetliIds': davetliIds,
    'saat': saat, // ✅ KALDI
    'tarih': tarih, // ✅ EKLENDİ
    'yer': yer,
    'konumAd': konumAd,
    'onaylar': onaylar,
    'olusturma': olusturma ?? FieldValue.serverTimestamp(),
  };
}
