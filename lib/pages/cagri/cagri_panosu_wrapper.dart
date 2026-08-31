// lib/widgets/cagri_panosu_wrapper.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/pages/salon/salon_sayfasi.dart';
import 'package:yaz_boz/pages/cagri/cagri_dialog.dart';
import 'package:yaz_boz/pages/cagri/cagri_panosu_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

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
      ),
    );
  }
}

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
      ),
    );
  }
}
