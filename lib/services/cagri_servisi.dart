
// lib/services/cagri_servisi.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/services/auth_service.dart';

class CagriServisi {
  static final CagriServisi _instance = CagriServisi._internal();
  factory CagriServisi() => _instance;
  CagriServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static const String _kol = 'cagrilar';

  Future<void> cagriIptalEt(String cagriId) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }
    final doc = await _fs.collection(_kol).doc(cagriId).get();
    if (!doc.exists ||
        doc.data()?['grupId'] != k.grupId ||
        doc.data()?['acanId'] != k.uid) {
      throw Exception('Bu çağrıyı iptal etme yetkiniz yok.');
    }
    await _fs.collection(_kol).doc(cagriId).update({'durum': 'iptal'});
  }

  Stream<Cagri?> acikCagriStreami(String uid) async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) yield null;
    yield* _fs
        .collection(_kol)
        .where('acanId', isEqualTo: uid)
        .where('grupId', isEqualTo: k?.grupId)
        .where('durum', isEqualTo: 'acik')
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isNotEmpty
              ? Cagri.fromFirestore(snap.docs.first)
              : null,
        );
  }

  Stream<Cagri?> davetliAcikCagriStreami(String uid) async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) yield null;
    yield* _fs
        .collection(_kol)
        .where('davetliIds', arrayContains: uid)
        .where('grupId', isEqualTo: k?.grupId)
        .where('durum', isEqualTo: 'acik')
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isNotEmpty
              ? Cagri.fromFirestore(snap.docs.first)
              : null,
        );
  }

  Stream<Cagri?> cagriStreami(String id) {
    return _fs
        .collection(_kol)
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists ? Cagri.fromFirestore(snap) : null);
  }

  Stream<List<Cagri>> son24SaatCagrilariStreami(String uid) async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      yield [];
      return;
    }
    final grupId = k.grupId!;
    late StreamController<List<Cagri>> controller;
    StreamSubscription<QuerySnapshot>? subAcan;
    StreamSubscription<QuerySnapshot>? subDavet;
    final Map<String, Cagri> birlesik = {};

    void push() {
      final liste = birlesik.values.toList()
        ..sort((a, b) {
          final aAktif = (a.durum == 'acik' || a.durum == 'onaylandi') ? 1 : 0;
          final bAktif = (b.durum == 'acik' || b.durum == 'onaylandi') ? 1 : 0;
          if (aAktif != bAktif) return bAktif.compareTo(aAktif);
          return (b.olusturma?.millisecondsSinceEpoch ?? 0).compareTo(
            a.olusturma?.millisecondsSinceEpoch ?? 0,
          );
        });
      if (!controller.isClosed) controller.add(liste);
    }

    controller = StreamController<List<Cagri>>(
      onListen: () {
        subAcan = _fs
            .collection(_kol)
            .where('acanId', isEqualTo: uid)
            .where('grupId', isEqualTo: grupId)
            .snapshots()
            .listen((snap) {
              for (final d in snap.docs) {
                final c = Cagri.fromFirestore(d);
                if (_son24Saat(c)) birlesik[d.id] = c;
              }
              push();
            });
        subDavet = _fs
            .collection(_kol)
            .where('davetliIds', arrayContains: uid)
            .where('grupId', isEqualTo: grupId)
            .snapshots()
            .listen((snap) {
              for (final d in snap.docs) {
                final c = Cagri.fromFirestore(d);
                if (_son24Saat(c)) birlesik[d.id] = c;
              }
              push();
            });
      },
      onCancel: () {
        subAcan?.cancel();
        subDavet?.cancel();
      },
    );
    yield* controller.stream;
  }

  bool _son24Saat(Cagri c) {
    final t = c.olusturma;
    if (t == null) return true;
    return DateTime.now().difference(t.toDate()).inHours < 24;
  }

  // ✅✅ GÜNCELLENDİ: uid PARAMETRESİ KULLANIMI KALDIRILDI ✅✅
  Stream<PanoVerisi> panoStreami(String uid) async* {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      yield PanoVerisi.bos();
      return;
    }
    final grupId = k.grupId!;

    Cagri? benim;
    Cagri? davet;
    late StreamController<PanoVerisi> ctrl;
    StreamSubscription<QuerySnapshot>? s1;
    StreamSubscription<QuerySnapshot>? s2;
    bool uygun(Cagri c) => c.durum == 'acik' || c.durum == 'onaylandi';

    void push() {
      if (ctrl.isClosed) return;

      if (benim != null) {
        // ✅ DÜZELTME: uid parametresi kaldırıldı
        ctrl.add(PanoVerisi.cagri(benim!, benAcan: true));
      } else if (davet != null) {
        // ✅ DÜZELTME: uid parametresi kaldırıldı
        ctrl.add(PanoVerisi.cagri(davet!, benAcan: false));
      } else {
        ctrl.add(PanoVerisi.bos());
      }
    }

    ctrl = StreamController<PanoVerisi>(
      onListen: () {
        s1 = _fs
            .collection(_kol)
            .where('acanId', isEqualTo: uid)
            .where('grupId', isEqualTo: grupId)
            .snapshots()
            .listen((snap) {
              final liste = snap.docs
                  .map(Cagri.fromFirestore)
                  .where(uygun)
                  .toList();
              benim = liste.isEmpty ? null : liste.first;
              push();
            });
        s2 = _fs
            .collection(_kol)
            .where('davetliIds', arrayContains: uid)
            .where('grupId', isEqualTo: grupId)
            .snapshots()
            .listen((snap) {
              final liste = snap.docs
                  .map(Cagri.fromFirestore)
                  .where(uygun)
                  .toList();
              davet = liste.isEmpty ? null : liste.first;
              push();
            });
      },
      onCancel: () {
        s1?.cancel();
        s2?.cancel();
      },
    );
    yield* ctrl.stream;
  }

  Future<void> cagriAc({
    required String acanId,
    required String acanAd,
    required List<String> davetliIds,
    required String? saat,
    required String yer,
    String? konumAd,
    String? tarih,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }

    // ✅ Çağrıyı açan kişiyi listenin BAŞINA ekle
    final tumKatilimcilar = [acanId, ...davetliIds];

    await _fs.collection(_kol).add({
      'acanId': acanId,
      'acanAd': acanAd,
      'durum': 'acik',
      'davetliIds': tumKatilimcilar,
      'onaylar': [acanId],
      'saat': saat,
      'tarih': tarih,
      'yer': yer,
      'konumAd': konumAd,
      'grupId': k.grupId,
      'olusturma': FieldValue.serverTimestamp(),
    });
  }

  Future<void> bulusmaKaydet({
    required String id,
    required String saat,
    required String yer,
    String? konumAd,
    String? tarih,
  }) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }
    final doc = await _fs.collection(_kol).doc(id).get();
    if (!doc.exists ||
        doc.data()?['grupId'] != k.grupId ||
        doc.data()?['acanId'] != k.uid) {
      throw Exception('Bu çağrıyı düzenleme yetkiniz yok.');
    }
    await _fs.collection(_kol).doc(id).update({
      'saat': saat,
      'tarih': tarih,
      'yer': yer,
      'konumAd': konumAd,
    });
  }

  Future<void> onayla(String id, String uid) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }

    final docRef = _fs.collection(_kol).doc(id);
    final docSnap = await docRef.get();
    if (!docSnap.exists) throw Exception('Çağrı bulunamadı.');
    if (docSnap.data()?['grupId'] != k.grupId) {
      throw Exception('Farklı gruptaki çağrıya onay veremezsiniz.');
    }

    final sonuc = await _fs.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return null;

      final c = Cagri.fromFirestore(snap);
      if (c.durum != 'acik' && c.durum != 'onaylandi') return null;
      if (c.onaylar.contains(uid)) return null;

      final yeniOnaylar = [...c.onaylar, uid];
      final bool zatenMuhurlu = c.durum == 'onaylandi';

      // ✅✅ KRİTİK DÜZELTME: Oyun Başlama Koşulu Güncellendi ✅✅
      // Eski: yeniOnaylar.length >= c.hedef (Herkes onayladı mı?)
      // Yeni: En az 4 kişi onayladı mı? (Çağrıcı dahil)
      final bool oyunBaslayabilir =
          yeniOnaylar.length >= 4 || yeniOnaylar.length >= c.hedef;
      if (zatenMuhurlu) {
        tx.update(docRef, {'onaylar': yeniOnaylar});
      } else {
        tx.update(docRef, {
          'onaylar': yeniOnaylar,
          // ✅ 4. kişi onayladığı anda durum 'onaylandi' olacak
          if (oyunBaslayabilir) 'durum': 'onaylandi',
        });
      }

      // Otomasyon sadece durum 'acik'ten 'onaylandi'ye geçtiğinde tetiklenir
      if (!zatenMuhurlu && oyunBaslayabilir) {
        return Cagri(
          id: c.id,
          acanId: c.acanId,
          acanAd: c.acanAd,
          durum: 'onaylandi',
          davetliIds: c.davetliIds,
          saat: c.saat,
          tarih: c.tarih,
          yer: c.yer,
          konumAd: c.konumAd,
          onaylar: yeniOnaylar,
          olusturma: c.olusturma,
        );
      }
      return null;
    });

    try {
      await _fs.collection('kullanicilar').doc(uid).update({'durum': 'musait'});
    } catch (_) {}
    if (sonuc != null && sonuc.durum == 'onaylandi') await _otomasyon(sonuc);
  }

  Future<void> _otomasyon(Cagri cagri) async {
    try {
      final k = await AuthService().profilGarantile();
      if (k == null || k.grupId == null) return;
      final grupId = k.grupId!;

      // Aktif oyun var mı kontrolü
      final oyunlarSnap = await _fs
          .collection('oyunlar')
          .where('grupId', isEqualTo: grupId)
          .where('oyunKazanan', isEqualTo: null)
          .where('aktifMi', isEqualTo: true)
          .limit(1)
          .get();
      if (oyunlarSnap.docs.isNotEmpty) return;

      // ✅ SADECE OYUN NUMARASI GLOBAL ARTSIN
      final nRef = _fs.collection('metadata').doc('oyun_numarasi');
      int oyunNo = 1;

      await _fs.runTransaction((tx) async {
        final doc = await tx.get(nRef);
        if (doc.exists) {
          oyunNo = (doc.data()?['son_numara'] ?? 0) + 1;
          tx.update(nRef, {'son_numara': oyunNo});
        } else {
          tx.set(nRef, {'son_numara': 1});
        }
      });

      // ✅ SEZON: Eğer aktif sezon yoksa YENİ oluştur, varsa mevcut olanı kullan
      String aktifSezonId;

      final sezonlarSnap = await _fs
          .collection('sezonlar')
          .where('grupId', isEqualTo: grupId)
          .where('sezonSampiyon', isEqualTo: null)
          .where('aktifMi', isEqualTo: true)
          .limit(1)
          .get();

      if (sezonlarSnap.docs.isNotEmpty) {
        aktifSezonId = sezonlarSnap.docs.first.id;
      } else {
        // Yeni sezon oluştur - NUMARA OYUN NUMARASINA BAĞLI DEĞİL, AYRI SAYAÇ
        final sRef = _fs.collection('metadata').doc('sezon_numarasi');
        int yeniSezonNo = 1;
        await _fs.runTransaction((tx) async {
          final doc = await tx.get(sRef);
          if (doc.exists) {
            yeniSezonNo = (doc.data()?['son_numara'] ?? 0) + 1;
            tx.update(sRef, {'son_numara': yeniSezonNo});
          } else {
            tx.set(sRef, {'son_numara': 1});
          }
        });

        final ref = _fs.collection('sezonlar').doc();
        await ref.set({
          'numara': yeniSezonNo,
          'grupId': grupId,
          'sezonTarih': '${cagri.adlandirmaTarihi} - Sezon $yeniSezonNo',
          'sezonSampiyon': null,
          'aktifMi': true,
        });
        aktifSezonId = ref.id;
      }

      // ✅ TURNUVA: Eğer aktif turnuva yoksa YENİ oluştur, varsa mevcut olanı kullan
      String aktifTurnuvaId;

      final turnuvaSnap = await _fs
          .collection('turnuva')
          .where('grupId', isEqualTo: grupId)
          .where('turKazanan', isEqualTo: null)
          .where('aktifMi', isEqualTo: true)
          .limit(1)
          .get();

      if (turnuvaSnap.docs.isNotEmpty) {
        aktifTurnuvaId = turnuvaSnap.docs.first.id;
      } else {
        // Yeni turnuva oluştur - NUMARA AYRI SAYAÇ
        final tRef = _fs.collection('metadata').doc('turnuva_numarasi');
        int yeniTurnuvaNo = 1;
        await _fs.runTransaction((tx) async {
          final doc = await tx.get(tRef);
          if (doc.exists) {
            yeniTurnuvaNo = (doc.data()?['son_numara'] ?? 0) + 1;
            tx.update(tRef, {'son_numara': yeniTurnuvaNo});
          } else {
            tx.set(tRef, {'son_numara': 1});
          }
        });

        final ref = _fs.collection('turnuva').doc();
        await ref.set({
          'numara': yeniTurnuvaNo,
          'sezonId': aktifSezonId,
          'grupId': grupId,
          'turTarih': '${cagri.adlandirmaTarihi} - Turnuva $yeniTurnuvaNo',
          'turKazanan': null,
          'turIkinci': null,
          'turUcuncu': null,
          'turKaybeden': null,
          'tursonuc': 0,
          'aktifMi': true,
        });
        aktifTurnuvaId = ref.id;
      }

      // ✅ OYUN OLUŞTUR - SADECE OYUN NO GLOBAL ARTIYOR
      final dortUid = cagri.onaylar.take(4).toList();
      if (dortUid.isEmpty) return;

      final isimler = <String>[];
      for (final u in dortUid) {
        final ad = await _oyuncuAdi(u);
        isimler.add(ad);
      }
      final oyuncuMetni = isimler.join(', ');

      await _fs.collection('oyunlar').doc().set({
        'numara': oyunNo, // ✅ GLOBAL ARTAN TEK NUMARA
        'turId': aktifTurnuvaId,
        'sezonId': aktifSezonId,
        'grupId': grupId,
        'oyunTarih':
            '${cagri.adlandirmaTarihi} - Oyun $oyunNo', // ✅ TUTARLI FORMAT
        'elSayisi': 8,
        'oyuncuSayisi': dortUid.length,
        'oyuncuIds': dortUid,
        'oyuncu': oyuncuMetni,
        'oyunKazanan': null,
        'oyunKazananUid': null,
        'oyunKaybeden': null,
        'oyunKaybedenUid': null,
        'esliMi': 0,
        'aktifMi': true,
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint(' OTOMASYON HATASI: $e\n$st');
    }
  }

  Future<String> _oyuncuAdi(String uid) async {
    try {
      final kSnap = await _fs.collection('kullanicilar').doc(uid).get();
      if (kSnap.exists) {
        final kd = kSnap.data() ?? {};
        final adSoyad = (kd['adSoyad'] ?? '').toString().trim();
        if (adSoyad.isNotEmpty) return adSoyad;
        final nick = (kd['nick'] ?? '').toString().trim();
        if (nick.isNotEmpty) return nick;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_oyuncuAdi hatası ($uid): $e');
    }
    return 'Oyuncu';
  }

  Future<void> sonlandir(String id) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }
    final doc = await _fs.collection(_kol).doc(id).get();
    if (!doc.exists ||
        doc.data()?['grupId'] != k.grupId ||
        doc.data()?['acanId'] != k.uid) {
      throw Exception('Bu çağrıyı sonlandırma yetkiniz yok.');
    }
    await _fs.collection(_kol).doc(id).update({'durum': 'sonlandi'});
  }

  Future<void> cagriGuncelle({
    required String cagriId,
    String? saat,
    String? tarih,
    required String yer,
    String? konumAd,
    required List<String> davetliIds,
  }) async {
    await FirebaseFirestore.instance
        .collection('cagrilar')
        .doc(cagriId)
        .update({
          'saat': saat,
          'tarih': tarih,
          'yer': yer,
          'konumAd': konumAd,
          'davetliIds': davetliIds,
          'guncellemeTarihi': FieldValue.serverTimestamp(),
        });
  }
}

