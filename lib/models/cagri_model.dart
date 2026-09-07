// lib/models/cagri_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Cagri {
  final String id;
  final String acanId;
  final String acanAd;
  final String durum;

  // ✅ YENİ: davetliIds artık ÇAĞIRICI DAHİL TÜM KATILIMCILARI içerir
  final List<String> davetliIds;

  final String? saat;
  final String? tarih;
  final String? yer;
  final String? konumAd;

  // ✅ onaylar listesi de çağrıcı dahil, otomatik onaylı başlar
  final List<String> onaylar;

  final Timestamp? olusturma;

  const Cagri({
    required this.id,
    required this.acanId,
    required this.acanAd,
    required this.durum,
    required this.davetliIds,
    this.saat,
    this.tarih,
    this.yer,
    this.konumAd,
    this.onaylar = const [],
    this.olusturma,
  });

  // ✅ HEDEF: Artık ayrı alan değil, davetliIds.length'den hesaplanır
  int get hedef => davetliIds.length;

  String get adlandirmaTarihi {
    if (tarih != null && tarih!.isNotEmpty) return tarih!;
    if (olusturma != null) {
      return DateFormat('dd.MM.yyyy').format(olusturma!.toDate());
    }
    return DateFormat('dd.MM.yyyy').format(DateTime.now());
  }

  bool get acik => durum == 'acik';
  bool get kilitli => durum == 'onaylandi';

  bool get detayDolu =>
      (saat != null && saat!.isNotEmpty ||
          tarih != null && tarih!.isNotEmpty) &&
      yer != null &&
      yer!.isNotEmpty;

  // ✅ SIFIR MATEMATİK: Direkt length
  int get onaySayisi => onaylar.length;
  bool get herkesOnayladi => onaylar.length >= 4 || onaylar.length >= hedef;

  factory Cagri.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    List<String> liste(dynamic raw) =>
        raw is List ? raw.map((e) => e.toString()).toList() : const [];

    return Cagri(
      id: doc.id,
      acanId: d['acanId']?.toString() ?? '',
      acanAd: d['acanAd']?.toString() ?? '',
      durum: d['durum']?.toString() ?? 'acik',
      davetliIds: liste(d['davetliIds']),
      saat: d['saat']?.toString(),
      tarih: d['tarih']?.toString(),
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
    'davetliIds': davetliIds,
    'saat': saat,
    'tarih': tarih,
    'yer': yer,
    'konumAd': konumAd,
    'onaylar': onaylar,
    'olusturma': olusturma ?? FieldValue.serverTimestamp(),
  };
}
