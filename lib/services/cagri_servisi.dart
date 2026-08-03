import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/cagri.dart';

class CagriServisi {
  static final CagriServisi _instance = CagriServisi._internal();
  factory CagriServisi() => _instance;
  CagriServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static const String _kol = 'cagrilar';

  Stream<Cagri?> acikCagriStreami(String uid) {
    return _fs
        .collection(_kol)
        .where('acanId', isEqualTo: uid)
        .where('durum', isEqualTo: 'acik')
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isNotEmpty
              ? Cagri.fromFirestore(snap.docs.first)
              : null,
        );
  }

  Stream<Cagri?> davetliAcikCagriStreami(String uid) {
    return _fs
        .collection(_kol)
        .where('davetliIds', arrayContains: uid)
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

  // ✅ YENİ: Son 24 saatteki TÜM çağrılar (açan + davetli birleşik)
  // Index gerektirmez: tek alan sorgusu + client-side zaman filtresi
  Stream<List<Cagri>> son24SaatCagrilariStreami(String uid) {
    late StreamController<List<Cagri>> controller;
    StreamSubscription<QuerySnapshot>? subAcan;
    StreamSubscription<QuerySnapshot>? subDavet;
    final Map<String, Cagri> birlesik = {};

    void push() {
      final liste = birlesik.values.toList()
        ..sort((a, b) {
          // Aktif/mühürlü olanlar üstte, sonra en yeni
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

    return controller.stream;
  }

  bool _son24Saat(Cagri c) {
    final t = c.olusturma;
    if (t == null) return true; // timestamp yoksa göster (güvenli taraf)
    return DateTime.now().difference(t.toDate()).inHours < 24;
  }

  // ✅ PANO — takılmasız birleşik stream.
  //    'acik' VE 'onaylandi'(kilitli) çağrıları izler; son onayda pano
  //    kilidi görür, tüm node'lar yeşillenir, zil çalar. '.first' bekleme
  //    YOK → boş stream'de asla takılmaz, her olayda anında push eder.
  // ✅ PANO — takılmasız birleşik stream.
  //    'acik' VE 'onaylandi'(kilitli) çağrıları izler; son onayda pano
  //    kilidi görür, tüm node'lar yeşillenir, zil çalar. '.first' bekleme
  //    YOK → boş stream'de asla takılmaz, her olayda anında push eder.
  Stream<PanoVerisi> panoStreami(String uid) {
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

    return ctrl.stream;
  }

  Future<void> cagriAc({
    required String acanId,
    required String acanAd,
    required List<String> davetliIds,
    required String saat,
    required String yer,
    String? konumAd,
  }) async {
    await _fs.collection(_kol).add({
      'acanId': acanId,
      'acanAd': acanAd,
      'durum': 'acik',
      'hedef': davetliIds.length,
      'davetliIds': davetliIds,
      'onaylar': [],
      'saat': saat,
      'yer': yer,
      'konumAd': konumAd,
      'olusturma': FieldValue.serverTimestamp(),
    });
  }

  Future<void> bulusmaKaydet({
    required String id,
    required String saat,
    required String yer,
    String? konumAd,
  }) async {
    await _fs.collection(_kol).doc(id).update({
      'saat': saat,
      'yer': yer,
      'konumAd': konumAd,
    });
  }

  Future<void> onayla(String id, String uid) async {
    final docRef = _fs.collection(_kol).doc(id);
    await docRef.update({
      'onaylar': FieldValue.arrayUnion([uid]),
    });

    await _fs.collection('kullanicilar').doc(uid).update({'durum': 'musait'});
    final snap = await docRef.get();
    final cagri = Cagri.fromFirestore(snap);
    if (cagri.herkesOnayladi) {
      await docRef.update({'durum': 'onaylandi'});
    }
  }

  Future<void> sonlandir(String id) async {
    await _fs.collection(_kol).doc(id).update({'durum': 'sonlandi'});
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
  }) {
    return PanoVerisi(
      aktif: c.durum == 'acik',
      cagriId: c.id,
      acanAd: c.acanAd,
      benAcan: benAcan,
      onaySayisi: c.onaylar.length,
      kilitli: c.durum == 'onaylandi',
      hedef: c.davetliIds.length,
    );
  }
}
