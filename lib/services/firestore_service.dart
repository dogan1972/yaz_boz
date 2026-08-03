import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // ✅ STATIC STREAM CACHE KALDIRILDI.
  //    Ölü cache "ilk çalışır / sonra hepsi beyaz" deseninin köküydü.
  //    Artık her çağrı taze listener açar; Firestore SDK aynı koleksiyonun
  //    aktif listener'larını kendi içinde birleştirir.

  // ✅ GLOBAL YÜKLEME WATCHDOGU — hiçbir sayfaya dokunmadan tüm stream'lerde
  //    "2 sn içinde ilk veri gelmezse console'a yaz" garantisi.
  void _watchdog(Stream<QuerySnapshot> stream, String etiket) {
    final sw = Stopwatch()..start();
    stream.first
        .timeout(const Duration(seconds: 2))
        .then((snap) {
          debugPrint(
            '✅ [$etiket] ilk snapshot ${sw.elapsedMilliseconds}ms '
            '(${snap.docs.length} doküman)',
          );
        })
        .catchError((Object e) {
          if (e is TimeoutException) {
            debugPrint(
              '⏱️ TIMEOUT [$etiket] 2.000ms içinde VERİ GELMEDİ — '
              'stream takılı, sayfa loading\'de kalır. '
              'Olası: ölü listener / ağ / Firestore güvenlik kuralı / yanlış koleksiyon.',
            );
          } else {
            debugPrint('⚠️ [$etiket] stream açılış hatası: $e');
          }
        });
  }

  // ───────────────────────────────────────────────────────────
  // YAZMA
  // ───────────────────────────────────────────────────────────
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db.collection(collection).doc(docId).set(data);
    } catch (e) {
      debugPrint("❌ setDocument hatası [$collection/$docId]: $e");
      rethrow;
    }
  }

  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db.collection(collection).doc(docId).update(data);
    } catch (e) {
      debugPrint("❌ updateDocument hatası [$collection/$docId]: $e");
      rethrow;
    }
  }

  Future<void> deleteDocument(String collection, String docId) async {
    try {
      await _db.collection(collection).doc(docId).delete();
    } catch (e) {
      debugPrint("❌ deleteDocument hatası [$collection/$docId]: $e");
      rethrow;
    }
  }

  Future<void> batchDeleteDocuments(
    String collection,
    List<String> docIds,
  ) async {
    if (docIds.isEmpty) return;
    try {
      for (var i = 0; i < docIds.length; i += 500) {
        final batch = _db.batch();
        final chunk = docIds.sublist(i, min(i + 500, docIds.length));
        for (final id in chunk) {
          batch.delete(_db.collection(collection).doc(id));
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("❌ batchDeleteDocuments hatası [$collection]: $e");
      rethrow;
    }
  }

  Future<void> cascadeDelete({
    required String rootCollection,
    required String rootId,
    required List<MapEntry<String, String>> childRelations,
  }) async {
    try {
      final silinecekler = <MapEntry<String, List<String>>>[];
      var seviyeIdleri = <String, List<String>>{
        rootCollection: [rootId],
      };

      for (final relation in childRelations) {
        final childCollection = relation.key;
        final parentField = relation.value;
        final parentIdList = seviyeIdleri.values.expand((x) => x).toList();
        if (parentIdList.isEmpty) continue;

        final snap = await _db.collection(childCollection).get();
        final childIds = snap.docs
            .where(
              (d) => parentIdList.contains(d.data()[parentField]?.toString()),
            )
            .map((d) => d.id)
            .toList();

        silinecekler.add(MapEntry(childCollection, childIds));
        seviyeIdleri[childCollection] = childIds;
      }

      for (final entry in silinecekler.reversed) {
        if (entry.value.isNotEmpty) {
          await batchDeleteDocuments(entry.key, entry.value);
        }
      }
      await deleteDocument(rootCollection, rootId);
    } catch (e) {
      debugPrint("❌ cascadeDelete hatası [$rootCollection/$rootId]: $e");
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────────
  // OKUMA  (watchdog'lu, cache'siz)
  // ───────────────────────────────────────────────────────────
  Stream<QuerySnapshot> getCollectionStream(String collection) {
    final stream = _db.collection(collection).snapshots();
    _watchdog(stream, collection);
    return stream;
  }

  Stream<QuerySnapshot> collectionStreamForOyun(
    String collection,
    String oyunId,
  ) {
    final stream = _db
        .collection(collection)
        .where('oyunId', isEqualTo: oyunId)
        .snapshots();
    _watchdog(stream, '$collection(oyunId=$oyunId)');
    return stream;
  }

  Future<QuerySnapshot> getCollection(String collection) async {
    try {
      return await _db.collection(collection).get();
    } catch (e) {
      debugPrint("❌ getCollection hatası [$collection]: $e");
      rethrow;
    }
  }

  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    try {
      return await _db.collection(collection).doc(docId).get();
    } catch (e) {
      debugPrint("❌ getDocument hatası [$collection/$docId]: $e");
      rethrow;
    }
  }

  Future<int> nextNumber(String collection) async {
    final counterRef = _db.collection('sayaclar').doc(collection);
    return _db.runTransaction<int>((tx) async {
      int current = 0;
      try {
        final snap = await tx.get(counterRef);
        if (snap.exists) {
          current = (snap.data()?['deger'] as num?)?.toInt() ?? 0;
        } else {
          final all = await _db.collection(collection).get();
          for (final d in all.docs) {
            final n = (d.data()['numara'] as num?)?.toInt() ?? 0;
            if (n > current) current = n;
          }
        }
      } catch (e) {
        debugPrint("⚠️ nextNumber uyarısı [$collection]: $e");
      }
      final next = current + 1;
      tx.set(counterRef, {'deger': next});
      return next;
    });
  }

  // ✅ auth_service çağırıyor diye no-op bırakıldı (cache artık yok).
  static void clearStreamCache() {
    debugPrint('ℹ️ clearStreamCache: cache kaldırıldı, no-op.');
  }
}
