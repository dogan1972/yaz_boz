// lib/services/turnuva_servisi.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  // ✅ YENİ TURNUVA OLUŞTURMA (HATA YÖNETİMİ EKLENDİ - LOADING SORUNU ÇÖZÜLDÜ)
  Future<String> yeniTurnuvaOlustur({
    required String sezonId,
    required String turTarih,
    required bool isLowestWins,
  }) async {
    try {
      final k = await AuthService().profilGarantile();
      if (k == null || k.grupId == null) throw Exception('Grup bilgisi eksik.');

      // Numaratör İşlemi
      final numaraRef = _fs
          .collection('metadata')
          .doc('turnuva_numarasi_${k.grupId}');
      int yeniNumara = 1;

      await _fs.runTransaction((tx) async {
        final doc = await tx.get(numaraRef);
        if (doc.exists) {
          final current = (doc.data()?['son_numara'] ?? 0) as int;
          yeniNumara = current + 1;
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
        'aktifMi': true,
      });

      return ref.id;
    } catch (e) {
      if (kDebugMode) print("❌ Turnuva oluşturma hatası: $e");
      rethrow; // Hatayı UI'a fırlat ki snackbar gösterebilsin
    }
  }

  // ✅ TURNUVA SONLANDIRMA HAZIRLIK
  Future<Map<String, dynamic>> turnuvayiSonlandirHazirla(
    String turnuvaId,
  ) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('turnuva').doc(turnuvaId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu turnuvayı sonlandırma yetkiniz yok.');
    }

    final oyunSnap = await _fs
        .collection('oyunlar')
        .where('turId', isEqualTo: turnuvaId)
        .where('grupId', isEqualTo: k?.grupId)
        .get();

    return {'toplamOyun': oyunSnap.docs.length, 'turnuvaData': doc.data()};
  }

  // ✅✅ GÜNCELLENDİ: AKTİF OYUN VARSA BİLE SONLANDIRABİLİR ✅✅
  Future<void> turnuvayiSonlandir(
    String turnuvaId,
    String sampiyonAd,
    String? sonuncuAd,
  ) async {
    try {
      final k = await AuthService().profilGarantile();
      final doc = await _fs.collection('turnuva').doc(turnuvaId).get();

      if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
        throw Exception('Yetkisiz işlem.');
      }

      final grupId = k!.grupId!;
      final batch = _fs.batch();

      // 1. AÇIK OYUNLARI BUL VE SONLANDIR
      final acikOyunlarSnap = await _fs
          .collection('oyunlar')
          .where('turId', isEqualTo: turnuvaId)
          .where('grupId', isEqualTo: grupId)
          .where('oyunKazanan', isEqualTo: null)
          .get();

      for (var oDoc in acikOyunlarSnap.docs) {
        final oyunData = oDoc.data();
        final oyunId = oDoc.id;

        // El var mı kontrol et
        final ellerSnap = await _fs
            .collection('eller')
            .where('oyunId', isEqualTo: oyunId)
            .where('grupId', isEqualTo: grupId)
            .limit(1)
            .get();

        if (ellerSnap.docs.isNotEmpty) {
          // EL VARSA: Skor hesapla ve kazananı bul
          final tumEller = await _fs
              .collection('eller')
              .where('oyunId', isEqualTo: oyunId)
              .where('grupId', isEqualTo: grupId)
              .get();

          List<String> oyuncuIsimleri =
              (oyunData['oyuncu'] as String?)
                  ?.split(', ')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              [];
          List<String>? oyuncuUidListesi = (oyunData['oyuncuIds'] as List?)
              ?.map((e) => e.toString())
              .toList();

          Map<String, String> uidToNameMap = {};
          if (oyuncuUidListesi != null &&
              oyuncuUidListesi.length == oyuncuIsimleri.length) {
            for (int i = 0; i < oyuncuUidListesi.length; i++) {
              uidToNameMap[oyuncuUidListesi[i]] = oyuncuIsimleri[i];
            }
          }

          Map<String, int> puanlar = {};
          for (var isim in oyuncuIsimleri) {
            puanlar[isim] = 0;
          }

          bool isLowestWins =
              oyunData['yuksekSkorKazanir'] == false ||
              oyunData['yuksekSkorKazanir'] == 0;

          for (var elDoc in tumEller.docs) {
            final elData = elDoc.data();
            final skorlar = elData['skorlar'] as Map?;
            if (skorlar is Map) {
              skorlar.forEach((uidKey, skorVal) {
                final s = (skorVal is num)
                    ? skorVal.toInt()
                    : (int.tryParse(skorVal.toString()) ?? 0);
                String hedefIsim =
                    uidToNameMap[uidKey.toString()] ?? uidKey.toString();
                if (puanlar.containsKey(hedefIsim)) {
                  puanlar[hedefIsim] = (puanlar[hedefIsim] ?? 0) + s;
                }
              });
            }
          }

          var sirali = puanlar.entries.toList();
          sirali.sort(
            (a, b) => isLowestWins
                ? a.value.compareTo(b.value)
                : b.value.compareTo(a.value),
          );

          String kazanan = sirali.isNotEmpty ? sirali.first.key : '';
          String kaybeden = sirali.length > 1 ? sirali.last.key : '';

          String? kazananUid = uidToNameMap.entries
              .firstWhere(
                (e) => e.value == kazanan,
                orElse: () => MapEntry('', ''),
              )
              .key;
          String? kaybedenUid = uidToNameMap.entries
              .firstWhere(
                (e) => e.value == kaybeden,
                orElse: () => MapEntry('', ''),
              )
              .key;

          batch.update(oDoc.reference, {
            'oyunKazanan': kazanan,
            'oyunKaybeden': kaybeden,
            'oyunKazananUid': kazananUid,
            'oyunKaybedenUid': kaybedenUid,
            'bitisTarihi': FieldValue.serverTimestamp(),
            'aktifMi': false,
          });
        } else {
          // EL YOKSA: Sadece kapat
          batch.update(oDoc.reference, {
            'aktifMi': false,
            'bitisTarihi': FieldValue.serverTimestamp(),
          });
        }
      }

      // 2. ŞAMPİYONU BELİRLE (En çok oyunu kazanan)
      final tumOyunlarSnap = await _fs
          .collection('oyunlar')
          .where('turId', isEqualTo: turnuvaId)
          .where('grupId', isEqualTo: grupId)
          .get();
      Map<String, int> kazanmaSayisi = {};
      Map<String, String> uidToNameGlobal = {};

      for (var oDoc in tumOyunlarSnap.docs) {
        final data = oDoc.data();
        final kUid = data['oyunKazananUid']?.toString();
        if (kUid != null && kUid.isNotEmpty) {
          kazanmaSayisi[kUid] = (kazanmaSayisi[kUid] ?? 0) + 1;
          // İsim eşleşmesi
          final oList = (data['oyuncu'] as String?)?.split(', ') ?? [];
          final uList =
              (data['oyuncuIds'] as List?)?.map((e) => e.toString()).toList() ??
              [];
          for (int i = 0; i < uList.length && i < oList.length; i++) {
            if (uList[i] == kUid) uidToNameGlobal[kUid] = oList[i];
          }
        }
      }

      String enCokKazananUid = '';
      int maxWin = 0;
      kazanmaSayisi.forEach((uid, adet) {
        if (adet > maxWin) {
          maxWin = adet;
          enCokKazananUid = uid;
        }
      });

      String finalSampiyon = uidToNameGlobal[enCokKazananUid] ?? sampiyonAd;

      // 3. TURNUVAYI KAPAT
      batch.update(_fs.collection('turnuva').doc(turnuvaId), {
        'turKazanan': finalSampiyon,
        'turKaybeden': sonuncuAd ?? '-',
        'tursonuc': 1,
        'bitisTarihi': FieldValue.serverTimestamp(),
        'aktifMi': false,
      });

      await batch.commit();
    } catch (e) {
      if (kDebugMode) print("❌ Turnuva sonlandırma hatası: $e");
      rethrow;
    }
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

  // ✅ TURNUVA DETAY HESAPLAMA
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

  // 🔒 AKTİF TURNUVA STREAMİ
  Stream<Turnuva?> aktifTurnuvaStreami() async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      yield null;
      return;
    }

    yield* _fs
        .collection('turnuva')
        .where('grupId', isEqualTo: k.grupId)
        .where('turKazanan', isEqualTo: null)
        .where('aktifMi', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.isEmpty ? null : Turnuva.fromFirestore(snap.docs.first),
        );
  }
}
