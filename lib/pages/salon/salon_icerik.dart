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

  Cagri get c => widget.cagri;
  bool get acanMi => c.acanId == widget.uid;
  bool get sonlandiMi => c.durum == 'sonlandi';
  List<String> get _koltukUid => [c.acanId, ...c.davetliIds];

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
    final snap = await FirebaseFirestore.instance
        .collection('kullanicilar')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    if (!mounted) return;
    setState(() {
      _profil = {for (final d in snap.docs) d.id: Kullanici.fromFirestore(d)};
    });
  }

  String _ad(String uid) =>
      uid == c.acanId ? c.acanAd : (_profil[uid]?.nick ?? '…');

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SalonToz(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, con) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _baslik(),
                  const SizedBox(height: 8),
                  Expanded(child: _masa()),
                  const SizedBox(height: 12),

                  // Konum Linki (Alt Kısım)
                  if (c.yer != null && c.yer!.isNotEmpty)
                    GestureDetector(
                      onTap: _konumuAc,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place,
                              color: AppColors.accentBlue,
                              size: 20,
                            ),
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
                                  if (c.konumAd != null &&
                                      c.konumAd!.isNotEmpty) ...[
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
                    ),

                  _durumSeridi(),
                ],
              ),
            ),
          ),
        ),
        if (_flashKilit) SalonKilitFlash(muhur: _muhur),
      ],
    );
  }

  Widget _baslik() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sonlandiMi ? 'ARŞİV · SALON' : 'BULUŞMA SALONU',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
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
                  fontSize: 30,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        if (c.kilitli)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
          ),
        if (sonlandiMi)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
          ),
      ],
    );
  }

  Widget _masa() {
    final koltuklar = _koltukUid;

    if (koltuklar.length <= 8) {
      return LayoutBuilder(
        builder: (context, con) {
          final w = con.maxWidth;
          final h = con.maxHeight;
          final cx = w / 2;
          final cy = h * 0.44;
          final rx = w * 0.36;
          final ry = h * 0.32;

          // Pusula yönlerine göre sabit pozisyonlar
          final List<Offset> pusulaPozisyonlari = [
            Offset(cx, cy - ry), // Kuzey
            Offset(cx + rx, cy), // Doğu
            Offset(cx, cy + ry), // Güney
            Offset(cx - rx, cy), // Batı

            Offset(cx - rx * 0.7, cy - ry * 0.7), // KuzeyBatı
            Offset(cx + rx * 0.7, cy - ry * 0.7), // KuzeyDoğu
            Offset(cx + rx * 0.7, cy + ry * 0.7), // GüneyDoğu
            Offset(cx - rx * 0.7, cy + ry * 0.7), // GüneyBatı
          ];

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: SalonMasaBoyaci(solgun: sonlandiMi),
                ),
              ),

              // Merkez Bilgi
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
                  left: pusulaPozisyonlari[i].dx - 42,
                  top: pusulaPozisyonlari[i].dy - 32,
                  width: 120, // Butonun sığması için genişlik artırıldı
                  child: SalonSandalye(
                    uid: koltuklar[i],
                    ad: _ad(koltuklar[i]),
                    acan: i == 0,
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
      // 8'den fazla ise liste görünümü
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: koltuklar.length,
        itemBuilder: (ctx, i) {
          final uid = koltuklar[i];
          final acan = i == 0;
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
                  if (!acan &&
                      !onayli &&
                      benim &&
                      (c.yer != null && c.yer!.isNotEmpty))
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

  Widget _durumSeridi() {
    final toplam = c.davetliIds.length + 1;
    final onay = (c.onaylar.length + 1).clamp(0, toplam);
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
                        child: const Text('Evet, Kapat'),
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
