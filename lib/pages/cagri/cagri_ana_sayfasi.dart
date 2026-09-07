// lib/pages/cagri/cagri_ana_sayfasi.dart

import 'package:flutter/material.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/pages/cagri/cagri_panosu.dart';
import 'package:yaz_boz/pages/cagri/cagri_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class CagriAnaSayfasi extends StatefulWidget {
  const CagriAnaSayfasi({super.key});

  @override
  State<CagriAnaSayfasi> createState() => _CagriAnaSayfasiState();
}

class _CagriAnaSayfasiState extends State<CagriAnaSayfasi> {
  // ✅ late final KALDIRILDI, nullable yapıldı
  String? _uid;
  Stream<List<Cagri>>? _listeStream;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // UID'yi al (AuthService().uid genelde senkron getter'dır)
    final uid = AuthService().uid;

    if (!mounted) return;

    setState(() {
      _uid = uid;
      // Stream sadece uid varsa oluşturulur
      if (_uid != null) {
        _listeStream = CagriServisi().son24SaatCagrilariStreami(_uid!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ UID henüz yüklenmediyse loading göster (Yatay geçişte güvenli)
    if (_uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentAmber),
        ),
      );
    }

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
      body: yatay
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CagriPanoWrapper(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: _listeAlani(),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: const CagriPanoWrapper(),
                  ),
                  _listeAlani(),
                ],
              ),
            ),
    );
  }

  Widget _listeAlani() {
    // ✅ Stream null ise boş döndür
    if (_listeStream == null || _uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Cagri>>(
      stream: _listeStream,
      builder: (context, snap) {
        // ✅ KRİTİK: Widget dispose olduysa build etme (Yatay mod hatasını çözer)
        if (!context.mounted) return const SizedBox.shrink();

        final liste = snap.data ?? const [];

        // ✅ uid null olamaz çünkü yukarıda kontrol ettik ama yine de güvenli parametre
        if (liste.isEmpty) return CagriBosDurumEkrani(uid: _uid);

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
                // ✅ _uid! yerine doğrudan _uid (null olmadığı garanti)
                child: CagriKarti(cagri: c, uid: _uid!),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
