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

  // ✅ ÇAĞRI İPTAL ETME
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

  // ✅ AÇIK ÇAĞRI STREAMİ
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

  // ✅ DAVETLİ AÇIK ÇAĞRI STREAMİ
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

  // ✅ TEKİL ÇAĞRI STREAMİ
  Stream<Cagri?> cagriStreami(String id) {
    return _fs
        .collection(_kol)
        .doc(id)
        .snapshots()
        .map((snap) => snap.exists ? Cagri.fromFirestore(snap) : null);
  }

  // ✅ SON 24 SAAT ÇAĞRILARI STREAMİ
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
          final ta = a.olusturma?.millisecondsSinceEpoch ?? 0;
          final tb = b.olusturma?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
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

  // ✅ PANO VERİSİ STREAMİ
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
        ctrl.add(PanoVerisi.cagri(benim!, benAcan: true, uid: uid));
      } else if (davet != null) {
        ctrl.add(PanoVerisi.cagri(davet!, benAcan: false, uid: uid));
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

  // ✅ ÇAĞRI AÇMA
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

    await _fs.collection(_kol).add({
      'acanId': acanId,
      'acanAd': acanAd,
      'durum': 'acik',
      'hedef': davetliIds.length,
      'davetliIds': davetliIds,
      'onaylar': [],
      'saat': saat,
      'tarih': tarih,
      'yer': yer,
      'konumAd': konumAd,
      'grupId': k.grupId,
      'olusturma': FieldValue.serverTimestamp(),
    });
  }

  // ✅ BULUŞMA KAYDETME
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

  // ✅ MÜHÜRLÜ ÇAĞRIYA DA ONAY DESTEKLİ SIRALI ONAY
  Future<void> onayla(String id, String uid) async {
    final k = await AuthService().profilGarantile();
    if (k == null || k.grupId == null) {
      throw Exception('Grup bilgisi bulunamadı.');
    }

    final docRef = _fs.collection(_kol).doc(id);

    final docSnap = await docRef.get();
    if (!docSnap.exists) throw Exception('Çağrı bulunamadı.');
    final docData = docSnap.data() as Map<String, dynamic>;
    if (docData['grupId'] != k.grupId) {
      throw Exception('Farklı gruptaki çağrıya onay veremezsiniz.');
    }

    final sonuc = await _fs.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return null;

      final c = Cagri.fromFirestore(snap);

      // ✅ Hem 'acik' hem de 'onaylandi' durumlarında onay verilebilir
      if (c.durum != 'acik' && c.durum != 'onaylandi') return null;

      // Zaten onaylamışsa tekrar ekleme
      if (c.onaylar.contains(uid)) return null;

      final yeniOnaylar = [...c.onaylar, uid];
      final bool zatenMuhurlu = c.durum == 'onaylandi';

      // Çağrıcı her zaman onaylı kabul edilir
      final Set<String> tumOnaylilar = {c.acanId, ...yeniOnaylar};

      // Oyunun başlaması için: Tüm davetliler onayladı VEYA 4 kişi tamamlandı
      final bool tumDavetlilerOnayladi = c.davetliIds.every(
        (d) => tumOnaylilar.contains(d),
      );
      final bool dortKisiTamamlandi = tumOnaylilar.length >= 4;
      final bool oyunBaslayabilir = tumDavetlilerOnayladi || dortKisiTamamlandi;

      // Eğer çağrı zaten mühürlüyse durumu değiştirme, sadece onay listesini güncelle
      if (zatenMuhurlu) {
        tx.update(docRef, {'onaylar': yeniOnaylar});
      } else {
        tx.update(docRef, {
          'onaylar': yeniOnaylar,
          if (oyunBaslayabilir) 'durum': 'onaylandi',
        });
      }

      // Otomasyon sadece ilk mühürlemede çalışmalı
      if (!zatenMuhurlu && oyunBaslayabilir) {
        return Cagri(
          id: c.id,
          acanId: c.acanId,
          acanAd: c.acanAd,
          durum: 'onaylandi',
          hedef: c.hedef,
          davetliIds: c.davetliIds,
          saat: c.saat,
          tarih: c.tarih,
          yer: c.yer,
          konumAd: c.konumAd,
          onaylar: tumOnaylilar.toList(),
          olusturma: c.olusturma,
        );
      }

      // Zaten mühürlüyse otomasyon tetikleme
      return null;
    });

    try {
      await _fs.collection('kullanicilar').doc(uid).update({'durum': 'musait'});
    } catch (_) {}

    if (sonuc != null && sonuc.durum == 'onaylandi') await _otomasyon(sonuc);
  }

  // ✅ OTOMASYON — UID DESTEKLİ OYUN OLUŞTURMA
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
          .where('aktifMi', isEqualTo: true) // ✅ EKLENDİ
          .limit(1)
          .get();
      if (oyunlarSnap.docs.isNotEmpty) return;

      final uidSira = <String>[
        cagri.acanId,
        ...cagri.onaylar.where((u) => u != cagri.acanId),
      ];
      final dortUid = uidSira.take(4).toList();
      if (dortUid.isEmpty) return;

      final isimler = <String>[];
      for (final u in dortUid) {
        final ad = await _oyuncuAdi(u);
        isimler.add(ad);
      }
      final oyuncuMetni = isimler.join(', ');
      final adTarih = cagri.adlandirmaTarihi;

      // ✅ SEZON ARAMA — aktifMi kontrolü eklendi
      final sezonlarSnap = await _fs
          .collection('sezonlar')
          .where('grupId', isEqualTo: grupId)
          .where('sezonSampiyon', isEqualTo: null)
          .where('aktifMi', isEqualTo: true) // ✅ EKLENDİ: Sadece aktif sezonlar
          .limit(1)
          .get();
      String aktifSezonId;
      if (sezonlarSnap.docs.isNotEmpty) {
        aktifSezonId = sezonlarSnap.docs.first.id;
      } else {
        final nRef = _fs.collection('metadata').doc('sezon_numarasi');
        int yeniNumara = 1;
        await _fs.runTransaction((tx) async {
          final doc = await tx.get(nRef);
          if (doc.exists) {
            yeniNumara = (doc.data()?['son_numara'] ?? 0) + 1;
            tx.update(nRef, {'son_numara': yeniNumara});
          } else {
            tx.set(nRef, {'son_numara': 1});
          }
        });

        final ref = _fs.collection('sezonlar').doc();
        await ref.set({
          'numara': yeniNumara,
          'grupId': grupId,
          'sezonTarih': '$adTarih - Sezon $yeniNumara',
          'sezonSampiyon': null,
          'aktifMi': true, // ✅ Yeni sezon aktif oluşturuluyor
        });
        aktifSezonId = ref.id;
      }

      // ✅ TURNUVA ARAMA — aktifMi kontrolü eklendi (KRİTİK DÜZELTME)
      final turnuvaSnap = await _fs
          .collection('turnuva')
          .where('grupId', isEqualTo: grupId)
          .where('turKazanan', isEqualTo: null)
          .where('aktifMi', isEqualTo: true) // ✅ EKLENDİ: Pasif/arşiv atlanır
          .limit(1)
          .get();
      String aktifTurnuvaId;
      if (turnuvaSnap.docs.isNotEmpty) {
        aktifTurnuvaId = turnuvaSnap.docs.first.id;
      } else {
        final nRef = _fs.collection('metadata').doc('turnuva_numarasi');
        int yeniNumara = 1;
        await _fs.runTransaction((tx) async {
          final doc = await tx.get(nRef);
          if (doc.exists) {
            yeniNumara = (doc.data()?['son_numara'] ?? 0) + 1;
            tx.update(nRef, {'son_numara': yeniNumara});
          } else {
            tx.set(nRef, {'son_numara': 1});
          }
        });

        final ref = _fs.collection('turnuva').doc();
        await ref.set({
          'numara': yeniNumara,
          'sezonId': aktifSezonId,
          'grupId': grupId,
          'turTarih': '$adTarih - Turnuva $yeniNumara',
          'turKazanan': null,
          'turIkinci': null,
          'turUcuncu': null,
          'turKaybeden': null,
          'tursonuc': 0,
          'aktifMi': true, // ✅ Yeni turnuva aktif oluşturuluyor
        });
        aktifTurnuvaId = ref.id;
      }

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

      final oyunRef = _fs.collection('oyunlar').doc();
      await oyunRef.set({
        'numara': oyunNo,
        'turId': aktifTurnuvaId,
        'grupId': grupId,
        'oyunTarih': '$adTarih - Oyun $oyunNo',
        'elSayisi': 8,
        'oyuncuSayisi': dortUid.length,
        'oyuncuIds': dortUid,
        'oyuncu': oyuncuMetni,
        'oyunKazanan': null,
        'oyunKazananUid': null,
        'oyunKaybeden': null,
        'oyunKaybedenUid': null,
        'esliMi': 0,
        'aktifMi': true, // ✅ Yeni oyun aktif oluşturuluyor
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('❌ OTOMASYON HATASI: $e\n$st');
    }
  }

  /// uid → oyuncu adı
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

  // ✅ SONLANDIRMA
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

  // ✅ GÜNCELLEME
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
  factory PanoVerisi.cagri(
    Cagri c, {
    required bool benAcan,
    required String uid,
  }) => PanoVerisi(
    aktif: c.durum == 'acik' || c.durum == 'onaylandi',
    cagriId: c.id,
    acanAd: c.acanAd,
    benAcan: benAcan,
    onaySayisi: c.onaylar.length + 1,
    kilitli: c.durum == 'onaylandi',
    hedef: c.davetliIds.length + 1,
  );
}
