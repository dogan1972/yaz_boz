// lib/models/arkadas_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ArkadaslikIstegi {
  final String id;
  final String gonderen;
  final String alan;
  final DateTime olusturma;

  ArkadaslikIstegi({
    required this.id,
    required this.gonderen,
    required this.alan,
    required this.olusturma,
  });

  factory ArkadaslikIstegi.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArkadaslikIstegi(
      id: doc.id,
      gonderen: data['gonderen'] ?? '',
      alan: data['alan'] ?? '',
      olusturma: (data['olusturma'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
