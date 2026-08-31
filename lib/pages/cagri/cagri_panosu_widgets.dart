// lib/widgets/cagri_panosu_widgets.dart
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Sol Taraf Metin ve İkon Bileşeni
Widget panoSolMetin({
  required String etiket,
  required String metin,
  required Color renk,
  required IconData ikon,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(ikon, color: renk, size: 18),
      const SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiket,
            style: TextStyle(
              color: renk.withValues(alpha: 0.8),
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              metin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Ortak Serit Kabuğu
Widget panoSeritKabuk({
  required VoidCallback onTap,
  required Widget sol,
  required Widget ray,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentBlue.withValues(alpha: 0.8),
              AppColors.bgSecondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: Container(
                color: AppColors.textPrimary.withValues(alpha: 0.22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
              child: Row(
                children: [
                  sol,
                  const SizedBox(width: 12),
                  Expanded(child: ray),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Statik Ray - 4 Adımlı Onay Göstergesi
class PanoStatikRay extends StatefulWidget {
  final int onay;
  final bool kilitli;
  final bool benAcan;
  final int hedef;
  const PanoStatikRay({
    super.key,
    required this.onay,
    required this.kilitli,
    required this.benAcan,
    required this.hedef,
  });

  @override
  State<PanoStatikRay> createState() => _PanoStatikRayState();
}

class _PanoStatikRayState extends State<PanoStatikRay>
    with SingleTickerProviderStateMixin {
  AnimationController? _nabiz;
  Timer? _nabizGecikme;

  int get onay => widget.onay;
  bool get kilitli => widget.kilitli;
  int get hedef => widget.hedef;

  static const _kirmizi = Color(0xFFEF4444);
  static const _sari = AppColors.accentAmber;
  static const _yesil = AppColors.accentGreen;

  @override
  void initState() {
    super.initState();
    _nabizGecikme = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _nabiz = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )..repeat();
      });
    });
  }

  @override
  void dispose() {
    _nabizGecikme?.cancel();
    _nabiz?.dispose();
    super.dispose();
  }

  Color _renk(int i) {
    if (i == 0) return _yesil;
    if (kilitli) return _yesil;
    if (i <= onay) return _yesil;
    if (i <= hedef) return _sari;
    return _kirmizi;
  }

  bool _nabizAktif(int i) {
    if (i == 0) return true;
    if (kilitli) return true;
    if (i <= hedef) return true;
    return false;
  }

  double _pulse(int i, double t) => 0.5 + 0.5 * sin(2 * pi * t - i * 0.9);

  @override
  Widget build(BuildContext context) {
    final ctrl = _nabiz;
    if (ctrl == null) return _ray((_) => 0.0);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) => _ray((i) => _pulse(i, ctrl.value)),
    );
  }

  Widget _ray(double Function(int i) pulseOf) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) _parca(i),
          _node(i, pulseOf(i)),
        ],
      ],
    );
  }

  Widget _parca(int i) {
    final dolu = kilitli || (i - 1) < onay;
    final renk = kilitli
        ? _yesil
        : (dolu ? _sari : AppColors.textPrimary.withValues(alpha: 0.24));
    return Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: renk.withValues(alpha: dolu ? 0.85 : 0.4),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  Widget _node(int i, double pulse) {
    final renk = _renk(i);
    final aktif = _nabizAktif(i);
    final dolu = kilitli || (i == 0) || (i <= onay);

    const double butonDolu = 34.0;
    const double butonBos = 28.0;
    final double buton = dolu ? butonDolu : butonBos;

    const double haloDolu = 50.0;
    const double haloBos = 42.0;
    final double haloTemel = dolu ? haloDolu : haloBos;

    final double p = aktif ? pulse : 0.0;
    final double haloOpacity = aktif ? (0.16 + 0.20 * p) : 0.10;
    final double haloScale = aktif ? (0.90 + 0.20 * p) : 1.0;
    final double shadowBlur = aktif ? (5 + 9 * p) : 0.0;
    final double shadowOpacity = aktif ? (0.30 + 0.30 * p) : 0.0;

    return SizedBox(
      width: 40,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: haloScale,
            child: Container(
              width: haloTemel,
              height: haloTemel,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: renk.withValues(alpha: haloOpacity),
              ),
            ),
          ),
          Container(
            width: buton,
            height: buton,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: renk,
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.9),
                width: 1.8,
              ),
              boxShadow: aktif
                  ? [
                      BoxShadow(
                        color: renk.withValues(alpha: shadowOpacity),
                        blurRadius: shadowBlur,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: dolu
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  )
                : Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textPrimary.withValues(alpha: 0.6),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
