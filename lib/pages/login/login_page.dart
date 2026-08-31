// lib/pages/login/login_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/pages/login/login_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final _adSoyad = TextEditingController();
  final _email = TextEditingController();
  final _sifre = TextEditingController();
  final _tekrar = TextEditingController();
  late final AnimationController _sars;

  bool _isLogin = true;
  bool _gizle = true;
  bool _yukleniyor = false;
  String? _hata;
  String _adim = '';
  int _sn = 0;
  Timer? _durumTimer;

  bool get _adSoyadOk => _adSoyad.text.trim().length >= 2;
  bool get _emailOk =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
  bool get _sifreOk => _sifre.text.length >= 6;
  bool get _eslesiyor => _tekrar.text.isNotEmpty && _tekrar.text == _sifre.text;

  bool get _hazir => _isLogin
      ? (_emailOk && _sifreOk && !_yukleniyor)
      : (_adSoyadOk && _emailOk && _sifreOk && _eslesiyor && !_yukleniyor);

  // ✅ _doluluk KALDIRILDI (Artık kullanılmıyor)

  @override
  void initState() {
    super.initState();
    _sars = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _adSoyad.addListener(() => setState(() {}));
    _email.addListener(() => setState(() {}));
    _sifre.addListener(() => setState(() {}));
    _tekrar.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _durumTimer?.cancel();
    _adSoyad.dispose();
    _email.dispose();
    _sifre.dispose();
    _tekrar.dispose();
    _sars.stop();
    _sars.dispose();
    super.dispose();
  }

  void _durumBaslat() {
    _sn = 0;
    _adim = 'bağlanılıyor…';
    _durumTimer?.cancel();
    _durumTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _sn++);
    });
  }

  void _durumDurdur() {
    _durumTimer?.cancel();
    _durumTimer = null;
  }

  void _vazgec() {
    _durumDurdur();
    setState(() {
      _yukleniyor = false;
      _adim = 'vazgeçildi';
    });
  }

  Future<void> _submit() async {
    if (_isLogin) {
      if (!_emailOk || !_sifreOk) {
        setState(
          () => _hata = 'Geçerli bir e-posta ve en az 6 haneli şifre girin.',
        );
        _sars.forward(from: 0);
        return;
      }
    } else {
      if (!_adSoyadOk || !_emailOk || !_sifreOk || !_eslesiyor) {
        setState(() {
          if (!_eslesiyor) {
            _hata = 'Şifreler eşleşmiyor.';
          } else if (!_adSoyadOk) {
            _hata = 'Ad soyad en az 2 karakter olmalı.';
          } else {
            _hata = 'Geçerli bir e-posta ve en az 6 haneli şifre girin.';
          }
        });
        _sars.forward(from: 0);
        return;
      }
    }

    setState(() {
      _yukleniyor = true;
      _hata = null;
      _adim = 'hazırlanıyor';
    });
    _durumBaslat();
    try {
      if (mounted) setState(() => _adim = 'auth isteği yolda…');
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(_email.text.trim(), _sifre.text);
      } else {
        await _auth.createUserWithEmailAndPassword(
          _email.text.trim(),
          _sifre.text,
          _adSoyad.text.trim(),
        );
      }
      if (mounted) setState(() => _adim = 'auth yanıt verdi ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adim = 'hata yakalandı';
        _hata = e.toString();
      });
      _sars.forward(from: 0);
    } finally {
      _durumDurdur();
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Widget _durumIzi() {
    return Row(
      children: [
        const LoginNabizNokta(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$_adim   (${_sn}sn)',
            style: const TextStyle(
              color: AppColors.accentAmber,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (_sn >= 4)
          GestureDetector(
            onTap: _vazgec,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: AppColors.accentRed.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'VAZGEÇ',
                style: TextStyle(
                  color: AppColors.accentRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buton() {
    final renk = _isLogin ? AppColors.accentAmber : AppColors.accentCyan;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedBuilder(
        animation: _sars,
        builder: (_, _) {
          final s = _sars.value;
          final dx = s > 0 && s < 1
              ? 5 * (1 - s) * (s * 8 % 2 == 0 ? 1 : -1)
              : 0.0;

          return Transform.translate(
            offset: Offset(dx, 0),
            child: Material(
              borderRadius: BorderRadius.circular(14),
              color: _hazir ? renk : AppColors.border,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                splashColor: renk.withValues(alpha: 0.4),
                onTap: _hazir ? _submit : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _hazir
                        ? [
                            BoxShadow(
                              color: renk.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _yukleniyor
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation(
                                  _isLogin
                                      ? const Color(0xFF1A1206)
                                      : const Color(0xFF06231F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'İŞLENİYOR',
                              style: TextStyle(
                                color: Color(0xFF1A1206),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _isLogin ? 'GİRİŞ YAP' : 'HESABI OLUŞTUR',
                          style: TextStyle(
                            color: _hazir
                                ? const Color(0xFF1A1206)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 1.4,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const LoginToz(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(26, 10, 26, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'YAZ BOZ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 42,
                          height: 0.92,
                          letterSpacing: -1.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'masaya geri dön' : 'yeni bir koltuk aç',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 2.6,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (!_isLogin) ...[
                        loginInputAlani(
                          controller: _adSoyad,
                          label: 'AD SOYAD',
                          hint: 'örn. Doğan Yılmaz',
                          ikon: Icons.person_outline,
                          klavye: TextInputType.name,
                          gecerli: _adSoyadOk,
                        ),
                        const SizedBox(height: 14),
                      ],
                      loginInputAlani(
                        controller: _email,
                        label: 'E-POSTA',
                        hint: 'ornek@posta.com',
                        ikon: Icons.mail_outline,
                        klavye: TextInputType.emailAddress,
                        gecerli: _emailOk,
                      ),
                      const SizedBox(height: 14),
                      loginInputAlani(
                        controller: _sifre,
                        label: 'ŞİFRE',
                        hint: 'en az 6 karakter',
                        ikon: Icons.lock_outline,
                        gizli: _gizle,
                        gecerli: _sifreOk,
                        ek: IconButton(
                          icon: Icon(
                            _gizle ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _gizle = !_gizle),
                        ),
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 14),
                        loginInputAlani(
                          controller: _tekrar,
                          label: 'ŞİFRE TEKRAR',
                          hint: 'bir daha yaz',
                          ikon: Icons.lock_outline,
                          gizli: _gizle,
                          gecerli: _eslesiyor,
                          hatali: _tekrar.text.isNotEmpty && !_eslesiyor,
                        ),
                      ],
                      if (_hata != null) ...[
                        const SizedBox(height: 14),
                        LoginHataSeridi(_hata!, _sars),
                      ],
                      const SizedBox(height: 18),
                      if (_yukleniyor) _durumIzi(),
                      if (_yukleniyor) const SizedBox(height: 12),
                      _buton(),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: _yukleniyor
                              ? null
                              : () => setState(() {
                                  _isLogin = !_isLogin;
                                  _hata = null;
                                }),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: _isLogin
                                      ? 'Hesabın yok mu?  '
                                      : 'Zaten üye misin?  ',
                                ),
                                TextSpan(
                                  text: _isLogin ? 'Kayıt ol' : 'Giriş yap',
                                  style: const TextStyle(
                                    color: AppColors.accentAmber,
                                    fontWeight: FontWeight.w800,
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
          ),
        ],
      ),
    );
  }
}
