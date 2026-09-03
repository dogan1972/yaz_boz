// lib/services/oyun_servisi.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/oyun_model.dart';
import 'package:yaz_boz/services/auth_service.dart';

class OyunServisi {
  static final OyunServisi _instance = OyunServisi._internal();
  factory OyunServisi() => _instance;
  OyunServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // 🔒 GRUP FİLTRELİ STREAM
  Stream<List<Oyun>> tumOyunlarStreami() async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      yield [];
      return;
    }

    yield* _fs
        .collection('oyunlar')
        .where('grupId', isEqualTo: k.grupId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((d) => Oyun.fromFirestore(d)).toList();
        });
  }

  Future<String> yeniOyunOlustur({
    required String turId,
    required String oyunTarih,
    required int elSayisi,
    required int oyuncuSayisi,
    required String oyuncular,
    required List<String> oyuncuIds,
    required bool esliMi,
    required bool yuksekSkorKazanir,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Kullanıcı profili veya grup bilgisi bulunamadı.');
    }

    // ✅ GÜNCELLENDİ: AKTİF Mİ KONTROLÜ EKLENDİ
    final turDoc = await _fs.collection('turnuva').doc(turId).get();
    if (!turDoc.exists || turDoc.data()?['grupId'] != k.grupId) {
      throw Exception('Geçersiz veya yetkisiz turnuva.');
    }

    // Hem turKazanan hem de aktifMi kontrolü yapılır
    final turData = turDoc.data() ?? {};
    final bool isFinished = turData['turKazanan'] != null;
    final bool isActive = turData['aktifMi'] == true;

    if (isFinished || !isActive) {
      throw Exception(
        isFinished
            ? 'Bu turnuva zaten sonlandırılmış. Yeni oyun eklenemez.'
            : 'Bu turnuva pasif durumda. Lütfen aktif bir turnuva seçin.',
      );
    }

    // ✅ DEĞİŞİKLİK: Grup bazlı numaratör (metadata > oyun_numarasi_{grupId})
    final numaraRef = _fs
        .collection('metadata')
        .doc('oyun_numarasi_${k.grupId}');
    int yeniNumara = 1;

    await _fs.runTransaction((tx) async {
      final doc = await tx.get(numaraRef);
      if (doc.exists) {
        yeniNumara = (doc.data()?['son_numara'] ?? 0) + 1;
        tx.update(numaraRef, {'son_numara': yeniNumara});
      } else {
        tx.set(numaraRef, {'son_numara': 1});
      }
    });

    final ref = _fs.collection('oyunlar').doc();
    await ref.set({
      'numara': yeniNumara, // ✅ Oyunun kendi içinde de numara görünür
      'turId': turId,
      'oyunTarih': oyunTarih,
      'elSayisi': elSayisi,
      'oyuncuSayisi': oyuncuSayisi,
      'oyuncu': oyuncular,
      'oyuncuIds': oyuncuIds,
      'esliMi': esliMi ? 1 : 0,
      'yuksekSkorKazanir': yuksekSkorKazanir ? 1 : 0,
      'grupId': k.grupId,
      'olusturma': FieldValue.serverTimestamp(),
      'aktifMi': true,
    });
    return ref.id;
  }

  // ✅ OYUN SONLANDIRMA (UID DESTEKLİ + AKTİF Mİ GÜNCELLEMESİ)
  Future<void> oyunuSonlandir(
    String oyunId,
    String kazananIsim,
    String kaybedenIsim,
    String? ikinciIsim,
    String? ucuncuIsim,
    String? kazananUid,
    String? kaybedenUid,
  ) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('oyunlar').doc(oyunId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu oyunu sonlandırma yetkiniz yok.');
    }

    await _fs.collection('oyunlar').doc(oyunId).update({
      'oyunKazanan': kazananIsim,
      'oyunKaybeden': kaybedenIsim,
      'oyunIkinci': ikinciIsim,
      'oyunUcuncu': ucuncuIsim,

      'oyunKazananUid': kazananUid,
      'oyunKaybedenUid': kaybedenUid,

      'bitisTarihi': FieldValue.serverTimestamp(),
      'aktifMi': false, // ✅ Oyun bitince otomatik pasife alınır
    });
  }

  // ✅ ZİNCİRLEME SİLME
  Future<void> oyunuSil(String oyunId) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('oyunlar').doc(oyunId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu oyunu silme yetkiniz yok.');
    }

    final batch = _fs.batch();

    final elSnap = await _fs
        .collection('eller')
        .where('oyunId', isEqualTo: oyunId)
        .where('grupId', isEqualTo: k?.grupId)
        .get();

    for (var eDoc in elSnap.docs) {
      batch.delete(eDoc.reference);
    }

    batch.delete(_fs.collection('oyunlar').doc(oyunId));
    await batch.commit();
  }

  // ✅ OYUN ELLERİNİ GETİR
  Future<QuerySnapshot> oyunElleriniGetir(String oyunId) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }

    return await _fs
        .collection('eller')
        .where('oyunId', isEqualTo: oyunId)
        .where('grupId', isEqualTo: k.grupId)
        .get();
  }

  // ✅ TÜM OYUNCULARI GETİR
  Future<List<Oyuncu>> tumOyunculariGetir() async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) return [];

    final userDoc = await _fs.collection('kullanicilar').doc(k.uid).get();
    if (!userDoc.exists) return [];

    final userData = userDoc.data() ?? {};
    final arkadasIds = List<String>.from(userData['arkadasIds'] ?? []);
    final kendiAd =
        userData['nick']?.toString() ??
        userData['adSoyad']?.toString() ??
        'Ben';

    final oyuncular = <Oyuncu>[Oyuncu(id: k.uid, oyuncuAdSoyad: kendiAd)];

    if (arkadasIds.isNotEmpty) {
      final snap = await _fs
          .collection('kullanicilar')
          .where(FieldPath.documentId, whereIn: arkadasIds)
          .where('grupId', isEqualTo: k.grupId)
          .get();

      for (final d in snap.docs) {
        final data = d.data();
        oyuncular.add(
          Oyuncu(
            id: d.id,
            oyuncuAdSoyad: data['nick']?.toString() ?? 'Bilinmeyen',
          ),
        );
      }
    }

    return oyuncular;
  }

  Future<void> oyunuGuncelle(String id, Map<String, dynamic> data) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('oyunlar').doc(id).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu oyunda değişiklik yapma yetkiniz yok.');
    }

    await _fs.collection('oyunlar').doc(id).update(data);
  }

  // 🔒 AKTİF OYUN BULMA (GÜNCELLENDİ: aktifMi KONTROLÜ EKLENDİ)
  Future<Oyun?> aktifOyunBul() async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) return null;

    final snap = await _fs
        .collection('oyunlar')
        .where('grupId', isEqualTo: k.grupId)
        .where('oyunKazanan', isEqualTo: null)
        .where(
          'aktifMi',
          isEqualTo: true,
        ) // ✅ Sadece gerçekten aktif olanları getir
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Oyun.fromFirestore(snap.docs.first);
  }

  // 🔒 TEK OYUN GETİR
  Future<Oyun?> oyunGetir(String oyunId) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) return null;

    final doc = await _fs.collection('oyunlar').doc(oyunId).get();
    if (!doc.exists || doc.data()?['grupId'] != k.grupId) return null;

    return Oyun.fromFirestore(doc);
  }
}
