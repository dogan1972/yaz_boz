// lib/widgets/cagri_panosu.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/pages/salon/salon_sayfasi.dart';
import 'package:yaz_boz/pages/cagri/cagri_dialog.dart';
import 'package:yaz_boz/theme/app_theme.dart';

// ============================================================
// 1. WRAPPER SINIFI (Stream Yönetimi)
// ============================================================

class CagriPanoWrapper extends StatefulWidget {
  const CagriPanoWrapper({super.key});

  @override
  State<CagriPanoWrapper> createState() => _CagriPanoWrapperState();
}

class _CagriPanoWrapperState extends State<CagriPanoWrapper> {
  String? _uid;
  Stream<PanoVerisi>? _stream;
  Timer? _gecikme;
  bool _oncekiKilit = false;
  StreamSubscription<PanoVerisi>? _panoSub;

  @override
  void initState() {
    super.initState();
    _uid = AuthService().uid;
    _baslat();
  }

  void _baslat() {
    _gecikme = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _uid == null) return;
      _panoSub?.cancel();
      setState(() {
        _stream = CagriServisi().panoStreami(_uid!);
      });
    });
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _panoSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) return const SizedBox.shrink();

    if (_stream == null) return _placeholder(context, uid);

    return StreamBuilder<PanoVerisi>(
      stream: _stream,
      builder: (context, snap) {
        if (!context.mounted) return const SizedBox.shrink();
        final v = snap.data ?? PanoVerisi.bos();

        if (v.kilitli && !_oncekiKilit) {
          _oncekiKilit = true;
        } else if (!v.kilitli) {
          _oncekiKilit = false;
        }

        return _CagriSeridi(v: v, uid: uid);
      },
    );
  }

  Widget _placeholder(BuildContext context, String uid) {
    return panoSeritKabuk(
      onTap: () => cagriAcDialogu(context, uid),
      sol: panoSolMetin(
        etiket: 'ÇAĞRI YOK',
        metin: 'Oyuna çağır',
        renk: AppColors.textPrimary.withValues(alpha: 0.7),
        ikon: Icons.add_circle_outline,
      ),
      ray: const PanoStatikRay(
        onay: 0,
        kilitli: false,
        benAcan: false,
        hedef: 0,
        aktif: false, // ✅ EKLENDİ
      ),
    );
  }
}

// ============================================================
// 2. SERİT GÖRÜNÜMÜ (Durum Metni ve Ray Bağlantısı)
// ============================================================

class _CagriSeridi extends StatelessWidget {
  final PanoVerisi v;
  final String uid;
  const _CagriSeridi({required this.v, required this.uid});

  void _tap(BuildContext context) {
    if (v.aktif && v.cagriId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SalonSayfasi(cagriId: v.cagriId!, uid: uid),
        ),
      );
    } else {
      cagriAcDialogu(context, uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    String etiket, metin;
    Color renk;
    IconData ikon;

    if (!v.aktif) {
      etiket = 'ÇAĞRI YOK';
      metin = 'Oyuna çağır';
      renk = AppColors.textPrimary.withValues(alpha: 0.7);
      ikon = Icons.add_circle_outline;
    } else if (v.kilitli) {
      etiket = 'SABİT';
      metin = 'Buluşma onaylandı';
      renk = AppColors.accentGreen.withValues(alpha: 0.9);
      ikon = Icons.verified_user_rounded;
    } else if (v.benAcan) {
      etiket = 'MASA';
      metin = v.onaySayisi > 0 ? '${v.onaySayisi} onay geldi…' : 'kuruluyor…';
      renk = AppColors.accentAmber;
      ikon = Icons.table_restaurant;
    } else {
      etiket = 'ÇAĞRI';
      metin = '${v.acanAd ?? 'Biri'} çağırdı';
      renk = AppColors.accentCyan;
      ikon = Icons.notifications_active_rounded;
    }

    return panoSeritKabuk(
      onTap: () => _tap(context),
      sol: panoSolMetin(etiket: etiket, metin: metin, renk: renk, ikon: ikon),
      ray: PanoStatikRay(
        onay: v.onaySayisi,
        kilitli: v.kilitli,
        benAcan: v.benAcan,
        hedef: v.hedef,
        aktif: v.aktif, // ✅ EKLENDİ
      ),
    );
  }
}

// ============================================================
// 3. YARDIMCI WIDGET'LAR (Metin, Kabuk ve Animasyonlu Ray)
// ============================================================

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

class PanoStatikRay extends StatefulWidget {
  final int onay, hedef;
  final bool kilitli, benAcan, aktif; // ✅ aktif eklendi
  const PanoStatikRay({
    super.key,
    required this.onay,
    required this.kilitli,
    required this.benAcan,
    required this.hedef,
    required this.aktif, // ✅ zorunlu parametre
  });

  @override
  State<PanoStatikRay> createState() => _PanoStatikRayState();
}

class _PanoStatikRayState extends State<PanoStatikRay>
    with SingleTickerProviderStateMixin {
  AnimationController? _nabiz;
  Timer? _nabizGecikme;

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
    // ✅ Aktif değilse renkleri sönük/gri yap
    if (!widget.aktif) return AppColors.textPrimary.withValues(alpha: 0.3);

    if (widget.kilitli) return _yesil;
    if (i < widget.onay) return _yesil;
    if (i < widget.hedef) return _sari;
    return _kirmizi;
  }

  bool _nabizAktif(int i) =>
      !widget.kilitli && i < widget.hedef && widget.aktif;

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
    // ✅ DÜZELTME: aktif değilse parçalar da sönük olmalı
    final dolu = widget.aktif && (widget.kilitli || (i <= widget.onay));
    final renk = !widget.aktif
        ? AppColors.textPrimary.withValues(alpha: 0.24)
        : (widget.kilitli
              ? _yesil
              : (dolu ? _sari : AppColors.textPrimary.withValues(alpha: 0.24)));
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

    // ✅ KRİTİK DÜZELTME: Tik sadece aktifse VEYA kilitliyse görünür
    final dolu = widget.aktif && (widget.kilitli || (i < widget.onay));

    const double butonDolu = 34.0,
        butonBos = 28.0,
        haloDolu = 50.0,
        haloBos = 42.0;
    final double buton = dolu ? butonDolu : butonBos;
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
