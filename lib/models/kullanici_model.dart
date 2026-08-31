// lib/models/kullanici_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Kullanici {
  final String uid;
  final String nick;
  final String email;
  final String davetKodu;
  final String qrPayload;
  final String? oyuncuId;
  final List<String> arkadasIds;

  // ✅ YENİ ALANLAR: Grup Kimliği ve Grup Adı
  final String? grupId;
  final String? grupAdi;

  final Timestamp? olusturma;

  const Kullanici({
    required this.uid,
    required this.nick,
    required this.email,
    required this.davetKodu,
    required this.qrPayload,
    this.oyuncuId,
    this.arkadasIds = const [],
    this.grupId,
    this.grupAdi, // ✅ Opsiyonel
    this.olusturma,
  });

  factory Kullanici.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawArk = d['arkadasIds'];

    return Kullanici(
      uid: doc.id,
      nick: d['nick']?.toString() ?? '',
      email: d['email']?.toString() ?? '',
      davetKodu: d['davetKodu']?.toString() ?? '',
      qrPayload: d['qrPayload']?.toString() ?? '',
      oyuncuId: d['oyuncuId']?.toString() ?? doc.id,
      arkadasIds: rawArk is List
          ? rawArk.map((e) => e.toString()).toList()
          : const [],
      grupId: d['grupId']?.toString(), // ✅ OKU
      grupAdi: d['grupAdi']?.toString(), // ✅ OKU
      olusturma: d['olusturma'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nick': nick,
    'email': email,
    'davetKodu': davetKodu,
    'qrPayload': qrPayload,
    'oyuncuId': oyuncuId ?? uid,
    'arkadasIds': arkadasIds,
    'grupId': grupId, // ✅ KAYDET
    'grupAdi': grupAdi, // ✅ KAYDET
    'olusturma': olusturma ?? FieldValue.serverTimestamp(),
  };
}
