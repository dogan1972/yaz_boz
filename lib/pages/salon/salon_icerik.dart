// lib/pages/salon/salon_icerik.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/cagri.dart';
import 'package:yaz_boz/models/kullanici.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';

// ✅ Public Widget: Ana sayfaya gömülebilir / SalonSayfasi tarafından sarılır
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

  // ✅ YERLEŞİM — ekran boyutunu al, kalan alanı masaya ver (sığdırma)
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _SalonToz(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, con) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _baslik(),
                  const SizedBox(height: 8),
                  // ✅ MASA ESNEK — cihazın kalan yüksekliğini doldurur
                  Expanded(child: _masa()),
                  const SizedBox(height: 12),
                  _detayPaneli(),
                  const SizedBox(height: 10),
                  _durumSeridi(),
                ],
              ),
            ),
          ),
        ),
        if (_flashKilit) _KilitFlash(muhur: _muhur),
      ],
    );
  }

  // ── başlık + durum damgası (mühür / sonlandı) ─────────────
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
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.acanAd} masası',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sonlandiMi
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFFF8FAFC),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.7),
                    width: 1.6,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF2DD4BF), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'MÜHÜRLENDİ',
                      style: TextStyle(
                        color: Color(0xFF2DD4BF),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF64748B).withValues(alpha: 0.7),
                    width: 1.6,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.power_settings_new, color: Color(0xFF94A3B8), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'SONLANDI',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
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

  // ── masa + sandalyeler ────────────────────────────────────
  Widget _masa() {
    final koltuklar = _koltukUid;
    return LayoutBuilder(
      builder: (context, con) {
        final w = con.maxWidth;
        final h = con.maxHeight;
        final cx = w / 2;
        final cy = h * 0.44;
        final rx = w * 0.34;
        final ry = h * 0.30;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _MasaBoyaci(solgun: sonlandiMi))),
            Positioned(
              left: cx - 78,
              top: cy - 44,
              width: 156,
              child: _masaOrtasi(),
            ),
            for (var i = 0; i < koltuklar.length && i < 4; i++)
              _sandalyeKonum(i, cx, cy, rx, ry, koltuklar[i]),
          ],
        );
      },
    );
  }

  Widget _sandalyeKonum(
    int i,
    double cx,
    double cy,
    double rx,
    double ry,
    String uid,
  ) {
    final a = (-pi / 2) + (i * (pi / 2));
    final x = cx + rx * cos(a);
    final y = cy + ry * sin(a);
    return Positioned(
      left: x - 42,
      top: y - 32,
      width: 84,
      child: _sandalye(uid, i == 0),
    );
  }

  Widget _sandalye(String uid, bool acan) {
    final onayli = acan || c.onaylar.contains(uid);
    final bekliyor = !acan && !onayli;
    final benim = uid == widget.uid;
    final renk = acan
        ? const Color(0xFFF59E0B)
        : (onayli ? const Color(0xFF2DD4BF) : const Color(0xFF475569));
    final ad = _ad(uid);
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
                      ? [const Color(0xFFF59E0B), const Color(0xFFB45309)]
                      : (onayli
                            ? [const Color(0xFF2DD4BF), const Color(0xFF0E7490)]
                            : [
                                const Color(0xFF334155),
                                const Color(0xFF1E293B),
                              ]),
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
                  color: Color(0xFF0A0F1C),
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
                  color: const Color(0xFF0A0F1C),
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
            color: onayli ? const Color(0xFFE2E8F0) : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        if (bekliyor && c.detayDolu && !c.kilitli && !sonlandiMi && benim)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Material(
              color: const Color(0xFF2DD4BF),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => CagriServisi().onayla(c.id, widget.uid),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Text(
                    'ONAYLA',
                    style: TextStyle(
                      color: Color(0xFF06231F),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (bekliyor && !c.detayDolu && !sonlandiMi && benim)
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text(
              'detay bekleniyor',
              style: TextStyle(color: Color(0xFF475569), fontSize: 9),
            ),
          ),
      ],
    );
  }

  Widget _masaOrtasi() {
    if (sonlandiMi) {
      return const KeyedSubtree(
        key: ValueKey('sonlandi'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.power_settings_new, color: Color(0xFF64748B), size: 28),
            SizedBox(height: 6),
            Text(
              'masa\ndağıldı',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      child: c.detayDolu ? _ortaBilgi() : const _OrtaBos(),
    );
  }

  Widget _ortaBilgi() {
    return KeyedSubtree(
      key: const ValueKey('dolu'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFFFCD34D), size: 18),
              const SizedBox(width: 6),
              Text(
                c.saat ?? '',
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.yer ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (c.konumAd != null && c.konumAd!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.place, color: Color(0xFF38BDF8), size: 12),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    c.konumAd!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── detay paneli ──────────────────────────────────────────
  Widget _detayPaneli() {
    if (sonlandiMi) return _sonlandiFis();
    if (c.kilitli) return _kilitliFis();
    if (acanMi) return _duzenlePaneli();
    if (!c.detayDolu) {
      return _panel(
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Masayı kuran saat ve yeri giriyor…',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BULUŞMA',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFFFCD34D), size: 16),
              const SizedBox(width: 8),
              Text(
                c.saat ?? '',
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${c.yer}${(c.konumAd?.isNotEmpty ?? false) ? ' · ${c.konumAd}' : ''}',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _duzenlePaneli() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BULUŞMA DETAYI',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _saatDugmesi(),
              const SizedBox(width: 10),
              Expanded(
                child: _metinAlani('yer', c.yer, Icons.place, (v) {
                  _kaydet(saat: c.saat, yer: v, konum: c.konumAd);
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _metinAlani('buluşma noktası / konum', c.konumAd, Icons.pin_drop, (v) {
            _kaydet(saat: c.saat, yer: c.yer, konum: v);
          }),
        ],
      ),
    );
  }

  Widget _saatDugmesi() {
    return Material(
      color: const Color(0xFF0B1220),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final now = TimeOfDay.now();
          final sec = await showTimePicker(
            context: context,
            initialTime: now,
            builder: (ctx, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFFF59E0B),
                  surface: Color(0xFF111A2B),
                ),
              ),
              child: child!,
            ),
          );
          if (sec == null) return;
          final s =
              '${sec.hour.toString().padLeft(2, '0')}:${sec.minute.toString().padLeft(2, '0')}';
          _kaydet(saat: s, yer: c.yer, konum: c.konumAd);
        },
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            children: [
              const Icon(Icons.schedule, color: Color(0xFFFCD34D), size: 16),
              const SizedBox(height: 3),
              Text(
                c.saat ?? 'SAAT',
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metinAlani(
    String hint,
    String? deger,
    IconData ikon,
    void Function(String) onKaydet,
  ) {
    final c2 = TextEditingController(text: deger ?? '');
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(ikon, color: const Color(0xFF64748B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: c2,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: onKaydet,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF2DD4BF), size: 20),
            onPressed: () => onKaydet(c2.text),
          ),
        ],
      ),
    );
  }

  Future<void> _kaydet({String? saat, String? yer, String? konum}) async {
    await CagriServisi().bulusmaKaydet(
      id: c.id,
      saat: (saat ?? '').trim(),
      yer: (yer ?? '').trim(),
      konumAd: (konum ?? '').trim(),
    );
  }

  Widget _kilitliFis() {
    return _panel(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_rounded, color: Color(0xFF2DD4BF), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BULUŞMA SABİTLENDİ',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${c.saat} · ${c.yer}',
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sonlandiFis() {
    return _panel(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7A1419).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.power_settings_new, color: Color(0xFFFCA5A5), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ÇAĞRI SONLANDIRILDI',
                  style: TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  (c.saat != null && c.saat!.isNotEmpty)
                      ? '${c.saat} · ${c.yer ?? ''}'
                      : 'Masa dağıldı.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ONAY SAYACI — açan kişi 1. onaydır: 1/4 başlar, 4/4 biter
  Widget _durumSeridi() {
    final toplam = c.davetliIds.length + 1;
    final onay = (c.onaylar.length + 1).clamp(0, toplam);
    return Row(
      children: [
        Expanded(
          child: _panel(
            child: Row(
              children: [
                const Icon(Icons.how_to_reg, color: Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ONAY  $onay / $toplam',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
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
                          backgroundColor: const Color(0xFF1E293B),
                          valueColor: AlwaysStoppedAnimation(
                            sonlandiMi ? const Color(0xFF64748B) : const Color(0xFF2DD4BF),
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
            color: const Color(0xFF7A1419).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final onay = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: const Color(0xFF111A2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: const Text(
                      'Çağrıyı sonlandır',
                      style: TextStyle(color: Color(0xFFF8FAFC)),
                    ),
                    content: const Text(
                      'Masa dağılacak ve herkesin panosu sönecek.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text(
                          'Vazgeç',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text(
                          'Sonlandır',
                          style: TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
                child: Icon(Icons.power_settings_new, color: Color(0xFFFCA5A5), size: 22),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KİLİT FLASH — son onay anında: amber parlama + dönen mühür
// ─────────────────────────────────────────────────────────────
class _KilitFlash extends StatelessWidget {
  final AnimationController muhur;
  const _KilitFlash({required this.muhur});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: muhur,
          builder: (context, _) {
            final t = muhur.value;
            final opaklik = (1 - t).clamp(0.0, 1.0);
            return Opacity(
              opacity: opaklik,
              child: Container(
                color: const Color(0xFF0A0F1C).withValues(alpha: 0.55),
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
                            const Color(0xFFF59E0B).withValues(alpha: 0.35 * (1 - t)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF2DD4BF), width: 3),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF0A0F1C).withValues(alpha: 0.6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_rounded, color: Color(0xFF2DD4BF), size: 26),
                              SizedBox(width: 10),
                              Text(
                                'SABİTLENDİ',
                                style: TextStyle(
                                  color: Color(0xFF5EEAD4),
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

// ─────────────────────────────────────────────────────────────
// BOŞ ORTA — nabız atan "detay bekleniyor"
// ─────────────────────────────────────────────────────────────
class _OrtaBos extends StatefulWidget {
  const _OrtaBos();
  @override
  State<_OrtaBos> createState() => _OrtaBosState();
}

class _OrtaBosState extends State<_OrtaBos> with SingleTickerProviderStateMixin {
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
    return KeyedSubtree(
      key: const ValueKey('bos'),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_restaurant,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.5 + 0.4 * t),
                size: 30 + 3 * t,
              ),
              const SizedBox(height: 6),
              Text(
                'saat & yer\nbekleniyor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.6 + 0.4 * t),
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
}

// ─────────────────────────────────────────────────────────────
// MASA BOYACISI — merkez & oranlar sandalyelerle hizalı
// ─────────────────────────────────────────────────────────────
class _MasaBoyaci extends CustomPainter {
  final bool solgun;
  const _MasaBoyaci({this.solgun = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.44);
    final rx = size.width * 0.34;
    final ry = size.height * 0.30;
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    final amber = solgun ? const Color(0xFF64748B) : const Color(0xFFF59E0B);

    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 10), width: rx * 2, height: ry * 2),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.45),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Color(0xFF1B2740), Color(0xFF0E1626)],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = amber.withValues(alpha: solgun ? 0.12 : 0.22)
        ..strokeWidth = 1.4,
    );
    for (var i = 1; i <= 3; i++) {
      final f = 1 - i * 0.22;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2 * f, height: ry * 2 * f),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF334155).withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 0.9, height: ry * 0.9),
      Paint()
        ..shader = RadialGradient(
          colors: [amber.withValues(alpha: solgun ? 0.04 : 0.10), Colors.transparent],
        ).createShader(
          Rect.fromCenter(center: c, width: rx * 0.9, height: ry * 0.9),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _MasaBoyaci old) => old.solgun != solgun;
}

// ─────────────────────────────────────────────────────────────
// SALON TOZU — ambient süzülen ışık parçacıkları
// ─────────────────────────────────────────────────────────────
class _SalonToz extends StatefulWidget {
  const _SalonToz();
  @override
  State<_SalonToz> createState() => _SalonTozState();
}

class _SalonTozState extends State<_SalonToz> with SingleTickerProviderStateMixin {
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
      builder: (context, _) => Positioned.fill(
        child: IgnorePointer(child: CustomPaint(painter: _Toz(_p, _c.value))),
      ),
    );
  }
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
        renk = r.nextBool() ? const Color(0xFFF59E0B) : const Color(0xFF2DD4BF);
}

class _Toz extends CustomPainter {
  final List<_P> p;
  final double t;
  _Toz(this.p, this.t);
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
  bool shouldRepaint(covariant _Toz old) => old.t != t;
}