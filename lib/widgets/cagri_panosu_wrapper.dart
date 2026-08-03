// lib/widgets/cagri_panosu_wrapper.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math'; // ✅ dalga nabız için
import 'package:flutter/services.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/pages/salon/salon_sayfasi.dart';
import 'package:yaz_boz/widgets/cagri_dialog.dart';

// ─────────────────────────────────────────────────────────────
// ÇAĞRI NABIZ ÇUBUĞU — HAFİF + TEMBEL + DALGA NABIZ
// ─────────────────────────────────────────────────────────────
class CagriPanoWrapper extends StatefulWidget {
  const CagriPanoWrapper({super.key});
  @override
  State<CagriPanoWrapper> createState() => _CagriPanoWrapperState();
}

class _CagriPanoWrapperState extends State<CagriPanoWrapper> {
  late final String? _uid;
  Stream<PanoVerisi>? _stream;
  Timer? _gecikme;
  bool _oncekiKilit = false;

  @override
  void initState() {
    super.initState();
    _uid = AuthService().uid;
    _gecikme = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _uid == null) return;
      setState(() => _stream = CagriServisi().panoStreami(_uid));
    });
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    super.dispose();
  }

  void _zilCal() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('Zil sesi hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const SizedBox.shrink();
    if (_stream == null) return _placeholder(context, _uid);

    return StreamBuilder<PanoVerisi>(
      stream: _stream,
      builder: (context, snap) {
        final v = snap.data ?? PanoVerisi.bos();
        if (v.kilitli && !_oncekiKilit) {
          _oncekiKilit = true;
          _zilCal();
        } else if (!v.kilitli) {
          _oncekiKilit = false;
        }
        return _CagriSeridi(v: v, uid: _uid);
      },
    );
  }

  Widget _placeholder(BuildContext context, String uid) {
    return _serit(
      onTap: () => cagriAcDialogu(context, uid),
      sol: _solMetin(
        etiket: 'ÇAĞRI YOK',
        metin: 'Oyuna çağır',
        renk: Colors.white70,
        ikon: Icons.add_circle_outline,
      ),
      ray: const _StatikRay(onay: 0, kilitli: false, benAcan: false, hedef: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SERİT — Ortak kabuk (değişmedi)
// ─────────────────────────────────────────────────────────────
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
      renk = Colors.white70;
      ikon = Icons.add_circle_outline;
    } else if (v.kilitli) {
      etiket = 'SABİT';
      metin = 'Buluşma onaylandı';
      renk = const Color(0xFF86EFAC);
      ikon = Icons.verified_user_rounded;
    } else if (v.benAcan) {
      etiket = 'MASA';
      metin = v.onaySayisi > 0 ? '${v.onaySayisi} onay geldi…' : 'kuruluyor…';
      renk = const Color(0xFFFCD34D);
      ikon = Icons.table_restaurant;
    } else {
      etiket = 'ÇAĞRI';
      metin = '${v.acanAd ?? 'Biri'} çağırdı';
      renk = const Color(0xFF7DD3FC);
      ikon = Icons.notifications_active_rounded;
    }

    return _serit(
      onTap: () => _tap(context),
      sol: _solMetin(etiket: etiket, metin: metin, renk: renk, ikon: ikon),
      ray: _StatikRay(
        onay: v.onaySayisi,
        kilitli: v.kilitli,
        benAcan: v.benAcan,
        hedef: v.hedef,
      ),
    );
  }
}

// ── ortak kabuk widget'ı (değişmedi) ────────────────────────
Widget _serit({
  required VoidCallback onTap,
  required Widget sol,
  required Widget ray,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0B2A5B)],
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
              child: Container(color: Colors.white.withValues(alpha: 0.22)),
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

Widget _solMetin({
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
                color: Colors.white,
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

// ─────────────────────────────────────────────────────────────
// STATİK RAY — BÜYÜK BUTON + SOLDAN SAĞA DALGA NABIZ
//   • TEK controller, 4 node'a faz kaymalı sin() → ışık yürür
//   • TEMBEL: nabız 1.2 sn sonra başlar (ilk frame temiz)
//   • HAFİF: scale sadece boş halo'da; tik butonu sabit
// ─────────────────────────────────────────────────────────────
class _StatikRay extends StatefulWidget {
  final int onay;
  final bool kilitli;
  final bool benAcan;
  final int hedef;

  const _StatikRay({
    required this.onay,
    required this.kilitli,
    required this.benAcan,
    required this.hedef,
  });

  @override
  State<_StatikRay> createState() => _StatikRayState();
}

class _StatikRayState extends State<_StatikRay>
    with SingleTickerProviderStateMixin {
  AnimationController? _nabiz;
  Timer? _nabizGecikme;

  int get onay => widget.onay;
  bool get kilitli => widget.kilitli;
  int get hedef => widget.hedef;

  static const _kirmizi = Color(0xFFEF4444);
  static const _sari = Color(0xFFF59E0B);
  static const _yesil = Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    // ✅ ilk frame'i boğma; pano yerleşsin, sonra nabızı uyandır
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

  // ✅ soldan sağa akan dalga: her node komşusundan sonra tepe yapar
  double _pulse(int i, double t) {
    return 0.5 + 0.5 * sin(2 * pi * t - i * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _nabiz;
    // nabız henüz uyanmadıysa statik çiz (pulse = 0)
    if (ctrl == null) {
      return _ray((_) => 0.0);
    }
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
    final renk = kilitli ? _yesil : (dolu ? _sari : Colors.white24);
    return Expanded(
      child: Container(
        height: 3, // ✅ biraz kalınlaştı, büyük butona orantılı
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

    // ✅ BÜYÜTÜLDÜ: ana buton 28/24 → 34/28
    const double butonDolu = 34.0;
    const double butonBos = 28.0;
    final double buton = dolu ? butonDolu : butonBos;

    // halo temel boyutu büyütüldü; nabız sadece boş halo'yu ölçekler
    const double haloDolu = 50.0;
    const double haloBos = 42.0;
    final double haloTemel = dolu ? haloDolu : haloBos;

    // aktifse dalga, değilse sönük ve sabit
    final double p = aktif ? pulse : 0.0;
    final double haloOpacity = aktif ? (0.16 + 0.20 * p) : 0.10;
    final double haloScale = aktif ? (0.90 + 0.20 * p) : 1.0;
    final double shadowBlur = aktif ? (5 + 9 * p) : 0.0;
    final double shadowOpacity = aktif ? (0.30 + 0.30 * p) : 0.0;

    return SizedBox(
      width: 40, // ✅ hücre genişledi
      height: 56, // ✅ hücre yükseldi
      child: Stack(
        alignment: Alignment.center,
        children: [
          // halo: scale burada ucuz (içi boş daire, child yok)
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
          // ana buton: SABİT boyut (tik titremesin), sadece gölgesi nabız atar
          Container(
            width: buton,
            height: buton,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: renk,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
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
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
