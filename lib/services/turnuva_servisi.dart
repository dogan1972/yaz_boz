// lib/services/turnuva_servisi.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/turnuva_model.dart';
import 'package:yaz_boz/services/auth_service.dart';

class TurnuvaServisi {
  static final TurnuvaServisi _instance = TurnuvaServisi._internal();
  factory TurnuvaServisi() => _instance;
  TurnuvaServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // 🔒 GRUP FİLTRELİ STREAM
  Stream<List<Turnuva>> tumTurnuvalarStreami() async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      yield [];
      return;
    }

    yield* _fs
        .collection('turnuva')
        .where('grupId', isEqualTo: k.grupId)
        .snapshots()
        .map((snapshot) {
          final liste = snapshot.docs
              .map((d) => Turnuva.fromFirestore(d))
              .toList();
          liste.sort((a, b) => (b.turTarih ?? '').compareTo(a.turTarih ?? ''));
          return liste;
        });
  }

  // 🔒 AKTİF TURNUVA BULMA
  Future<Turnuva?> aktifTurnuvaBul() async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) return null;

    final snap = await _fs
        .collection('turnuva')
        .where('grupId', isEqualTo: k.grupId)
        .where('turKazanan', isEqualTo: null)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Turnuva.fromFirestore(snap.docs.first);
  }

  // ✅ YENİ TURNUVA OLUŞTURMA (GRUP İÇİ NUMARATÖR + BOŞ KONTROL HAZIRLIĞI)
  Future<String> yeniTurnuvaOlustur({
    required String sezonId,
    required String turTarih,
    required bool isLowestWins,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null) throw Exception('Kullanıcı profili bulunamadı.');

    // ✅ GRUP İÇİ NUMARATÖR: Her grup kendi sayacından başlar
    final numaraRef = _fs
        .collection('gruplar')
        .doc(k.grupId!)
        .collection('numarator')
        .doc('turnuva');
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

    final ref = _fs.collection('turnuva').doc();
    await ref.set({
      'numara': yeniNumara,
      'sezonId': sezonId,
      'turTarih': turTarih,
      'turKazanan': null,
      'turIkinci': null,
      'turUcuncu': null,
      'turKaybeden': null,
      'tursonuc': 0,
      'isLowestWins': isLowestWins,
      'grupId': k.grupId,
      'olusturma': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ✅ TURNUVA SONLANDIRMA (BOŞ TURNUVA UYARISI İÇİN VERİ DÖNDÜRÜR)
  Future<Map<String, dynamic>> turnuvayiSonlandirHazirla(
    String turnuvaId,
  ) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('turnuva').doc(turnuvaId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu turnuvayı sonlandırma yetkiniz yok.');
    }

    // Oyun sayısını kontrol et
    final oyunSnap = await _fs
        .collection('oyunlar')
        .where('turId', isEqualTo: turnuvaId)
        .where('grupId', isEqualTo: k?.grupId)
        .get();

    return {'toplamOyun': oyunSnap.docs.length, 'turnuvaData': doc.data()};
  }

  Future<void> turnuvayiSonlandir(
    String turnuvaId,
    String sampiyonAd,
    String? sonuncuAd,
  ) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('turnuva').doc(turnuvaId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu turnuvayı sonlandırma yetkiniz yok.');
    }

    await _fs.collection('turnuva').doc(turnuvaId).update({
      'turKazanan': sampiyonAd,
      'turKaybeden': sonuncuAd,
      'tursonuc': 1,
      'bitisTarihi': FieldValue.serverTimestamp(),
    });
  }

  // ✅ ZİNCİRLEME SİLME
  Future<void> turnuvayiSil(String turnuvaId) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('turnuva').doc(turnuvaId).get();
    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu turnuvayı silme yetkiniz yok.');
    }

    final batch = _fs.batch();
    final oyunSnap = await _fs
        .collection('oyunlar')
        .where('turId', isEqualTo: turnuvaId)
        .where('grupId', isEqualTo: k?.grupId)
        .get();

    for (var oDoc in oyunSnap.docs) {
      final elSnap = await _fs
          .collection('eller')
          .where('oyunId', isEqualTo: oDoc.id)
          .where('grupId', isEqualTo: k?.grupId)
          .get();
      for (var eDoc in elSnap.docs) {
        batch.delete(eDoc.reference);
      }
      batch.delete(oDoc.reference);
    }

    batch.delete(_fs.collection('turnuva').doc(turnuvaId));
    await batch.commit();
  }

  // ✅ TURNUVA GÜNCELLEME
  Future<void> turnuvayiGuncelle(String id, Map<String, dynamic> data) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('turnuva').doc(id).get();
    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Yetkisiz işlem.');
    }
    await _fs.collection('turnuva').doc(id).update(data);
  }

  // ✅ TURNUVA DETAY HESAPLAMA (BOŞ TURNUVA GÜVENLİĞİ EKLENDİ)
  Future<Map<String, dynamic>> turnuvaDetayHesapla(String turnuvaId) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }

    final grupId = k.grupId!;
    final turDoc = await _fs.collection('turnuva').doc(turnuvaId).get();
    if (!turDoc.exists) throw Exception('Turnuva bulunamadı.');

    final turData = turDoc.data() as Map<String, dynamic>;

    final oyunlarSnap = await _fs
        .collection('oyunlar')
        .where('turId', isEqualTo: turnuvaId)
        .where('grupId', isEqualTo: grupId)
        .get();

    final turnuvaOyunlari = oyunlarSnap.docs;
    turnuvaOyunlari.sort((a, b) {
      final ta = (a.data())['oyunTarih']?.toString() ?? '';
      final tb = (b.data())['oyunTarih']?.toString() ?? '';
      return ta.compareTo(tb);
    });

    final biten = turnuvaOyunlari
        .where((d) => (d.data())['oyunKaybeden'] != null)
        .length;

    // ✅ BOŞ TURNUVA İSTATİSTİK GÜVENLİĞİ
    if (turnuvaOyunlari.isEmpty) {
      return {
        'turData': turData,
        'oyunlar': [],
        'bitenOyun': 0,
        'toplamOyun': 0,
        'kazanan': 'Veri Yok',
        'istatistikler': <Map<String, dynamic>>[],
      };
    }

    return {
      'turData': turData,
      'oyunlar': turnuvaOyunlari,
      'bitenOyun': biten,
      'toplamOyun': turnuvaOyunlari.length,
    };
  }
}
