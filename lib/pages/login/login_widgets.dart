// lib/pages/login/login_widgets.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Özel Input Alanı (Focus & Validasyon Animasyonlu)
Widget loginInputAlani({
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
          color: AppColors.textSecondary,
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
                ? AppColors.accentRed
                : (gecerli
                      ? AppColors.accentCyan
                      : (odak ? AppColors.accentAmber : AppColors.border));
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
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
                  Icon(ikon, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      obscureText: gizli,
                      keyboardType: klavye,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(
                          color: AppColors.divider,
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
                        color: AppColors.accentCyan,
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

/// Asılı Ampul Bileşeni
class LoginAsiliAmpul extends StatefulWidget {
  final double seviye;
  final bool islem;
  const LoginAsiliAmpul({super.key, required this.seviye, required this.islem});
  @override
  State<LoginAsiliAmpul> createState() => _LoginAsiliAmpulState();
}

class _LoginAsiliAmpulState extends State<LoginAsiliAmpul>
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
        final Color cam, filaman, halo;
        if (widget.islem) {
          cam = const Color(0xFF6B3A06);
          filaman = const Color(0xFFFCD34D);
          halo = AppColors.accentAmber;
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
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(width: 2, height: 16, color: const Color(0xFF475569)),
              Container(
                width: 18,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.textHint, AppColors.divider],
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

/// Arka Plan Toz Partikülleri
class LoginToz extends StatefulWidget {
  const LoginToz({super.key});
  @override
  State<LoginToz> createState() => _LoginTozState();
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
      renk = r.nextBool() ? AppColors.accentAmber : AppColors.accentCyan;
}

class _LoginTozState extends State<LoginToz>
    with SingleTickerProviderStateMixin {
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

/// Sarsılan Hata Seridi
class LoginHataSeridi extends StatelessWidget {
  final String metin;
  final AnimationController sars;
  const LoginHataSeridi(this.metin, this.sars, {super.key});
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
              color: AppColors.accentRed.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppColors.accentRed.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.accentRed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metin,
                    style: const TextStyle(
                      color: AppColors.accentRed,
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

/// Nabız Atan Durum Noktası
class LoginNabizNokta extends StatefulWidget {
  const LoginNabizNokta({super.key});
  @override
  State<LoginNabizNokta> createState() => _LoginNabizNoktaState();
}

class _LoginNabizNoktaState extends State<LoginNabizNokta>
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
            color: AppColors.accentAmber,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentAmber.withValues(alpha: 0.6 * t),
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
