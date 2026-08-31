import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

class ArkadaslikIstegi {
  final String id;
  final String gonderen;
  final String alan;
  final Timestamp? olusturma;

  const ArkadaslikIstegi({
    required this.id,
    required this.gonderen,
    required this.alan,
    this.olusturma,
  });

  factory ArkadaslikIstegi.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ArkadaslikIstegi(
      id: doc.id,
      gonderen: d['gonderen']?.toString() ?? '',
      alan: d['alan']?.toString() ?? '',
      olusturma: d['olusturma'] as Timestamp?,
    );
  }
}

// ✅ YENİ: Çapraz grup uyarısı için özel exception sınıfı
class GrupCakismaException implements Exception {
  final String mesaj;
  GrupCakismaException(this.mesaj);
  @override
  String toString() => mesaj;
}

class ArkadasServisi {
  static final ArkadasServisi _instance = ArkadasServisi._internal();
  factory ArkadasServisi() => _instance;
  ArkadasServisi._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static const String _kol = 'istekler';
  static const String _kullanicilar = 'kullanicilar';

  Future<void> istekGonder(String gonderen, String alan) async {
    if (gonderen == alan) return;

    // Çift istek kontrolü
    final benSnap = await _fs.collection(_kullanicilar).doc(gonderen).get();
    if (benSnap.exists) {
      final raw = (benSnap.data()?['arkadasIds'] as List?) ?? const [];
      if (raw.map((e) => e.toString()).contains(alan)) return;
    }

    // Bekleyen istek kontrolü
    final gidenSnap = await _fs
        .collection(_kol)
        .where('gonderen', isEqualTo: gonderen)
        .get();
    final zatenVar = gidenSnap.docs
        .map(ArkadaslikIstegi.fromDoc)
        .any((i) => i.alan == alan);
    if (zatenVar) return;

    await _fs.collection(_kol).add({
      'gonderen': gonderen,
      'alan': alan,
      'olusturma': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ArkadaslikIstegi>> gelenIsteklerStreami(String uid) {
    return _fs
        .collection(_kol)
        .where('alan', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(ArkadaslikIstegi.fromDoc).toList()..sort((a, b) {
                final ta = a.olusturma?.millisecondsSinceEpoch ?? 0;
                final tb = b.olusturma?.millisecondsSinceEpoch ?? 0;
                return tb.compareTo(ta);
              }),
        );
  }

  Stream<List<ArkadaslikIstegi>> gidenIsteklerStreami(String uid) {
    return _fs
        .collection(_kol)
        .where('gonderen', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map(ArkadaslikIstegi.fromDoc).toList());
  }

  // lib/services/arkadas_servisi.dart - istegiOnayla metodu güncellemesi

  Future<void> istegiOnayla(
    String istekId,
    String gonderen,
    String alan,
  ) async {
    await _oyuncuIdGarantile(gonderen);
    await _oyuncuIdGarantile(alan);

    // Kullanıcı profillerini çek
    final gonderenSnap = await _fs
        .collection(_kullanicilar)
        .doc(gonderen)
        .get();
    final alanSnap = await _fs.collection(_kullanicilar).doc(alan).get();

    final gData = gonderenSnap.data() ?? {};
    final aData = alanSnap.data() ?? {};

    String? gonderenGrup = gData['grupId'] as String?;
    String? alanGrup = aData['grupId'] as String?;
    String? gonderenGrupAdi = gData['grupAdi'] as String?;
    String? alanGrupAdi = aData['grupAdi'] as String?;

    // 🛑 ÇAPRAZ GRUP KONTROLÜ
    if (gonderenGrup != null &&
        gonderenGrup.isNotEmpty &&
        alanGrup != null &&
        alanGrup.isNotEmpty &&
        gonderenGrup != alanGrup) {
      String uyarMesaji = '';
      if (gonderenGrupAdi != null && alanGrupAdi != null) {
        uyarMesaji =
            "Çapraz girişim engellendi!\n\nSiz '$alanGrupAdi' üyesisiniz.\nKarşı taraf '$gonderenGrupAdi' üyesi.\n\nBir kişi aynı anda sadece tek bir grupta bulunabilir.";
      } else {
        uyarMesaji =
            "Her iki kullanıcının da farklı grupları mevcut. Çapraz grup katılımına izin verilmez.";
      }
      throw GrupCakismaException(uyarMesaji);
    }

    String ortakGrupId;
    String? yeniGrupAdi;
    bool yeniGrupOlusturuldu = false;

    // Mantık: Grubu olanın grubu esas alınır.
    if (gonderenGrup != null && gonderenGrup.isNotEmpty) {
      ortakGrupId = gonderenGrup;
      yeniGrupAdi = gonderenGrupAdi;
    } else if (alanGrup != null && alanGrup.isNotEmpty) {
      ortakGrupId = alanGrup;
      yeniGrupAdi = alanGrupAdi;
    } else {
      // İkisi de grupsuzsa -> YENİ GRUP OLUŞTUR
      ortakGrupId = const Uuid().v4();
      final gonderenAd =
          gData['nick']?.toString() ??
          gData['adSoyad']?.toString() ??
          'Kullanıcı';
      yeniGrupAdi = "$gonderenAd'in Grubu";
      yeniGrupOlusturuldu = true;
    }

    // ✅ YENİ GRUP OLUŞTURMA
    if (yeniGrupOlusturuldu) {
      await _fs.collection('gruplar').doc(ortakGrupId).set({
        'grupAdi': yeniGrupAdi,
        'kurucuId': alan,
        'olusturma': FieldValue.serverTimestamp(),
        'uyeSayisi': 2,
      });
      debugPrint('✅ Yeni grup oluşturuldu: $ortakGrupId - $yeniGrupAdi');
    }

    // ✅ YENİ: Gruptaki TÜM mevcut üyeleri çek
    final grupUyeleriSnap = await _fs
        .collection(_kullanicilar)
        .where('grupId', isEqualTo: ortakGrupId)
        .get();

    final grupUyeIdleri = grupUyeleriSnap.docs
        .map((d) => d.id)
        .where((id) => id != gonderen && id != alan) // Kendileri hariç
        .toList();

    // ✅ BATCH WRITE: Tüm arkadaşlıkları tek seferde yaz
    final batch = _fs.batch();

    // 1) Gonderen ve Alan'ın grup bilgilerini güncelle
    batch.update(_fs.collection(_kullanicilar).doc(gonderen), {
      'grupId': ortakGrupId,
      'grupAdi': yeniGrupAdi,
    });
    batch.update(_fs.collection(_kullanicilar).doc(alan), {
      'grupId': ortakGrupId,
      'grupAdi': yeniGrupAdi,
    });

    // 2) Gonderen ↔ Alan karşılıklı arkadaşlık
    batch.update(_fs.collection(_kullanicilar).doc(gonderen), {
      'arkadasIds': FieldValue.arrayUnion([alan]),
    });
    batch.update(_fs.collection(_kullanicilar).doc(alan), {
      'arkadasIds': FieldValue.arrayUnion([gonderen]),
    });

    // 3) ✅ YENİ: Gruptaki diğer herkesle karşılıklı arkadaşlık kur
    for (final uyeId in grupUyeIdleri) {
      // Yeni katılan (alan) ↔ Mevcut üye
      batch.update(_fs.collection(_kullanicilar).doc(alan), {
        'arkadasIds': FieldValue.arrayUnion([uyeId]),
      });
      batch.update(_fs.collection(_kullanicilar).doc(uyeId), {
        'arkadasIds': FieldValue.arrayUnion([alan]),
      });

      // Gonderen ↔ Mevcut üye (eğer gonderen de yeni katıldıysa)
      // Not: Eğer gonderen zaten gruptaysa bu redundant olabilir ama arrayUnion güvenlidir
      batch.update(_fs.collection(_kullanicilar).doc(gonderen), {
        'arkadasIds': FieldValue.arrayUnion([uyeId]),
      });
      batch.update(_fs.collection(_kullanicilar).doc(uyeId), {
        'arkadasIds': FieldValue.arrayUnion([gonderen]),
      });
    }

    // 4) ✅ Grup dokümanındaki üye sayısını güncelle
    final yeniUyeSayisi = grupUyeIdleri.length + 2; // mevcut + gonderen + alan
    if (yeniGrupOlusturuldu) {
      // Yeni grup zaten set edildi, güncelleme gerekmez
    } else {
      batch.update(_fs.collection('gruplar').doc(ortakGrupId), {
        'uyeSayisi': yeniUyeSayisi,
      });
    }

    // 5) İsteği sil
    batch.delete(_fs.collection(_kol).doc(istekId));

    // ✅ Tek seferde tüm işlemleri uygula
    await batch.commit();

    debugPrint(
      '✅ Arkadaşlık onaylandı. Grup: $ortakGrupId | '
      'Toplam üye: $yeniUyeSayisi | '
      'Yeni arkadaşlık sayısı: ${grupUyeIdleri.length * 2 + 2}',
    );
  }

  // ✅ YENİ: Gruptan Ayrılma Metodu
  Future<void> gruptanAyril(String uid) async {
    await _fs.collection(_kullanicilar).doc(uid).update({
      'grupId': FieldValue.delete(),
      'grupAdi': FieldValue.delete(),
    });
  }

  Future<String?> _oyuncuIdGarantile(String uid) async {
    final ref = _fs.collection(_kullanicilar).doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return null;

    final d = snap.data() ?? {};
    final mevcut = d['oyuncuId']?.toString();

    if (mevcut != null && mevcut.isNotEmpty) return mevcut;

    await ref.update({'oyuncuId': uid});
    return uid;
  }

  Future<void> istegiReddet(String istekId) async {
    await _fs.collection(_kol).doc(istekId).delete();
  }
}
