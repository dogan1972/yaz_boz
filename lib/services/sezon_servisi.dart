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
        .where('aktifMi', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Sezon.fromFirestore(snap.docs.first);
  }

  // ✅ YENİ SEZON OLUŞTURMA (GRUP BAZLI METADATA NUMARATÖRÜ)
  Future<String> yeniSezonOlustur({
    required String tarih,
    required bool isLowestWins,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null) throw Exception('Kullanıcı profili bulunamadı.');

    // ✅ DEĞİŞİKLİK: Grup bazlı numaratör (metadata > sezon_numarasi_{grupId})
    final numaraRef = _fs
        .collection('metadata')
        .doc('sezon_numarasi_${k.grupId}');
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

    final ref = _fs.collection('sezonlar').doc();
    await ref.set({
      'numara': yeniNumara, // ✅ Sezonun kendi içinde de numara görünür
      'sezonTarih': tarih,
      'sezonSampiyon': null,
      'isLowestWins': isLowestWins,
      'grupId': k.grupId,
      'olusturma': FieldValue.serverTimestamp(),
      'aktifMi': true,
    });
    return ref.id;
  }

  // ✅✅ OTOMATİK ZİNCİRLEME SONLANDIRMA (DOĞRUDAN VERİ KULLANIMI) ✅✅
  Future<void> sezonuSonlandir(String sezonId, String sampiyonAd) async {
    final k = await AuthService().profilGarantile();
    final doc = await _fs.collection('sezonlar').doc(sezonId).get();

    if (!doc.exists || doc.data()?['grupId'] != k?.grupId) {
      throw Exception('Bu sezonu sonlandırma yetkiniz yok.');
    }

    final grupId = k?.grupId!;

    // 1. ADIM: Bu sezondaki TÜM AÇIK turnuvaları bul
    final acikTurnuvalarSnap = await _fs
        .collection('turnuva')
        .where('sezonId', isEqualTo: sezonId)
        .where('grupId', isEqualTo: grupId)
        .where('turKazanan', isEqualTo: null)
        .get();

    final batch = _fs.batch();

    // 2. ADIM: Her açık turnuva için altındaki oyunları kontrol et ve sonlandır
    for (var tDoc in acikTurnuvalarSnap.docs) {
      final turId = tDoc.id;

      // Turnuvaya ait AÇIK oyunları bul
      final acikOyunlarSnap = await _fs
          .collection('oyunlar')
          .where('turId', isEqualTo: turId)
          .where('grupId', isEqualTo: grupId)
          .where('oyunKazanan', isEqualTo: null)
          .get();

      // ✅ TURNUVA ŞAMPİYONU İÇİN DEĞİŞKENLER
      String turSampiyonu = '-';
      String turKaybedeni = '-';
      String turIkincisi = '-';
      String turUcuncusu = '-';

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
          // ✅ EL VARSA: Oyunu otomatik sonlandır (Skor + Gösterge + UID)

          // Tüm elleri çek
          final tumEller = await _fs
              .collection('eller')
              .where('oyunId', isEqualTo: oyunId)
              .where('grupId', isEqualTo: grupId)
              .get();

          // Oyuncu listesini ve UID haritasını hazırla
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

          // UID -> İsim Haritası Oluştur
          Map<String, String> uidToNameMap = {};
          if (oyuncuUidListesi != null &&
              oyuncuUidListesi.length == oyuncuIsimleri.length) {
            for (int i = 0; i < oyuncuUidListesi.length; i++) {
              uidToNameMap[oyuncuUidListesi[i]] = oyuncuIsimleri[i];
            }
          }

          // Puanları başlat
          Map<String, int> puanlar = {};
          for (var isim in oyuncuIsimleri) {
            puanlar[isim] = 0;
          }

          bool isLowestWins =
              oyunData['yuksekSkorKazanir'] == false ||
              oyunData['yuksekSkorKazanir'] == 0;

          // HER EL İÇİN PUAN TOPLA
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

                // Gösterge Puanını Bul
                int g = 0;
                if (gostergeler is Map && gostergeler[uidKey] != null) {
                  final gv = gostergeler[uidKey];
                  g = (gv is num)
                      ? gv.toInt()
                      : (int.tryParse(gv.toString()) ?? 0);
                } else if (tekGosterge is num) {
                  g = tekGosterge.toInt();
                }

                // UID'den isme çevir
                String hedefIsim = uidToNameMap[uidStr] ?? uidStr;

                if (puanlar.containsKey(hedefIsim)) {
                  puanlar[hedefIsim] = (puanlar[hedefIsim] ?? 0) + s + g;
                }
              });
            }
          }

          // Kazananı/Kaybedeni belirle (Sıralı Liste)
          var sirali = puanlar.entries.toList();
          sirali.sort(
            (a, b) => isLowestWins
                ? a.value.compareTo(b.value)
                : b.value.compareTo(a.value),
          );

          String kazanan = sirali.isNotEmpty ? sirali.first.key : '';
          String kaybeden = sirali.length > 1 ? sirali.last.key : '';

          // ✅ İkinci ve Üçüyü de belirle (Turnuva için gerekli olabilir)
          String ikinci = sirali.length > 2
              ? (isLowestWins ? sirali[1].key : sirali[sirali.length - 2].key)
              : '';
          String ucuncu = sirali.length > 3
              ? (isLowestWins ? sirali[2].key : sirali[sirali.length - 3].key)
              : '';

          // ✅ DÜZELTME 1: UID'leri de bulup kaydet
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

          // ✅ DÜZELTME 3: Turnuva şampiyonunu DOĞRUDAN HESAPLANAN VERİDEN AL
          // Son işlenen oyunun sonuçlarını turnuva sonucu olarak kabul ediyoruz.
          // Eğer turnuvada tek oyun varsa bu kesin doğru.
          // Eğer çok oyun varsa ve hepsi aynı anda kapanıyorsa, son dönen oyunun sonucu yazılır.
          turSampiyonu = kazanan;
          turKaybedeni = kaybeden;
          turIkincisi = ikinci;
          turUcuncusu = ucuncu;
        } else {
          //  EL YOKSA: Sadece pasife al, sonuç yazma
          batch.update(oDoc.reference, {'aktifMi': false});
        }
      }

      // ✅ TURNUVAYI GÜNCELLE (Hesaplanan değerlerle)
      batch.update(tDoc.reference, {
        'turKazanan': turSampiyonu,
        'turKaybeden': turKaybedeni,
        'turIkinci': turIkincisi,
        'turUcuncu': turUcuncusu,
        'tursonuc': 1,
        'bitisTarihi': FieldValue.serverTimestamp(),
        'aktifMi': false,
      });
    }

    // 4. ADIM: Sezonu sonlandır
    batch.update(_fs.collection('sezonlar').doc(sezonId), {
      'sezonSampiyon': sampiyonAd,
      'bitisTarihi': FieldValue.serverTimestamp(),
      'aktifMi': false,
    });

    await batch.commit();
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

  // ✅ SEZON İSTATİSTİK HESAPLAMA (SKOR AVERAJI DESTEKLİ)
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

    Map<String, int> oynadigiOyunMap = {};
    Map<String, int> kazandigiOyunMap = {};
    Map<String, int> kaybettigiOyunMap = {};
    Map<String, double> toplamSkorMap = {};
    Set<String> tumOyuncuUids = {};

    for (var oyunDoc in sezonOyunlari) {
      final data = oyunDoc.data() as Map<String, dynamic>? ?? {};
      final List<dynamic>? oyuncuUidListesi =
          data['oyuncuIds'] as List<dynamic>?;
      final String kaybedenUid =
          data['oyunKaybedenUid']?.toString().trim() ?? '';
      final bool oyunBittiMi = kaybedenUid.isNotEmpty;

      if (oyuncuUidListesi != null && oyuncuUidListesi.isNotEmpty) {
        for (var uid in oyuncuUidListesi) {
          final u = uid.toString().trim();
          if (u.isNotEmpty) {
            tumOyuncuUids.add(u);
            oynadigiOyunMap[u] = (oynadigiOyunMap[u] ?? 0) + 1;
            if (oyunBittiMi) {
              if (u == kaybedenUid) {
                kaybettigiOyunMap[u] = (kaybettigiOyunMap[u] ?? 0) + 1;
              } else {
                kazandigiOyunMap[u] = (kazandigiOyunMap[u] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    Map<String, String> uidToNameMap = {};
    if (tumOyuncuUids.isNotEmpty) {
      final uidList = tumOyuncuUids.take(30).toList();
      final usersSnap = await _fs
          .collection('kullanicilar')
          .where(FieldPath.documentId, whereIn: uidList)
          .get();
      for (var uDoc in usersSnap.docs) {
        final uData = uDoc.data();
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

        final skorlar = elData['skorlar'];
        if (skorlar is Map) {
          skorlar.forEach((uid, skor) {
            final v = (skor is num)
                ? skor.toDouble()
                : (double.tryParse(skor.toString()) ?? 0.0);
            final u = uid.toString().trim();
            toplamSkorMap[u] = (toplamSkorMap[u] ?? 0.0) + v;

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

    // ✅ DÜZELTME 2: Galibiyetler eşitse (veya 0 ise) skora göre sırala
    final sortedUids = tumOyuncuUids.toList();
    sortedUids.sort((uidA, uidB) {
      final winA = kazandigiOyunMap[uidA] ?? 0;
      final winB = kazandigiOyunMap[uidB] ?? 0;

      // Önce galibiyete bak
      if (winA != winB) return winB.compareTo(winA);

      // ✅ Galibiyetler eşitse (örn: hepsi 0 ise) toplam skora bak
      final scoreA = toplamSkorMap[uidA] ?? 0.0;
      final scoreB = toplamSkorMap[uidB] ?? 0.0;

      if (isLowestWins) {
        return scoreA.compareTo(scoreB); // Düşük skor iyi
      } else {
        return scoreB.compareTo(scoreA); // Yüksek skor iyi
      }
    });

    final List<OyuncuDetayIstatistik> finalListe = [];
    for (var uid in sortedUids) {
      final isim = uidToNameMap[uid] ?? uid;
      finalListe.add(
        OyuncuDetayIstatistik(
          oyuncuAdi: isim,
          oynadigiOyun: oynadigiOyunMap[uid] ?? 0,
          kazandigiOyun: kazandigiOyunMap[uid] ?? 0,
          kaybettigiOyun: kaybettigiOyunMap[uid] ?? 0,
        ),
      );
    }

    String formatSkor(String uid, double skor) {
      final isim = uidToNameMap[uid];
      return (isim != null && isim.isNotEmpty)
          ? "$isim (${skor.toStringAsFixed(0)})"
          : "Veri Yok";
    }

    // ✅ EN ÇOK YENİLENİ SKOR AVERAJINA GÖRE BUL
    String getTopLoserUid() {
      // Galibiyeti en az olanları filtrele
      var losers = sortedUids
          .where((uid) => (kazandigiOyunMap[uid] ?? 0) == 0)
          .toList();
      if (losers.isEmpty) {
        losers =
            sortedUids; // Hiç kimse 0 galibiyetle bitirmediyse herkesi değerlendir
      }

      losers.sort((a, b) {
        final scoreA = toplamSkorMap[a] ?? 0.0;
        final scoreB = toplamSkorMap[b] ?? 0.0;
        return isLowestWins
            ? scoreB.compareTo(scoreA) // Düşük kazanıyorsa, yüksek skor en kötü
            : scoreA.compareTo(
                scoreB,
              ); // Yüksek kazanıyorsa, düşük skor en kötü
      });
      return losers.isNotEmpty ? losers.first : '';
    }

    String enCokYenilenUid = getTopLoserUid();

    // En çok kazananı bul (Galibiyet > Skor)
    String enCokKazananUid = '';
    int maxWin = -1;
    double bestTieBreakerScore = isLowestWins
        ? double.infinity
        : double.negativeInfinity;

    for (var uid in tumOyuncuUids) {
      final wins = kazandigiOyunMap[uid] ?? 0;
      final totalScore = toplamSkorMap[uid] ?? 0.0;
      if (wins > maxWin) {
        maxWin = wins;
        enCokKazananUid = uid;
        bestTieBreakerScore = totalScore;
      } else if (wins == maxWin) {
        bool isBetter = isLowestWins
            ? (totalScore < bestTieBreakerScore)
            : (totalScore > bestTieBreakerScore);
        if (isBetter) {
          enCokKazananUid = uid;
          bestTieBreakerScore = totalScore;
        }
      }
    }

    return {
      'toplamOyun': toplamOyun,
      'enCokKazanan': enCokKazananUid.isNotEmpty
          ? "${uidToNameMap[enCokKazananUid] ?? '?'} ($maxWin Gal.)"
          : 'Veri Yok',
      'enCokYenilen': enCokYenilenUid.isNotEmpty
          ? "${uidToNameMap[enCokYenilenUid] ?? '?'} (${kaybettigiOyunMap[enCokYenilenUid] ?? 0} Yen.)"
          : 'Veri Yok',
      'baslangicTarihi': baslangicTarihi,
      'bitisTarihi': bitisTarihi,
      'enIyiSkor': formatSkor(enIyiSkorUid, enIyiSkorDeger),
      'enKotuSkor': formatSkor(enKotuSkorUid, enKotuSkorDeger),
      'oyuncuIstatistikleri': finalListe,
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
