import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
// KULLANICI — gerçek insan (Auth uid'li). Masadaki 'oyuncular'dan ayrı.
// ─────────────────────────────────────────────────────────────
class Kullanici {
  final String uid;
  final String nick;
  final String email;
  final String davetKodu; // 6 haneli benzersiz, "YB7K2Q" gibi
  final String qrPayload; // "yazboz://arkadas/<davetKodu>"
  final List<String> arkadasIds;
  final Timestamp? olusturma;

  const Kullanici({
    required this.uid,
    required this.nick,
    required this.email,
    required this.davetKodu,
    required this.qrPayload,
    this.arkadasIds = const [],
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
      arkadasIds: rawArk is List
          ? rawArk.map((e) => e.toString()).toList()
          : const [],
      olusturma: d['olusturma'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nick': nick,
    'email': email,
    'davetKodu': davetKodu,
    'qrPayload': qrPayload,
    'arkadasIds': arkadasIds,
    'olusturma': olusturma ?? FieldValue.serverTimestamp(),
  };
}
