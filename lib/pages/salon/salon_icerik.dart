// lib/pages/salon/salon_icerik.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/models/kullanici_model.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/pages/salon/salon_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class SalonIcerik extends StatefulWidget {
  final Cagri cagri;
  final String uid;
  const SalonIcerik({super.key, required this.cagri, required this.uid});

  @override
  State<SalonIcerik> createState() => _SalonIcerikState();
}

class _SalonIcerikState extends State<SalonIcerik>
    with SingleTickerProviderStateMixin {
  Map<String, Kullanici> _profil = {};
  bool _oncekiKilit = false;
  bool _flashKilit = false;
  Timer? _flashTimer;
  late final AnimationController _muhur;

  Set<String> _yuklenenProfilIds = {};

  Cagri get c => widget.cagri;
  bool get acanMi => c.acanId == widget.uid;
  bool get sonlandiMi => c.durum == 'sonlandi';

  List<String> get _koltukUid => c.davetliIds;

  Future<void> _konumuAc() async {
    String hedefUrl;
    final konumMetni = c.konumAd?.trim() ?? '';

    if (konumMetni.contains('maps.app.goo.gl') ||
        konumMetni.contains('google.com/maps')) {
      hedefUrl = konumMetni.startsWith('http')
          ? konumMetni
          : 'https://$konumMetni';
    } else {
      final aranacak = konumMetni.isNotEmpty ? konumMetni : c.yer;
      if (aranacak == null || aranacak.isEmpty) return;
      hedefUrl =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(aranacak)}';
    }

    try {
      final uri = Uri.parse(hedefUrl);
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Harita açılamadı.')));
        }
      }
    } catch (e) {
      debugPrint('Konum açma hatası: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _muhur = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _oncekiKilit = c.kilitli;
    if (c.kilitli) _muhur.value = 1;
    _profilYukle();
  }

  @override
  void didUpdateWidget(covariant SalonIcerik old) {
    super.didUpdateWidget(old);

    if (c.kilitli && !_oncekiKilit) {
      _oncekiKilit = true;
      setState(() => _flashKilit = true);
      _muhur.forward(from: 0);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 850), () {
        if (mounted) setState(() => _flashKilit = false);
      });
    }

    if (old.cagri.davetliIds != c.davetliIds) {
      _yuklenenProfilIds.clear();
      _profilYukle();
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _muhur.dispose();
    super.dispose();
  }

  Future<void> _profilYukle() async {
    final ids = _koltukUid;
    if (ids.isEmpty) return;

    if (_yuklenenProfilIds.containsAll(ids) &&
        _yuklenenProfilIds.length == ids.length) {
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      if (!mounted) return;

      setState(() {
        _profil = {for (final d in snap.docs) d.id: Kullanici.fromFirestore(d)};
        _yuklenenProfilIds = ids.toSet();
      });
    } catch (e) {
      debugPrint('Profil yükleme hatası: $e');
    }
  }

  String _ad(String uid) =>
      uid == c.acanId ? c.acanAd : (_profil[uid]?.nick ?? '…');

  @override
  Widget build(BuildContext context) {
    final bool yatay =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        const SalonToz(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: yatay ? _yatayDuzen() : _dikeyDuzen(),
          ),
        ),
        if (_flashKilit) SalonKilitFlash(muhur: _muhur),
      ],
    );
  }

  // ✅ MEVCUT DİKEY DÜZEN
  Widget _dikeyDuzen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baslik(),
        const SizedBox(height: 8),
        Expanded(child: _masa()),
        const SizedBox(height: 12),
        if (c.yer != null && c.yer!.isNotEmpty) _konumKarti(),
        _durumSeridi(),
      ],
    );
  }

  // ✅ YENİ YATAY DÜZEN (Ergonomik Split-View)
  Widget _yatayDuzen() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // SOL: MASA (%55 - Daha geniş alan)
        Expanded(
          flex: 55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _baslik(kucukBaslik: true),
              const SizedBox(height: 20),
              Expanded(child: _masa(yatayMod: true)),
            ],
          ),
        ),

        const SizedBox(width: 32),

        // SAĞ: BİLGİLER (%45 - Dikeyde ortalı ve scrollable)
        Expanded(
          flex: 45,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.yer != null && c.yer!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _konumKarti(),
                  ),
                _durumSeridi(yatayMod: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _baslik({bool kucukBaslik = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sonlandiMi ? 'ARŞİV · SALON' : 'BULUŞMA SALONU',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: kucukBaslik ? 10 : 11,
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.acanAd} MASASI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sonlandiMi
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: kucukBaslik ? 24 : 30,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        if (c.kilitli) _muhurRozeti(),
        if (sonlandiMi) _sonlandiRozeti(),
      ],
    );
  }

  Widget _muhurRozeti() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Transform.rotate(
        angle: -0.12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.7),
              width: 1.6,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: AppColors.accentCyan,
                size: 12,
              ),
              SizedBox(width: 4),
              Text(
                'MÜHÜRLENDİ',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sonlandiRozeti() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Transform.rotate(
        angle: -0.12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              width: 1.6,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.power_settings_new,
                color: AppColors.textSecondary,
                size: 12,
              ),
              SizedBox(width: 4),
              Text(
                'SONLANDI',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _masa({bool yatayMod = false}) {
    final koltuklar = _koltukUid;
    final sandalyeBoyutu = yatayMod ? 52.0 : 64.0;

    if (koltuklar.length <= 8) {
      return LayoutBuilder(
        builder: (context, con) {
          final w = con.maxWidth;
          final h = con.maxHeight;

          // ✅ YATAY MODDA MASAYI TAM ORTAYA HİZALA
          final cx = w / 2;
          final cy = h / 2;

          // Yatay modda elipsi biraz daha basık yap ki sığsın
          final rx = w * 0.36;
          final ry = h * 0.36;

          final List<Offset> pusulaPozisyonlari = [
            Offset(cx, cy - ry), // Kuzey
            Offset(cx + rx, cy), // Doğu
            Offset(cx, cy + ry), // Güney
            Offset(cx - rx, cy), // Batı
            Offset(cx - rx * 0.7, cy - ry * 0.7), // Kuzey-Batı
            Offset(cx + rx * 0.7, cy - ry * 0.7), // Kuzey-Doğu
            Offset(cx + rx * 0.7, cy + ry * 0.7), // Güney-Doğu
            Offset(cx - rx * 0.7, cy + ry * 0.7), // Güney-Batı
          ];

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: SalonMasaBoyaci(solgun: sonlandiMi),
                ),
              ),
              // Orta bilgiyi de merkeze sabitle
              Positioned(
                left: cx - 78,
                top: cy - 44,
                width: 156,
                child: SalonOrtaBilgi(cagri: c),
              ),
              for (
                var i = 0;
                i < koltuklar.length && i < pusulaPozisyonlari.length;
                i++
              )
                Positioned(
                  left: pusulaPozisyonlari[i].dx - (sandalyeBoyutu / 2 + 10),
                  top: pusulaPozisyonlari[i].dy - (sandalyeBoyutu / 2 + 10),
                  width: 120,
                  child: SalonSandalye(
                    uid: koltuklar[i],
                    ad: _ad(koltuklar[i]),
                    acan: koltuklar[i] == c.acanId,
                    onayli: c.onaylar.contains(koltuklar[i]),
                    benim: koltuklar[i] == widget.uid,
                    cagri: c,
                    onOnayla: () => CagriServisi().onayla(c.id, widget.uid),
                  ),
                ),
            ],
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: koltuklar.length,
        itemBuilder: (ctx, i) {
          final uid = koltuklar[i];
          final acan = uid == c.acanId;
          final onayli = c.onaylar.contains(uid);
          final benim = uid == widget.uid;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: acan
                        ? AppColors.accentAmber.withValues(alpha: 0.2)
                        : (onayli
                              ? AppColors.accentCyan.withValues(alpha: 0.2)
                              : AppColors.divider.withValues(alpha: 0.2)),
                    child: Text(
                      _ad(uid)[0].toUpperCase(),
                      style: TextStyle(
                        color: acan
                            ? AppColors.accentAmber
                            : (onayli
                                  ? AppColors.accentCyan
                                  : AppColors.textSecondary),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ad(uid),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          acan
                              ? 'Çağrı Sahibi'
                              : (onayli ? 'Onaylandı' : 'Bekliyor'),
                          style: TextStyle(
                            color: acan
                                ? AppColors.accentAmber
                                : (onayli
                                      ? AppColors.accentCyan
                                      : AppColors.divider),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!acan && !onayli && benim)
                    Material(
                      color: AppColors.accentCyan,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => CagriServisi().onayla(c.id, widget.uid),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            'ONAYLA',
                            style: TextStyle(
                              color: Color(0xFF06231F),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (!acan && onayli)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _konumKarti() {
    return GestureDetector(
      onTap: _konumuAc,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.place, color: AppColors.accentBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.yer!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (c.konumAd != null && c.konumAd!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.konumAd!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: AppColors.accentCyan,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _durumSeridi({bool yatayMod = false}) {
    final toplam = c.hedef;
    final onay = c.onaySayisi;

    return Row(
      children: [
        Expanded(
          child: salonPanel(
            child: Row(
              children: [
                const Icon(
                  Icons.how_to_reg,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ONAY  $onay / $toplam',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: toplam == 0 ? 0 : onay / toplam,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(
                            sonlandiMi
                                ? AppColors.textSecondary
                                : AppColors.accentCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (acanMi && !sonlandiMi) ...[
          const SizedBox(width: 10),
          Material(
            color: AppColors.accentRed.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final onay = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: const Text(
                      'Masayı Kapat',
                      style: AppTextStyles.bodyPrimary,
                    ),
                    content: const Text(
                      'Bu masayı kapatmak istediğine emin misin?',
                      style: AppTextStyles.bodySecondary,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text(
                          'Vazgeç',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(d, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                        ),
                        child: const Text('Evet, Çağrıyı İptal Et'),
                      ),
                    ],
                  ),
                );
                if (onay == true && mounted) {
                  await CagriServisi().sonlandir(c.id);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Icon(
                  Icons.cancel_outlined,
                  color: AppColors.accentRed,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
