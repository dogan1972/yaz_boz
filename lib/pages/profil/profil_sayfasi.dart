// lib/pages/profil/profil_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/kullanici_model.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/pages/profil/profil_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

class ProfilSayfasi extends StatefulWidget {
  const ProfilSayfasi({super.key});
  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  final _fs = FirebaseFirestore.instance;
  Kullanici? _profil;
  bool _yukleniyor = true;
  bool _cikiliyor = false;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _profilYukle();
  }

  Future<void> _profilYukle() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) setState(() => _yukleniyor = false);
      return;
    }
    try {
      final p = await AuthService().profilGarantile();
      if (!mounted) return;
      setState(() {
        _profil = p;
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint('Profil yüklenemedi: $e');
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _nickDuzenle() async {
    final controller = TextEditingController(text: _profil?.nick ?? '');
    final yeni = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Takma Adını Düzenle',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Yeni takma ad',
            hintStyle: const TextStyle(color: AppColors.divider),
            filled: true,
            fillColor: AppColors.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('İptal', style: AppTextStyles.bodySecondary),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              foregroundColor: const Color(0xFF1A1206),
            ),
            onPressed: () => Navigator.pop(d, controller.text.trim()),
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (yeni == null || yeni.isEmpty || yeni.length < 2 || _uid == null) return;

    await _fs.collection('kullanicilar').doc(_uid).update({'nick': yeni});
    await _profilYukle();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Takma ad güncellendi.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _cikisYap() async {
    setState(() => _cikiliyor = true);
    await Future.delayed(const Duration(milliseconds: 320));
    try {
      await AuthService().signOut();
    } catch (e) {
      debugPrint('Çıkış hatası: $e');
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _kimlikKarti(Kullanici p) {
    final harf = p.nick.trim().isEmpty ? '?' : p.nick.trim()[0].toUpperCase();
    final arkadasSayisi = p.arkadasIds.length;

    return profilKart(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentAmber.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.accentAmber, Color(0xFFB45309)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  harf,
                  style: const TextStyle(
                    color: Color(0xFF1A1206),
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.nick,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _nickDuzenle,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit,
                          color: AppColors.accentAmber,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  p.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    profilRozet(
                      'Kod: ${p.davetKodu}',
                      AppColors.accentCyan,
                      Icons.qr_code_2_rounded,
                    ),
                    profilRozet(
                      '$arkadasSayisi arkadaş',
                      AppColors.accentBlue,
                      Icons.group_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentAmber),
            )
          : _profil == null
          ? Stack(
              children: [
                const ProfilToz(),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: profilKart(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ProfilNabizIkon(),
                          const SizedBox(height: 16),
                          const Text(
                            'HESAP HAZIRLANIYOR',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Profilin oluşturulamadı — bağlantıyı kontrol edip tekrar dene.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Material(
                            color: AppColors.accentAmber,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() => _yukleniyor = true);
                                _profilYukle();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      color: Color(0xFF1A1206),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'TEKRAR DENE',
                                      style: TextStyle(
                                        color: Color(0xFF1A1206),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                const ProfilToz(),
                ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _kimlikKarti(_profil!),
                    const SizedBox(height: 14),
                    ProfilQrKarti(_profil!),
                    const SizedBox(height: 14),
                    ProfilCikisKarti(cikiliyor: _cikiliyor, onCikis: _cikisYap),
                  ],
                ),
              ],
            ),
    );
  }
}
