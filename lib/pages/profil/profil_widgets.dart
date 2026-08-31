// lib/pages/profil/profil_widgets.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yaz_boz/models/kullanici_model.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Ortak Profil Kartı Yapısı
Widget profilKart({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

/// Rozet Bileşeni (Kod, Arkadaş Sayısı vb.)
Widget profilRozet(String metin, Color renk, IconData ikon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: renk.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, color: renk, size: 13),
        const SizedBox(width: 5),
        Text(
          metin,
          style: TextStyle(
            color: renk,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

/// QR Kod ve Kopyala Butonu Kartı
class ProfilQrKarti extends StatelessWidget {
  final Kullanici profil;
  const ProfilQrKarti(this.profil, {super.key});

  @override
  Widget build(BuildContext context) {
    return profilKart(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_add_alt_1,
                color: AppColors.textSecondary,
                size: 15,
              ),
              const SizedBox(width: 8),
              const Text(
                'BENİ EKLE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentAmber.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: profil.qrPayload,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Arkadaşların bu kodu okutarak seni ekleyebilir',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ProfilKopyalaDugmesi(kod: profil.davetKodu),
        ],
      ),
    );
  }
}

/// Kopyala Butonu (Geri Bildirimli)
class ProfilKopyalaDugmesi extends StatefulWidget {
  final String kod;
  const ProfilKopyalaDugmesi({super.key, required this.kod});
  @override
  State<ProfilKopyalaDugmesi> createState() => _ProfilKopyalaDugmesiState();
}

class _ProfilKopyalaDugmesiState extends State<ProfilKopyalaDugmesi> {
  bool _kopyalandi = false;
  Future<void> _kopyala() async {
    await Clipboard.setData(ClipboardData(text: widget.kod));
    if (!mounted) return;
    setState(() => _kopyalandi = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _kopyalandi = false);
  }

  @override
  Widget build(BuildContext context) {
    final renk = AppColors.accentCyan;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _kopyala,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: _kopyalandi ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: renk.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                _kopyalandi ? Icons.check_circle_rounded : Icons.copy_rounded,
                key: ValueKey(_kopyalandi),
                color: renk,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                _kopyalandi ? 'Kopyalandı!' : 'Kodu kopyala: ${widget.kod}',
                key: ValueKey(_kopyalandi),
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Çıkış Kartı
class ProfilCikisKarti extends StatelessWidget {
  final bool cikiliyor;
  final VoidCallback onCikis;
  const ProfilCikisKarti({
    super.key,
    required this.cikiliyor,
    required this.onCikis,
  });

  @override
  Widget build(BuildContext context) {
    return profilKart(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: cikiliyor ? null : onCikis,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: cikiliyor
                      ? const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.accentAmber,
                          ),
                        )
                      : Icon(
                          Icons.logout_rounded,
                          color: AppColors.accentRed.withValues(alpha: 0.8),
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          cikiliyor ? 'Ampul sönüyor…' : 'Çıkış yap',
                          key: ValueKey(cikiliyor),
                          style: TextStyle(
                            color: cikiliyor
                                ? AppColors.accentAmber
                                : AppColors.accentRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cikiliyor
                            ? 'masadan ayrılıyorsun'
                            : 'Başka bir hesapla girmek için',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!cikiliyor)
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.accentRed.withValues(alpha: 0.8),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nabız İkon (Boş Durum İçin)
class ProfilNabizIkon extends StatefulWidget {
  const ProfilNabizIkon({super.key});
  @override
  State<ProfilNabizIkon> createState() => _ProfilNabizIkonState();
}

class _ProfilNabizIkonState extends State<ProfilNabizIkon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
      builder: (_, _) {
        final t = _c.value;
        return Container(
          width: 72 + 6 * t,
          height: 72 + 6 * t,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentAmber.withValues(alpha: 0.10 + 0.08 * t),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentAmber.withValues(alpha: 0.3 * t),
                blurRadius: 20 + 8 * t,
              ),
            ],
          ),
          child: Icon(
            Icons.person_search_rounded,
            color: AppColors.accentAmber.withValues(alpha: 0.7 + 0.3 * t),
            size: 32,
          ),
        );
      },
    );
  }
}

/// Profil Toz Partikülleri
class ProfilToz extends StatefulWidget {
  const ProfilToz({super.key});
  @override
  State<ProfilToz> createState() => _ProfilTozState();
}

class _PT {
  final double x, y0, r, hiz, faz;
  final Color renk;
  _PT(Random r)
    : x = r.nextDouble(),
      y0 = r.nextDouble(),
      r = 1 + r.nextDouble() * 2.0,
      hiz = 0.3 + r.nextDouble() * 0.7,
      faz = r.nextDouble(),
      renk = r.nextBool() ? AppColors.accentAmber : AppColors.accentCyan;
}

class _ProfilTozState extends State<ProfilToz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_PT> _p;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat();
    final r = Random();
    _p = List.generate(12, (_) => _PT(r));
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
      builder: (_, _) => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _ProfilTozBoyaci(_p, _c.value)),
        ),
      ),
    );
  }
}

class _ProfilTozBoyaci extends CustomPainter {
  final List<_PT> p;
  final double t;
  _ProfilTozBoyaci(this.p, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final e in p) {
      final y = (e.y0 + t * e.hiz + e.faz) % 1.0;
      final dy = (1 - y) * size.height;
      final op = (0.05 + 0.12 * (1 - (y - 0.5).abs() * 2)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(e.x * size.width, dy),
        e.r,
        Paint()..color = e.renk.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfilTozBoyaci old) => old.t != t;
}
