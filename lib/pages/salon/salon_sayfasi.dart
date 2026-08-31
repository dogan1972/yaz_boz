// lib/pages/salon/salon_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/pages/salon/salon_icerik.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

class SalonSayfasi extends StatefulWidget {
  final String cagriId;
  final String uid;
  const SalonSayfasi({super.key, required this.cagriId, required this.uid});

  @override
  State<SalonSayfasi> createState() => _SalonSayfasiState();
}

class _SalonSayfasiState extends State<SalonSayfasi> {
  late final Stream<Cagri?> _stream;

  @override
  void initState() {
    super.initState();
    _stream = CagriServisi().cagriStreami(widget.cagriId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: StreamBuilder<Cagri?>(
        stream: _stream,
        builder: (context, snap) {
          final c = snap.data;

          // ✅ Bekleme veya boş durum
          if (snap.connectionState == ConnectionState.waiting || c == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentAmber),
            );
          }

          // ✅ _IptalFisi artık salon_icerik.dart içinde yönetiliyor.
          // Bu sayfa sadece SalonIcerik'i sarmalıyor.
          return SalonIcerik(cagri: c, uid: widget.uid);
        },
      ),
    );
  }
}
