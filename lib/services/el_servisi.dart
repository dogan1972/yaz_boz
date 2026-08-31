// lib/services/el_servisi.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/el_model.dart';
import 'package:yaz_boz/services/auth_service.dart';

class ElServisi {
  static final ElServisi _instance = ElServisi._internal();
  factory ElServisi() => _instance;
  ElServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // ✅ YENİ EL OLUŞTURMA (Grup ID otomatik eklenir)
  Future<String> yeniElOlustur({
    required String oyunId,
    required int elNo,
    required Map<String, int> skorlar,
    required Map<String, int> gostergeMap,
    String? elTarih,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Kullanıcı profili veya grup bilgisi bulunamadı.');
    }

    // Oyunun bu gruba ait olduğunu kontrol et
    final oyunDoc = await _fs.collection('oyunlar').doc(oyunId).get();
    if (!oyunDoc.exists || oyunDoc.data()?['grupId'] != k.grupId) {
      throw Exception('Bu oyuna el ekleme yetkiniz yok.');
    }

    final ref = _fs.collection('eller').doc();
    await ref.set({
      'oyunId': oyunId,
      'elNo': elNo,
      'skorlar': skorlar,
      'gostergeler': gostergeMap,
      'elTarih': elTarih ?? DateTime.now().toString(),
      'grupId': k.grupId, // 🔒 OTOMATİK GRUP ATAMASI
      'olusturma': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ✅ EL GÜNCELLEME (Yetki kontrolü ile)
  Future<void> elGuncelle(String elId, Map<String, dynamic> data) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('eller').doc(elId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu eli düzenleme yetkiniz yok.');
    }

    await _fs.collection('eller').doc(elId).update(data);
  }

  // ✅ EL SİLME (Yetki kontrolü ile)
  Future<void> elSil(String elId) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('eller').doc(elId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu eli silme yetkiniz yok.');
    }

    await _fs.collection('eller').doc(elId).delete();
  }

  // ✅ GRUP FİLTRELİ STREAM: Belirli bir oyunun ellerini dinler
  Stream<List<El>> oyunElleriStreami(String oyunId) async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      yield [];
      return;
    }

    yield* _fs
        .collection('eller')
        .where('oyunId', isEqualTo: oyunId)
        .where('grupId', isEqualTo: k.grupId)
        .orderBy('elNo', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((d) => El.fromFirestore(d)).toList();
        });
  }

  // ✅ TEK EL GETİRME (Grup filtreli)
  Future<El?> elGetir(String elId) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) return null;

    final doc = await _fs.collection('eller').doc(elId).get();
    if (!doc.exists || doc.data()?['grupId'] != k.grupId) return null;

    return El.fromFirestore(doc);
  }
}
