// lib/widgets/app_widgets.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Ambient Köşe Işığı
Widget appGlow(Color renk, double boyut) {
  return IgnorePointer(
    child: Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [renk.withValues(alpha: 0.10), Colors.transparent],
        ),
      ),
    ),
  );
}

/// Dashboard Menü Butonu
Widget appMenuButon({
  required double genislik,
  required bool isYatay,
  required IconData icon,
  required Color renk,
  required String baslik,
  required String altBaslik,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      splashColor: renk.withValues(alpha: 0.18),
      highlightColor: renk.withValues(alpha: 0.10),
      child: Container(
        width: genislik,
        height: isYatay ? 104.0 : 122.0,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: renk.withValues(alpha: 0.35), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: renk.withValues(alpha: 0.18),
              blurRadius: 14.0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: (isYatay ? 30.0 : 38.0),
                height: (isYatay ? 30.0 : 38.0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: renk.withValues(alpha: 0.16),
                  border: Border.all(
                    color: renk.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, color: renk, size: isYatay ? 18.0 : 22.0),
              ),
              SizedBox(height: isYatay ? 6.0 : 8.0),
              Text(
                baslik,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: isYatay ? 13.0 : 14.0,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3.0),
              Text(
                altBaslik,
                style: const TextStyle(
                  fontSize: 10.0,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Dashboard Toz Partikülleri
class AppDashboardToz extends StatefulWidget {
  const AppDashboardToz({super.key});
  @override
  State<AppDashboardToz> createState() => _AppDashboardTozState();
}

class _DT {
  final double x, y0, r, hiz, faz;
  final Color renk;
  _DT(Random r)
    : x = r.nextDouble(),
      y0 = r.nextDouble(),
      r = 1 + r.nextDouble() * 2.0,
      hiz = 0.25 + r.nextDouble() * 0.6,
      faz = r.nextDouble(),
      renk = r.nextBool() ? AppColors.accentAmber : AppColors.accentCyan;
}

class _AppDashboardTozState extends State<AppDashboardToz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_DT> _p;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    final r = Random();
    _p = List.generate(14, (_) => _DT(r));
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
          child: CustomPaint(painter: _AppDashboardTozBoyaci(_p, _c.value)),
        ),
      ),
    );
  }
}

class _AppDashboardTozBoyaci extends CustomPainter {
  final List<_DT> p;
  final double t;
  _AppDashboardTozBoyaci(this.p, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in p) {
      final y = (e.y0 + t * e.hiz + e.faz) % 1.0;
      final dy = (1 - y) * size.height;
      final op = (0.05 + 0.12 * (1 - (y - 0.5).abs() * 2)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(e.x * size.width, dy),
        e.r,
        Paint()..color = e.renk.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AppDashboardTozBoyaci old) => old.t != t;
}

/// Global Hata Kartı (ErrorWidget.builder için)
class AppHataKarti extends StatelessWidget {
  final String baslik;
  final String hata;
  final String? stack;

  const AppHataKarti({
    super.key,
    required this.baslik,
    required this.hata,
    this.stack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accentRed, Color(0xFFB91C1C)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.accentRed.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bug_report_outlined,
                                  color: Color(0xFFDC2626),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      baslik,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 1.6,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Bir hata yakalandı — uygulama çökmedi.',
                                      style: TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  '$hata${stack != null ? '\n\n— stack —\n$stack' : ''}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Bu metni geliştiriciye iletin — kök neden burada yazar.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
