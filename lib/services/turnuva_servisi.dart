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

  //  AKTİF TURNUVA BULMA
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

  // ✅ YENİ TURNUVA OLUŞTURMA
  Future<String> yeniTurnuvaOlustur({
    required String sezonId,
    required String turTarih,
    required bool isLowestWins,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null) throw Exception('Kullanıcı profili bulunamadı.');

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

  // ✅✅ GÜNCELLENDİ: EN ÇOK KAZANANA GÖRE ŞAMPİYON BELİRLEME ✅✅
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

    final grupId = k!.grupId!;
    final batch = _fs.batch();

    // 1. ADIM: Bu turnuvaya ait AÇIK oyunları bul ve varsa sonlandır
    final acikOyunlarSnap = await _fs
        .collection('oyunlar')
        .where('turId', isEqualTo: turnuvaId)
        .where('grupId', isEqualTo: grupId)
        .where('oyunKazanan', isEqualTo: null)
        .get();

    for (var oDoc in acikOyunlarSnap.docs) {
      final oyunData = oDoc.data();
      final oyunId = oDoc.id;

      // ⚠️ KRİTİK KOŞUL: En az 1 el girilmiş mi?
      final ellerSnap = await _fs
          .collection('eller')
          .where('oyunId', isEqualTo: oyunId)
          .where('grupId', isEqualTo: grupId)
          .limit(1)
          .get();

      if (ellerSnap.docs.isNotEmpty) {
        // ✅ EL VARSA: Oyunu normal şekilde sonlandır
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
          final gostergeler = elData['gostergeler'] as Map?;
          final tekGosterge = elData['gosterge'];

          if (skorlar is Map) {
            skorlar.forEach((uidKey, skorVal) {
              final uidStr = uidKey.toString();
              final s = (skorVal is num)
                  ? skorVal.toInt()
                  : (int.tryParse(skorVal.toString()) ?? 0);

              int g = 0;
              if (gostergeler is Map && gostergeler[uidKey] != null) {
                final gv = gostergeler[uidKey];
                g = (gv is num)
                    ? gv.toInt()
                    : (int.tryParse(gv.toString()) ?? 0);
              } else if (tekGosterge is num) {
                g = tekGosterge.toInt();
              }

              String hedefIsim = uidToNameMap[uidStr] ?? uidStr;
              if (puanlar.containsKey(hedefIsim)) {
                puanlar[hedefIsim] = (puanlar[hedefIsim] ?? 0) + s + g;
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
        // ❌ EL YOKSA: Sadece pasife al
        batch.update(oDoc.reference, {
          'aktifMi': false,
          'bitisTarihi': FieldValue.serverTimestamp(),
        });
      }
    }

    // 2. ADIM: Tüm oyunları (bitmiş olanlar dahil) tarayıp şampiyonu belirle
    final tumOyunlarSnap = await _fs
        .collection('oyunlar')
        .where('turId', isEqualTo: turnuvaId)
        .where('grupId', isEqualTo: grupId)
        .get();

    Map<String, int> kazanmaSayisi = {};
    Map<String, String> uidToNameMapGlobal = {};

    for (var oDoc in tumOyunlarSnap.docs) {
      final data = oDoc.data();
      final kazananUid = data['oyunKazananUid']?.toString();

      if (kazananUid != null && kazananUid.isNotEmpty) {
        kazanmaSayisi[kazananUid] = (kazanmaSayisi[kazananUid] ?? 0) + 1;

        // İsim haritasını güncelle (oyuncu listesinde olabilir)
        final oyuncuListesi = data['oyuncu'] as String?;
        final uidListesi = (data['oyuncuIds'] as List?)
            ?.map((e) => e.toString())
            .toList();

        if (oyuncuListesi != null && uidListesi != null) {
          final isimler = oyuncuListesi
              .split(', ')
              .map((e) => e.trim())
              .toList();
          for (int i = 0; i < uidListesi.length && i < isimler.length; i++) {
            if (uidListesi[i] == kazananUid) {
              uidToNameMapGlobal[kazananUid] = isimler[i];
            }
          }
        }
      }
    }

    // En çok kazananı bul
    String enCokKazananUid = '';
    int maxKazanma = 0;

    kazanmaSayisi.forEach((uid, adet) {
      // ✅ 'count' yerine 'adet' kullanıldı
      if (adet > maxKazanma) {
        maxKazanma = adet;
        enCokKazananUid = uid;
      }
    });

    // Eğer hiç oyun kazanılmadıysa veya veri yoksa parametredeki ismi kullan
    String finalSampiyon = uidToNameMapGlobal[enCokKazananUid] ?? sampiyonAd;

    // Kaybedeni belirlemek için (en az kazanan veya parametre)
    String finalKaybeden = sonuncuAd ?? '-';

    // 3. ADIM: Turnuvayı Güncelle
    batch.update(_fs.collection('turnuva').doc(turnuvaId), {
      'turKazanan': finalSampiyon,
      'turKaybeden': finalKaybeden,
      'tursonuc': 1,
      'bitisTarihi': FieldValue.serverTimestamp(),
      'aktifMi': false,
    });

    await batch.commit();
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
