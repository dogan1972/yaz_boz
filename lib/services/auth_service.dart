import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/firestore_service.dart';
import 'package:yaz_boz/models/kullanici.dart';
import 'package:flutter/material.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static const _kol = 'kullanicilar';

  // ✅ hang'e karşı üst sınır — hiçbir await sonsuz kalamaz
  static const _authTimeout = Duration(seconds: 15);
  static const _profilTimeout = Duration(seconds: 8);

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  static const _alfabe = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _kodUret() {
    final r = Random.secure();
    return List.generate(6, (_) => _alfabe[r.nextInt(_alfabe.length)]).join();
  }

  Future<bool> _kodBenzersizMi(String kod) async {
    final snap = await _fs
        .collection(_kol)
        .where('davetKodu', isEqualTo: kod)
        .get();
    return snap.docs.isEmpty;
  }

  Future<String> _benzersizKod() async {
    for (var i = 0; i < 6; i++) {
      final kod = _kodUret();
      if (await _kodBenzersizMi(kod)) return kod;
    }
    throw const AuthException('Davet kodu üretilemedi, tekrar deneyin.');
  }

  String _nickUret(String email) {
    final onEk = email.split('@').first;
    final parcalar = onEk.split(RegExp(r'[._\-]')).where((w) => w.isNotEmpty);
    if (parcalar.isEmpty) return 'Oyuncu';
    return parcalar
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  bool _emailGecerliMi(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  // ✅ PROFİL GARANTİSİ — SADECE profil sayfası / çağrı dialog'u için (tembel).
  //    GİRİŞ ZİNCİRİNDE ÇAĞRILMIYOR → doğru şifre yolu Firestore'a hiç uğramaz.
  Future<Kullanici?> profilGarantile() async {
    final u = uid;
    if (u == null) return null;
    final ref = _fs.collection(_kol).doc(u);
    final doc = await ref.get();
    if (doc.exists) return Kullanici.fromFirestore(doc);
    final email = _auth.currentUser?.email ?? '';
    final kod = await _benzersizKod();
    final k = Kullanici(
      uid: u,
      nick: _nickUret(email),
      email: email,
      davetKodu: kod,
      qrPayload: 'yazboz://arkadas/$kod',
    );
    await ref.set(k.toMap());
    return k;
  }

  // ── GİRİŞ — SADECE Auth, 15 sn zaman aşımı, profil YOK ────
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final temizEmail = email.trim();
    if (temizEmail.isEmpty || password.isEmpty) {
      throw const AuthException('E-posta ve şifre alanları boş bırakılamaz.');
    }
    if (!_emailGecerliMi(temizEmail)) {
      throw const AuthException('Geçerli bir e-posta adresi girin.');
    }
    try {
      final cred = await _auth
          .signInWithEmailAndPassword(email: temizEmail, password: password)
          .timeout(_authTimeout);

      return cred;
    } on TimeoutException {
      throw const AuthException(
        'Bağlantı zaman aşımı — ağı kontrol edip tekrar deneyin.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    } catch (e) {
      throw const AuthException('Giriş sırasında bir hata oluştu.');
    }
  }

  // ── KAYIT — Auth zaman aşımı; profil yazma AYRI + kısa zaman aşımı
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final temizEmail = email.trim();
    if (temizEmail.isEmpty || password.isEmpty) {
      throw const AuthException('E-posta ve şifre alanları boş bırakılamaz.');
    }
    if (!_emailGecerliMi(temizEmail)) {
      throw const AuthException('Geçerli bir e-posta adresi girin.');
    }
    if (password.length < 6) {
      throw const AuthException('Şifre en az 6 karakter olmalı.');
    }
    try {
      final cred = await _auth
          .createUserWithEmailAndPassword(email: temizEmail, password: password)
          .timeout(_authTimeout);

      try {
        final uid = cred.user!.uid;
        final kod = await _benzersizKod();
        await _fs
            .collection(_kol)
            .doc(uid)
            .set(
              Kullanici(
                uid: uid,
                nick: _nickUret(temizEmail),
                email: temizEmail,
                davetKodu: kod,
                qrPayload: 'yazboz://arkadas/$kod',
              ).toMap(),
            )
            .timeout(_profilTimeout);
      } catch (e) {
        debugPrint(' Profil oluşturma hatası ($uid): $e');
        throw AuthException('Profil oluşturulamadı. Lütfen tekrar deneyin.');
      }
      return cred;
    } on TimeoutException {
      throw const AuthException(
        'Bağlantı zaman aşımı — ağı kontrol edip tekrar deneyin.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    } catch (e) {
      throw const AuthException('Kayıt sırasında bir hata oluştu.');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      FirestoreService.clearStreamCache();
    } catch (e) {
      throw const AuthException('Çıkış yapılırken bir hata oluştu.');
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı deneyin.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı hatası. Bağlantınızı kontrol edin.';
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi henüz etkinleştirilmedi.';
      case 'requires-recent-login':
        return 'Bu işlem için tekrar giriş yapmanız gerekiyor.';
      default:
        return e.message ?? 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }
}
