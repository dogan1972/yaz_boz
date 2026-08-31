// lib/services/sezon_servisi.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/sezon_model.dart';
import 'package:yaz_boz/services/auth_service.dart';

class SezonServisi {
  static final SezonServisi _instance = SezonServisi._internal();
  factory SezonServisi() => _instance;
  SezonServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // 🔒 GRUP FİLTRELİ STREAM
  Stream<List<Sezon>> tumSezonlarStreami() async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      yield [];
      return;
    }

    yield* _fs
        .collection('sezonlar')
        .where('grupId', isEqualTo: k.grupId)
        .snapshots()
        .map((snapshot) {
          final liste = snapshot.docs
              .map((d) => Sezon.fromFirestore(d))
              .toList();
          liste.sort((a, b) => b.sezonTarih.compareTo(a.sezonTarih));
          return liste;
        });
  }

  // 🔒 AKTİF SEZON BULMA
  Future<Sezon?> aktifSezonBul() async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) return null;

    final snap = await _fs
        .collection('sezonlar')
        .where('grupId', isEqualTo: k.grupId)
        .where('sezonSampiyon', isEqualTo: null)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Sezon.fromFirestore(snap.docs.first);
  }

  // ✅ YENİ SEZON OLUŞTURMA
  Future<String> yeniSezonOlustur({
    required String tarih,
    required bool isLowestWins,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null) throw Exception('Kullanıcı profili bulunamadı.');

    final numaraRef = _fs
        .collection('gruplar')
        .doc(k.grupId!)
        .collection('numarator')
        .doc('sezon');
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

    final ref = _fs.collection('sezonlar').doc();
    await ref.set({
      'numara': yeniNumara,
      'sezonTarih': tarih,
      'sezonSampiyon': null,
      'isLowestWins': isLowestWins,
      'grupId': k.grupId,
      'olusturma': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ✅ BOŞ SEZON KONTROLÜ
  Future<Map<String, dynamic>> sezonuSonlandirHazirla(String sezonId) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('sezonlar').doc(sezonId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu sezonu sonlandırma yetkiniz yok.');
    }

    final turnuvaSnap = await _fs
        .collection('turnuva')
        .where('sezonId', isEqualTo: sezonId)
        .where('grupId', isEqualTo: k?.grupId)
        .get();

    int toplamOyun = 0;
    for (var tDoc in turnuvaSnap.docs) {
      final oyunSnap = await _fs
          .collection('oyunlar')
          .where('turId', isEqualTo: tDoc.id)
          .where('grupId', isEqualTo: k?.grupId)
          .get();
      toplamOyun += oyunSnap.docs.length;
    }

    return {'toplamOyun': toplamOyun, 'sezonData': doc.data()};
  }

  // ✅ SEZON SONLANDIRMA
  Future<void> sezonuSonlandir(String sezonId, String sampiyonAd) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('sezonlar').doc(sezonId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu sezonu sonlandırma yetkiniz yok.');
    }

    await _fs.collection('sezonlar').doc(sezonId).update({
      'sezonSampiyon': sampiyonAd,
      'bitisTarihi': FieldValue.serverTimestamp(),
    });
  }

  // ✅ SEZON GÜNCELLEME
  Future<void> sezonuGuncelle(String id, Map<String, dynamic> data) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('sezonlar').doc(id).get();
    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu sezonda değişiklik yapma yetkiniz yok.');
    }
    await _fs.collection('sezonlar').doc(id).update(data);
  }

  // ✅ ZİNCİRLEME SİLME
  Future<void> sezonuSil(String sezonId) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('sezonlar').doc(sezonId).get();
    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu sezonu silme yetkiniz yok.');
    }

    final batch = _fs.batch();
    final turnuvaSnap = await _fs
        .collection('turnuva')
        .where('sezonId', isEqualTo: sezonId)
        .where('grupId', isEqualTo: k?.grupId)
        .get();

    for (var tDoc in turnuvaSnap.docs) {
      final oyunSnap = await _fs
          .collection('oyunlar')
          .where('turId', isEqualTo: tDoc.id)
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
      batch.delete(tDoc.reference);
    }
    batch.delete(_fs.collection('sezonlar').doc(sezonId));
    await batch.commit();
  }

  // ✅ UID BAZLI DETAYLI İSTATİSTİK HESAPLAMA
  Future<Map<String, dynamic>> sezonIstatistikHesapla(String sezonId) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }

    final grupId = k.grupId!;
    final sezonDoc = await _fs.collection('sezonlar').doc(sezonId).get();
    if (!sezonDoc.exists) throw Exception('Sezon bulunamadı.');

    final sezonData = sezonDoc.data() as Map<String, dynamic>;
    final bool isLowestWins = sezonData['isLowestWins'] ?? true;

    final turnuvaSnap = await _fs
        .collection('turnuva')
        .where('sezonId', isEqualTo: sezonId)
        .where('grupId', isEqualTo: grupId)
        .get();

    final sezonTurnuvalari = turnuvaSnap.docs;

    if (sezonTurnuvalari.isEmpty) {
      return {
        'toplamOyun': 0,
        'enCokKazanan': 'Veri Yok',
        'enCokYenilen': 'Veri Yok',
        'baslangicTarihi': '-',
        'bitisTarihi': '-',
        'enIyiSkor': '-',
        'enKotuSkor': '-',
        'oyuncuIstatistikleri': <OyuncuDetayIstatistik>[],
        'isLowestWins': isLowestWins,
      };
    }

    final turIds = sezonTurnuvalari.map((d) => d.id).toSet().toList();
    List<DocumentSnapshot> sezonOyunlari = [];
    Set<String> sezonOyunIdSet = {};

    if (turIds.isNotEmpty) {
      final oyunlarSnap = await _fs
          .collection('oyunlar')
          .where('turId', whereIn: turIds)
          .where('grupId', isEqualTo: grupId)
          .get();
      sezonOyunlari = oyunlarSnap.docs;
      sezonOyunIdSet = sezonOyunlari.map((d) => d.id).toSet();
    }

    int toplamOyun = sezonOyunlari.length;

    // ✅ UID BAZLI SAYIM HARİTALARI
    Map<String, int> oynadigiOyunMap = {};
    Map<String, int> kazandigiOyunMap = {};
    Map<String, int> kaybettigiOyunMap = {};
    Set<String> tumOyuncuUids = {};

    for (var oyunDoc in sezonOyunlari) {
      final data = oyunDoc.data() as Map<String, dynamic>? ?? {};

      // ✅ YENİ ALAN ADLARI: oyuncuIds ve oyunKaybedenUid
      final List<dynamic>? oyuncuUidListesi =
          data['oyuncuIds'] as List<dynamic>?;
      final String kaybedenUid =
          data['oyunKaybedenUid']?.toString().trim() ?? '';

      if (oyuncuUidListesi != null) {
        for (var uid in oyuncuUidListesi) {
          final u = uid.toString().trim();
          if (u.isNotEmpty) {
            tumOyuncuUids.add(u);
            oynadigiOyunMap[u] = (oynadigiOyunMap[u] ?? 0) + 1;

            if (kaybedenUid.isNotEmpty && u == kaybedenUid) {
              kaybettigiOyunMap[u] = (kaybettigiOyunMap[u] ?? 0) + 1;
            } else {
              // Kaybeden dışındakiler kazanmış sayılır
              kazandigiOyunMap[u] = (kazandigiOyunMap[u] ?? 0) + 1;
            }
          }
        }
      }
    }

    // ✅ TEK SORGUDA TÜM OYUNCU BİLGİLERİNİ ÇEK (UID -> İsim Eşleştirme)
    Map<String, String> uidToNameMap = {};
    if (tumOyuncuUids.isNotEmpty) {
      // Firestore whereIn limiti 30'dur. Batch işlemi gerekebilir.
      final uidList = tumOyuncuUids.take(30).toList();
      final usersSnap = await _fs
          .collection('kullanicilar')
          .where(FieldPath.documentId, whereIn: uidList)
          .get();

      for (var uDoc in usersSnap.docs) {
        final uData = uDoc.data();
        // Önce nick'e, yoksa adSoyad'a bak
        uidToNameMap[uDoc.id] =
            (uData['nick'] ?? uData['adSoyad'] ?? 'Bilinmeyen').toString();
      }
    }

    double enIyiSkorDeger = isLowestWins
        ? double.infinity
        : double.negativeInfinity;
    double enKotuSkorDeger = isLowestWins
        ? double.negativeInfinity
        : double.infinity;
    String enIyiSkorUid = "", enKotuSkorUid = "";
    String baslangicTarihi = "-", bitisTarihi = "-";

    if (sezonOyunIdSet.isNotEmpty) {
      final ellerSnap = await _fs
          .collection('eller')
          .where('oyunId', whereIn: sezonOyunIdSet.toList())
          .where('grupId', isEqualTo: grupId)
          .get();
      for (var elDoc in ellerSnap.docs) {
        final elData = elDoc.data() as Map<String, dynamic>? ?? {};
        final tarih = elData['elTarih']?.toString();
        if (tarih != null && tarih.isNotEmpty) {
          final tStr = tarih.length >= 10 ? tarih.substring(0, 10) : tarih;
          if (baslangicTarihi == "-" || tStr.compareTo(baslangicTarihi) < 0) {
            baslangicTarihi = tStr;
          }
          if (bitisTarihi == "-" || tStr.compareTo(bitisTarihi) > 0) {
            bitisTarihi = tStr;
          }
        }

        // Skorları da UID bazlı işliyoruz
        final skorlar = elData['skorlar'];
        if (skorlar is Map) {
          skorlar.forEach((uid, skor) {
            final v = (skor is num)
                ? skor.toDouble()
                : (double.tryParse(skor.toString()) ?? 0.0);
            final u = uid.toString().trim();
            if (isLowestWins) {
              if (v < enIyiSkorDeger) {
                enIyiSkorDeger = v;
                enIyiSkorUid = u;
              }
              if (v > enKotuSkorDeger) {
                enKotuSkorDeger = v;
                enKotuSkorUid = u;
              }
            } else {
              if (v > enIyiSkorDeger) {
                enIyiSkorDeger = v;
                enIyiSkorUid = u;
              }
              if (v < enKotuSkorDeger) {
                enKotuSkorDeger = v;
                enKotuSkorUid = u;
              }
            }
          });
        }
      }
    }

    // ✅ LİSTEYİ UID'DEN İSME ÇEVİREREK OLUŞTUR
    List<OyuncuDetayIstatistik> oyuncuListesi = [];
    for (var uid in tumOyuncuUids) {
      final isim = uidToNameMap[uid] ?? uid; // İsim bulunamazsa UID göster
      oyuncuListesi.add(
        OyuncuDetayIstatistik(
          oyuncuAdi: isim,
          oynadigiOyun: oynadigiOyunMap[uid] ?? 0,
          kazandigiOyun: kazandigiOyunMap[uid] ?? 0,
          kaybettigiOyun: kaybettigiOyunMap[uid] ?? 0,
        ),
      );
    }
    oyuncuListesi.sort((a, b) => b.kazandigiOyun.compareTo(a.kazandigiOyun));

    String formatSkor(String uid, double skor) {
      final isim = uidToNameMap[uid];
      return (isim != null && isim.isNotEmpty)
          ? "$isim (${skor.toStringAsFixed(0)})"
          : "Veri Yok";
    }

    String getTopUid(Map<String, int> map) {
      if (map.isEmpty) return '';
      return map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return {
      'toplamOyun': toplamOyun,
      'enCokKazanan': kazandigiOyunMap.isNotEmpty
          ? "${uidToNameMap[getTopUid(kazandigiOyunMap)] ?? '?'} (${kazandigiOyunMap[getTopUid(kazandigiOyunMap)]} Gal.)"
          : 'Veri Yok',
      'enCokYenilen': kaybettigiOyunMap.isNotEmpty
          ? "${uidToNameMap[getTopUid(kaybettigiOyunMap)] ?? '?'} (${kaybettigiOyunMap[getTopUid(kaybettigiOyunMap)]} Yen.)"
          : 'Veri Yok',
      'baslangicTarihi': baslangicTarihi,
      'bitisTarihi': bitisTarihi,
      'enIyiSkor': formatSkor(enIyiSkorUid, enIyiSkorDeger),
      'enKotuSkor': formatSkor(enKotuSkorUid, enKotuSkorDeger),
      'oyuncuIstatistikleri': oyuncuListesi,
      'isLowestWins': isLowestWins,
    };
  }
}

class OyuncuDetayIstatistik {
  final String oyuncuAdi;
  final int oynadigiOyun, kazandigiOyun, kaybettigiOyun;
  OyuncuDetayIstatistik({
    required this.oyuncuAdi,
    required this.oynadigiOyun,
    required this.kazandigiOyun,
    required this.kaybettigiOyun,
  });
}
