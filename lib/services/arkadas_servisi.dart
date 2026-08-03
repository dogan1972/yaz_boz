import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────
// ARKADAŞLIK İSTEĞİ — belge modeli (varlığı = bekliyor)
// ─────────────────────────────────────────────────────────────
class ArkadaslikIstegi {
  final String id;
  final String gonderen;
  final String alan;
  final Timestamp? olusturma;

  const ArkadaslikIstegi({
    required this.id,
    required this.gonderen,
    required this.alan,
    this.olusturma,
  });

  factory ArkadaslikIstegi.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ArkadaslikIstegi(
      id: doc.id,
      gonderen: d['gonderen']?.toString() ?? '',
      alan: d['alan']?.toString() ?? '',
      olusturma: d['olusturma'] as Timestamp?,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ARKADAŞ SERVİSİ — Singleton
//   • istek gönder (mükerrer + zaten-arkadaş kalkanlı)
//   • gelen / giden istek stream'leri (tek alan sorgusu → index derdi yok)
//   • onayla → iki tarafın listesine yaz + isteği sil
//   • reddet → isteği sil (iz bırakmaz)
// ─────────────────────────────────────────────────────────────
class ArkadasServisi {
  static final ArkadasServisi _instance = ArkadasServisi._internal();
  factory ArkadasServisi() => _instance;
  ArkadasServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static const String _kol = 'istekler';
  static const String _kullanicilar = 'kullanicilar';

  /// İstek gönder. Kendine / zaten arkadaşa / mükerrer bekleyene atılmaz.
  Future<void> istekGonder(String gonderen, String alan) async {
    if (gonderen == alan) return;

    // 1) zaten arkadaş mı?
    final benSnap = await _fs.collection(_kullanicilar).doc(gonderen).get();
    if (benSnap.exists) {
      final raw = (benSnap.data()?['arkadasIds'] as List?) ?? const [];
      if (raw.map((e) => e.toString()).contains(alan)) return;
    }

    // 2) aynı yönde bekleyen istek var mı? (tek alan sorgusu, güvenli)
    final gidenSnap = await _fs
        .collection(_kol)
        .where('gonderen', isEqualTo: gonderen)
        .get();
    final zatenVar = gidenSnap.docs
        .map(ArkadaslikIstegi.fromDoc)
        .any((i) => i.alan == alan);
    if (zatenVar) return;

    // 3) isteği bırak
    await _fs.collection(_kol).add({
      'gonderen': gonderen,
      'alan': alan,
      'olusturma': FieldValue.serverTimestamp(),
    });
  }

  /// Bana gelen bekleyen istekler (gerçek zamanlı).
  Stream<List<ArkadaslikIstegi>> gelenIsteklerStreami(String uid) {
    return _fs
        .collection(_kol)
        .where('alan', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(ArkadaslikIstegi.fromDoc).toList()..sort((a, b) {
                final ta = a.olusturma?.millisecondsSinceEpoch ?? 0;
                final tb = b.olusturma?.millisecondsSinceEpoch ?? 0;
                return tb.compareTo(ta);
              }),
        );
  }

  /// Benim gönderdiğim bekleyen istekler ("Gönderildi ✓" için).
  Stream<List<ArkadaslikIstegi>> gidenIsteklerStreami(String uid) {
    return _fs
        .collection(_kol)
        .where('gonderen', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map(ArkadaslikIstegi.fromDoc).toList());
  }

  /// Onayla → iki tarafın listesine yaz, isteği sil.
  Future<void> istegiOnayla(
    String istekId,
    String gonderen,
    String alan,
  ) async {
    await _fs.collection(_kol).doc(istekId).delete();
    await _fs.collection(_kullanicilar).doc(gonderen).update({
      'arkadasIds': FieldValue.arrayUnion([alan]),
    });
    await _fs.collection(_kullanicilar).doc(alan).update({
      'arkadasIds': FieldValue.arrayUnion([gonderen]),
    });
  }

  /// Reddet → isteği sil (iz bırakmaz, tekrar istenebilir).
  Future<void> istegiReddet(String istekId) async {
    await _fs.collection(_kol).doc(istekId).delete();
  }
}
