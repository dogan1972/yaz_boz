import 'package:cloud_firestore/cloud_firestore.dart';

class Cagri {
  final String id;
  final String acanId;
  final String acanAd;
  final String durum;
  final int hedef;
  final List<String> davetliIds;
  final String? saat;
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
    this.yer,
    this.konumAd,
    this.onaylar = const [],
    this.olusturma,
  });

  bool get acik => durum == 'acik';
  bool get kilitli => durum == 'onaylandi';
  bool get detayDolu =>
      saat != null && saat!.isNotEmpty && yer != null && yer!.isNotEmpty;

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
      saat: d['saat']?.toString(),
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
        'saat': saat,
        'yer': yer,
        'konumAd': konumAd,
        'onaylar': onaylar,
        'olusturma': olusturma ?? FieldValue.serverTimestamp(),
      };
}