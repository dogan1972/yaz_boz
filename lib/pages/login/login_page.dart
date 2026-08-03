import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yaz_boz/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final _email = TextEditingController();
  final _sifre = TextEditingController();
  final _tekrar = TextEditingController();
  late final AnimationController _sars;

  bool _isLogin = true;
  bool _gizle = true;
  bool _yukleniyor = false;
  String? _hata;
  String _adim = ''; // ✅ teşhis: await'in nerede olduğunu ekrana yazar
  int _sn = 0;
  Timer? _durumTimer;

  bool get _emailOk =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
  bool get _sifreOk => _sifre.text.length >= 6;
  bool get _eslesiyor => _tekrar.text.isNotEmpty && _tekrar.text == _sifre.text;
  bool get _hazir => _isLogin
      ? (_emailOk && _sifreOk && !_yukleniyor)
      : (_emailOk && _sifreOk && _eslesiyor && !_yukleniyor);
  double get _doluluk => (_emailOk ? 0.5 : 0.0) + (_sifreOk ? 0.5 : 0.0);

  @override
  void initState() {
    super.initState();
    _sars = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _email.addListener(() => setState(() {}));
    _sifre.addListener(() => setState(() {}));
    _tekrar.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _durumTimer?.cancel();
    _email.dispose();
    _sifre.dispose();
    _tekrar.dispose();
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
      setState(() => _sn++); // sadece sayaç; metni _adim taşır
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
      if (!_emailOk || !_sifreOk || !_eslesiyor) {
        setState(
          () => _hata = !_eslesiyor
              ? 'Şifreler eşleşmiyor.'
              : 'Geçerli bir e-posta ve en az 6 haneli şifre girin.',
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      body: Stack(
        children: [
          const _Toz(),
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
                      _AsiliAmpul(seviye: _doluluk, islem: _yukleniyor),
                      const SizedBox(height: 16),
                      const Text(
                        'YAZ BOZ',
                        style: TextStyle(
                          color: Color(0xFFF8FAFC),
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
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 2.6,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _alan(
                        controller: _email,
                        label: 'E-POSTA',
                        hint: 'ornek@posta.com',
                        ikon: Icons.mail_outline,
                        klavye: TextInputType.emailAddress,
                        gecerli: _emailOk,
                      ),
                      const SizedBox(height: 14),
                      _alan(
                        controller: _sifre,
                        label: 'ŞİFRE',
                        hint: 'en az 6 karakter',
                        ikon: Icons.lock_outline,
                        gizli: _gizle,
                        gecerli: _sifreOk,
                        ek: IconButton(
                          icon: Icon(
                            _gizle ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _gizle = !_gizle),
                        ),
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 14),
                        _alan(
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
                        _HataSeridi(_hata!, _sars),
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
                                color: Color(0xFF94A3B8),
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
                                    color: Color(0xFFFCD34D),
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

  // ── teşhis satırı: _adim + sayaç + VAZGEÇ ─────────────────
  Widget _durumIzi() {
    return Row(
      children: [
        const _NabizNokta(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$_adim   (${_sn}sn)',
            style: const TextStyle(
              color: Color(0xFFFCD34D),
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
                color: const Color(0xFF7A1419).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'VAZGEÇ',
                style: TextStyle(
                  color: Color(0xFFFCA5A5),
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

  Widget _alan({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData ikon,
    bool gizli = false,
    bool gecerli = false,
    bool hatali = false,
    TextInputType? klavye,
    Widget? ek,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Focus(
          child: Builder(
            builder: (fc) {
              final odak = Focus.of(fc).hasFocus;
              final cerceve = hatali
                  ? const Color(0xFFEF4444)
                  : (gecerli
                        ? const Color(0xFF2DD4BF)
                        : (odak
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF1E293B)));
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2B),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: cerceve, width: odak ? 1.6 : 1.2),
                  boxShadow: odak
                      ? [
                          BoxShadow(
                            color: cerceve.withValues(alpha: 0.18),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(ikon, color: const Color(0xFF64748B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        obscureText: gizli,
                        keyboardType: klavye,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    if (gecerli)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFF2DD4BF),
                          size: 18,
                        ),
                      ),
                    ek ?? const SizedBox(width: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buton() {
    final renk = _isLogin ? const Color(0xFFF59E0B) : const Color(0xFF2DD4BF);
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
              color: _hazir ? renk : const Color(0xFF1E293B),
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
                                : const Color(0xFF475569),
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
}

class _HataSeridi extends StatelessWidget {
  final String metin;
  final AnimationController sars;
  const _HataSeridi(this.metin, this.sars);
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sars,
      builder: (_, _) {
        final s = sars.value;
        final dx = s > 0 && s < 1
            ? 6 * (1 - s) * (s * 10 % 2 == 0 ? 1 : -1)
            : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF7A1419).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFCA5A5),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metin,
                    style: const TextStyle(
                      color: Color(0xFFFECACA),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NabizNokta extends StatefulWidget {
  const _NabizNokta();
  @override
  State<_NabizNokta> createState() => _NabizNoktaState();
}

class _NabizNoktaState extends State<_NabizNokta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF59E0B),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.6 * t),
                blurRadius: 8 + 6 * t,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AsiliAmpul extends StatefulWidget {
  final double seviye;
  final bool islem;
  const _AsiliAmpul({required this.seviye, required this.islem});
  @override
  State<_AsiliAmpul> createState() => _AsiliAmpulState();
}

class _AsiliAmpulState extends State<_AsiliAmpul>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final s = widget.seviye.clamp(0.0, 1.0);
        final t = _c.value;
        final Color cam;
        final Color filaman;
        final Color halo;
        if (widget.islem) {
          cam = const Color(0xFF6B3A06);
          filaman = const Color(0xFFFCD34D);
          halo = const Color(0xFFF59E0B);
        } else {
          cam = Color.lerp(
            const Color(0xFF3A1012),
            const Color(0xFF0E3A66),
            s,
          )!;
          filaman = Color.lerp(
            const Color(0xFFFF7A4D),
            const Color(0xFF7DD3FC),
            s,
          )!;
          halo = Color.lerp(
            const Color(0xFFE03A2E),
            const Color(0xFF38BDF8),
            s,
          )!;
        }
        final glow = widget.islem ? (0.7 + 0.3 * t) : (0.4 + 0.6 * s);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(width: 2, height: 16, color: const Color(0xFF475569)),
              Container(
                width: 18,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF64748B), Color(0xFF334155)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 92 + (widget.islem ? 8 * t : 0),
                    height: 92 + (widget.islem ? 8 * t : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          halo.withValues(alpha: (0.18 + 0.4 * glow)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [cam, cam.withValues(alpha: 0.6)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: filaman.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: halo.withValues(alpha: 0.5 * glow),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 12,
                          top: 10,
                          child: Container(
                            width: 12,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            color: filaman.withValues(alpha: 0.5 + 0.5 * glow),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Toz extends StatefulWidget {
  const _Toz();
  @override
  State<_Toz> createState() => _TozState();
}

class _TozState extends State<_Toz> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_P> _p;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 15))
      ..repeat();
    final r = Random();
    _p = List.generate(14, (_) => _P(r));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _TozBoyaci(_p, _c.value)),
        ),
      ),
    );
  }
}

class _P {
  final double x, y0, r, hiz, faz;
  final Color renk;
  _P(Random r)
    : x = r.nextDouble(),
      y0 = r.nextDouble(),
      r = 1 + r.nextDouble() * 2.2,
      hiz = 0.4 + r.nextDouble() * 0.8,
      faz = r.nextDouble(),
      renk = r.nextBool() ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);
}

class _TozBoyaci extends CustomPainter {
  final List<_P> p;
  final double t;
  _TozBoyaci(this.p, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final e in p) {
      final y = (e.y0 + t * e.hiz + e.faz) % 1.0;
      final dy = (1 - y) * size.height;
      final op = (0.10 + 0.18 * (1 - (y - 0.5).abs() * 2)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(e.x * size.width, dy),
        e.r,
        Paint()..color = e.renk.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TozBoyaci old) => old.t != t;
}
