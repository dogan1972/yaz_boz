// lib/pages/salon/salon_widgets.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/theme/app_theme.dart';

/// Ortak Panel Yapısı
Widget salonPanel({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

/// Masa Çizimi (CustomPainter)
class SalonMasaBoyaci extends CustomPainter {
  final bool solgun;
  const SalonMasaBoyaci({this.solgun = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.44);
    final rx = size.width * 0.34;
    final ry = size.height * 0.30;
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    final amber = solgun ? AppColors.textSecondary : AppColors.accentAmber;

    // Gölge
    canvas.drawOval(
      Rect.fromCenter(
        center: c + const Offset(0, 10),
        width: rx * 2,
        height: ry * 2,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Masa Gövdesi
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Color(0xFF1B2740), Color(0xFF0E1626)],
        ).createShader(rect),
    );

    // Masa Kenarı
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = amber.withValues(alpha: solgun ? 0.12 : 0.22)
        ..strokeWidth = 1.4,
    );

    // İç Halkalar
    for (var i = 1; i <= 3; i++) {
      final f = 1 - i * 0.22;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2 * f, height: ry * 2 * f),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.divider.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
    }

    // Merkez Parıltı
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 0.9, height: ry * 0.9),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                amber.withValues(alpha: solgun ? 0.04 : 0.10),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCenter(center: c, width: rx * 0.9, height: ry * 0.9),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant SalonMasaBoyaci old) => old.solgun != solgun;
}

/// Sandalye Bileşeni
class SalonSandalye extends StatelessWidget {
  final String uid;
  final String ad;
  final bool acan;
  final bool onayli;
  final bool benim;
  final Cagri cagri;
  final VoidCallback? onOnayla;

  const SalonSandalye({
    super.key,
    required this.uid,
    required this.ad,
    required this.acan,
    required this.onayli,
    required this.benim,
    required this.cagri,
    this.onOnayla,
  });

  @override
  Widget build(BuildContext context) {
    final bekliyor = !acan && !onayli;
    final renk = acan
        ? AppColors.accentAmber
        : (onayli ? AppColors.accentCyan : AppColors.divider);
    final harf = ad.trim().isEmpty ? '?' : ad.trim()[0].toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    renk.withValues(alpha: onayli ? 0.4 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: acan
                      ? [AppColors.accentAmber, const Color(0xFFB45309)]
                      : (onayli
                            ? [AppColors.accentCyan, const Color(0xFF0E7490)]
                            : [AppColors.divider, AppColors.border]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: renk.withValues(alpha: 0.6),
                  width: benim ? 2.2 : 1.2,
                ),
              ),
              child: Text(
                harf,
                style: const TextStyle(
                  color: AppColors.bgPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: renk, width: 1.2),
                ),
                child: Icon(
                  acan
                      ? Icons.star_rounded
                      : (onayli ? Icons.check_rounded : Icons.hourglass_bottom),
                  color: renk,
                  size: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          ad,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onayli ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),

        // ✅ ONAY BUTONU: Sadece bekleyen, bende olan ve sonlanmamış çağrılar için
        if (bekliyor && cagri.durum != 'sonlandi' && benim)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Material(
              color: AppColors.accentCyan,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onOnayla,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Text(
                    cagri.yer == null || cagri.yer!.isEmpty
                        ? 'DETAY BEKLENİYOR'
                        : 'ONAYLA',
                    style: TextStyle(
                      color: cagri.yer == null || cagri.yer!.isEmpty
                          ? AppColors.textHint
                          : const Color(0xFF06231F),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (!benim && onayli)
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.check_circle,
              color: AppColors.accentCyan,
              size: 16,
            ),
          ),
      ],
    );
  }
}

/// Kilit Flash Animasyonu
class SalonKilitFlash extends StatelessWidget {
  final AnimationController muhur;
  const SalonKilitFlash({super.key, required this.muhur});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: muhur,
          builder: (_, _) {
            final t = muhur.value;
            return Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Container(
                color: AppColors.bgPrimary.withValues(alpha: 0.55),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 320 * (0.6 + 0.6 * t),
                      height: 320 * (0.6 + 0.6 * t),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accentAmber.withValues(
                              alpha: 0.35 * (1 - t),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: (1 - t) * -0.5,
                      child: Transform.scale(
                        scale: 0.7 + 0.5 * Curves.easeOutBack.transform(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.accentCyan,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.bgPrimary.withValues(alpha: 0.6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.accentCyan,
                                size: 26,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'SABİTLENDİ',
                                style: TextStyle(
                                  color: AppColors.accentCyan,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: 2,
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
            );
          },
        ),
      ),
    );
  }
}

/// Salon Toz Partikülleri
class SalonToz extends StatefulWidget {
  const SalonToz({super.key});
  @override
  State<SalonToz> createState() => _SalonTozState();
}

class _P {
  final double x, y0, r, hiz, faz;
  final Color renk;
  _P(Random r)
    : x = r.nextDouble(),
      y0 = r.nextDouble(),
      r = 1 + r.nextDouble() * 2.2,
      hiz = 0.3 + r.nextDouble() * 0.7,
      faz = r.nextDouble(),
      renk = r.nextBool() ? AppColors.accentAmber : AppColors.accentCyan;
}

class _SalonTozState extends State<SalonToz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_P> _p;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
    final r = Random();
    _p = List.generate(16, (_) => _P(r));
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
          child: CustomPaint(painter: _SalonTozBoyaci(_p, _c.value)),
        ),
      ),
    );
  }
}

class _SalonTozBoyaci extends CustomPainter {
  final List<_P> p;
  final double t;
  _SalonTozBoyaci(this.p, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in p) {
      final y = (e.y0 + t * e.hiz + e.faz) % 1.0;
      final dy = (1 - y) * size.height;
      final op = (0.06 + 0.14 * (1 - (y - 0.5).abs() * 2)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(e.x * size.width, dy),
        e.r,
        Paint()..color = e.renk.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SalonTozBoyaci old) => old.t != t;
}

/// Masa Ortası Bilgi (Tarih/Saat/Yer veya Boş Durum)
class SalonOrtaBilgi extends StatefulWidget {
  final Cagri cagri;
  const SalonOrtaBilgi({super.key, required this.cagri});
  @override
  State<SalonOrtaBilgi> createState() => _SalonOrtaBilgiState();
}

class _SalonOrtaBilgiState extends State<SalonOrtaBilgi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cagri.durum == 'sonlandi') {
      return const KeyedSubtree(
        key: ValueKey('sonlandi'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.power_settings_new,
              color: AppColors.textSecondary,
              size: 28,
            ),
            SizedBox(height: 6),
            Text(
              'masa\ndağıldı',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.cagri.yer == null || widget.cagri.yer!.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('bos'),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_restaurant,
                  color: AppColors.accentAmber.withValues(alpha: 0.5 + 0.4 * t),
                  size: 30 + 3 * t,
                ),
                const SizedBox(height: 6),
                Text(
                  'detay\nbekleniyor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(
                      alpha: 0.6 + 0.4 * t,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // ✅ YENİ TASARIM: MEKAN ADI + SAAT
    return KeyedSubtree(
      key: const ValueKey('dolu'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.cagri.yer ?? 'Mekan Belirtilmedi',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                height: 1.2,
              ),
            ),
          ),
          if (widget.cagri.saat != null && widget.cagri.saat!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, color: AppColors.accentAmber, size: 14),
                const SizedBox(width: 4),
                Text(
                  widget.cagri.saat!,
                  style: const TextStyle(
                    color: AppColors.accentAmber,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
