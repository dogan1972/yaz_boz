// lib/pages/cagri/cagri_ana_sayfasi.dart

import 'package:flutter/material.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/pages/cagri/cagri_panosu_wrapper.dart';
import 'package:yaz_boz/pages/cagri/cagri_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class CagriAnaSayfasi extends StatefulWidget {
  const CagriAnaSayfasi({super.key});

  @override
  State<CagriAnaSayfasi> createState() => _CagriAnaSayfasiState();
}

class _CagriAnaSayfasiState extends State<CagriAnaSayfasi> {
  late final String? _uid;
  late final Stream<List<Cagri>> _listeStream;

  @override
  void initState() {
    super.initState();
    _uid = AuthService().uid;
    _listeStream = CagriServisi().son24SaatCagrilariStreami(_uid!);
  }

  @override
  Widget build(BuildContext context) {
    final yatay = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text(
          'ÇAĞRILAR',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      // ✅ DİKEY MODDA TAM SAYFA SCROLL DESTEĞİ
      body: yatay
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CagriPanoWrapper(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: _listeAlani(disScroll: true),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ✅ PANONUN EKRANI TAŞIRMAMASI İÇİN SINIRLAMA
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: const CagriPanoWrapper(),
                  ),
                  _listeAlani(disScroll: true),
                ],
              ),
            ),
    );
  }

  Widget _listeAlani({required bool disScroll}) {
    return StreamBuilder<List<Cagri>>(
      stream: _listeStream,
      builder: (context, snap) {
        final liste = snap.data ?? const [];
        if (liste.isEmpty) return CagriBosDurumEkrani(uid: _uid);

        // ✅ DİKEYDE DE LİSTE ALANI SCROLL EDİLEBİLİR OLSUN
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(
                bottom: 10,
                top: 12,
                left: 16,
                right: 16,
              ),
              child: Text('SON 24 SAAT', style: AppTextStyles.caption),
            ),
            for (final c in liste)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: CagriKarti(cagri: c, uid: _uid!),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