class PanoVerisi {
  final bool aktif;
  final String? cagriId;
  final String? acanAd;
  final bool benAcan;
  final int onaySayisi;
  final bool kilitli;
  final int hedef;

  const PanoVerisi({
    required this.aktif,
    required this.cagriId,
    required this.acanAd,
    required this.benAcan,
    required this.onaySayisi,
    required this.kilitli,
    required this.hedef,
  });

  factory PanoVerisi.bos() => PanoVerisi(
    aktif: false,
    cagriId: null,
    acanAd: null,
    benAcan: false,
    onaySayisi: 0,
    kilitli: false,
    hedef: 0,
  );

  // ✅ GÜNCELLENDİ: SAAT KONTROLÜ EKLENDİ
  factory PanoVerisi.cagri(Cagri c, {required bool benAcan}) {
    bool isAktif = c.durum == 'acik' || c.durum == 'onaylandi';
    bool isKilitli = c.durum == 'onaylandi';

    // Eğer çağrı mühürlüyse (onaylandi), saati kontrol et
    if (c.durum == 'onaylandi') {
      try {
        // Saat formatı muhtemelen "HH:mm" (örn: "19:30")
        // Tarih formatı muhtemelen "dd.MM.yyyy" (örn: "04.09.2026")

        DateTime? bulusmaZamani;

        if (c.tarih != null &&
            c.tarih!.isNotEmpty &&
            c.saat != null &&
            c.saat!.isNotEmpty) {
          // Tarih ve saat varsa birleştir
          final parts = c.tarih!.split('.'); // 04.09.2026 -> [04, 09, 2026]
          final timeParts = c.saat!.split(':'); // 19:30 -> [19, 30]

          if (parts.length == 3 && timeParts.length == 2) {
            bulusmaZamani = DateTime(
              int.parse(parts[2]), // Yıl
              int.parse(parts[1]), // Ay
              int.parse(parts[0]), // Gün
              int.parse(timeParts[0]), // Saat
              int.parse(timeParts[1]), // Dakika
            );
          }
        } else if (c.olusturma != null &&
            c.saat != null &&
            c.saat!.isNotEmpty) {
          // Sadece saat varsa ve tarih yoksa, oluşturma tarihini baz alarak bugünü varsayabiliriz
          // Ama senin sisteminde tarih genelde var görünüyor.
          // Güvenlik için sadece tarih+saat ikisi de varsa kontrol yapıyoruz.
        }

        // Eğer buluşma zamanı hesaplandıysa ve şu andan 12 saat (720 dk) önceyse -> PASİF YAP
        if (bulusmaZamani != null) {
          final fark = DateTime.now().difference(bulusmaZamani);
          if (fark.inMinutes > 720) {
            // 12 saat * 60 dk
            isAktif = false;
            isKilitli = false; // Tikleri boşaltmak için kilidi de kaldırıyoruz
          }
        }
      } catch (e) {
        debugPrint('PanoVerisi tarih parse hatası: $e');
        // Hata olursa varsayılan davranış (aktif) kalsın
      }
    }

    return PanoVerisi(
      aktif: isAktif,
      cagriId: c.id,
      acanAd: c.acanAd,
      benAcan: benAcan,
      onaySayisi: c.onaylar.length,
      kilitli: isKilitli,
      hedef: c.hedef,
    );
  }
}
