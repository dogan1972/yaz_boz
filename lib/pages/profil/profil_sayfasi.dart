import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yaz_boz/models/kullanici.dart';
import 'package:yaz_boz/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// PROFİL — kimlik + QR/davet kodu + müsaitlik ampulü + çıkış
//   Profil yoksa AuthService.profilGarantile() o an üretir.
// ─────────────────────────────────────────────────────────────
class ProfilSayfasi extends StatefulWidget {
  const ProfilSayfasi({super.key});
  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  final _fs = FirebaseFirestore.instance;
  Kullanici? _profil;
  bool _yukleniyor = true;
  bool _cikiliyor = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _profilYukle();
  }

  // ✅ yoksa oluşturur → "Profil bulunamadı" çıkmazı kapanır
  Future<void> _profilYukle() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) setState(() => _yukleniyor = false);
      return;
    }
    try {
      final p = await AuthService().profilGarantile();
      if (!mounted) return;
      setState(() {
        _profil = p;
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint('Profil yüklenemedi: $e');
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _nickDuzenle() async {
    final controller = TextEditingController(text: _profil?.nick ?? '');
    final yeni = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF111A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Takma Adını Düzenle',
          style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 17),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE2E8F0)),
          decoration: InputDecoration(
            hintText: 'Yeni takma ad',
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            filled: true,
            fillColor: const Color(0xFF0B1220),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF1A1206),
            ),
            onPressed: () => Navigator.pop(d, controller.text.trim()),
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (yeni == null || yeni.isEmpty || yeni.length < 2 || _uid == null) return;
    await _fs.collection('kullanicilar').doc(_uid).update({'nick': yeni});
    await _profilYukle();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Takma ad güncellendi.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ✅ çıkış: oturumu kapat + stack'i köke boşalt → login'e düşer
  Future<void> _cikisYap() async {
    setState(() => _cikiliyor = true);
    await Future.delayed(const Duration(milliseconds: 320));
    try {
      await AuthService().signOut();
    } catch (e) {
      debugPrint('Çıkış hatası: $e');
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : _profil == null
          ? _profilBosKarti()
          : Stack(
              children: [
                const _ProfilToz(),
                ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _kimlikKarti(_profil!),
                    const SizedBox(height: 14),
                    _qrKarti(_profil!),
                    const SizedBox(height: 14),
                    _cikisKarti(),
                  ],
                ),
              ],
            ),
    );
  }

  // ── kimlik ────────────────────────────────────────────────
  Widget _kimlikKarti(Kullanici p) {
    final harf = p.nick.trim().isEmpty ? '?' : p.nick.trim()[0].toUpperCase();
    final arkadasSayisi = p.arkadasIds.length;
    return _kart(
      child: Row(
        children: [
          // avatar + halo
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  harf,
                  style: const TextStyle(
                    color: Color(0xFF1A1206),
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.nick,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _nickDuzenle,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit,
                          color: Color(0xFFF59E0B),
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  p.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _rozet(
                      'Kod: ${p.davetKodu}',
                      const Color(0xFF2DD4BF),
                      Icons.qr_code_2_rounded,
                    ),
                    _rozet(
                      '$arkadasSayisi arkadaş',
                      const Color(0xFF38BDF8),
                      Icons.group_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rozet(String metin, Color renk, IconData ikon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
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

  // ── QR + kod kopyala ──────────────────────────────────────
  Widget _qrKarti(Kullanici p) {
    return _kart(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_add_alt_1,
                color: Color(0xFF94A3B8),
                size: 15,
              ),
              const SizedBox(width: 8),
              const Text(
                'BENİ EKLE',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // QR — beyaz kart + amber köşe ışığı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: p.qrPayload,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Arkadaşların bu kodu okutarak seni ekleyebilir',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          // kopyala — basınca geri bildirim
          _KopyalaDugmesi(kod: p.davetKodu),
        ],
      ),
    );
  }

  // ── müsaitlik (ampul) ─────────────────────────────────────

  // ── çıkış ─────────────────────────────────────────────────
  Widget _cikisKarti() {
    return _kart(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _cikiliyor ? null : _cikisYap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: _cikiliyor
                      ? const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                        )
                      : Icon(
                          Icons.logout_rounded,
                          color: Colors.red.shade300,
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
                          _cikiliyor ? 'Ampul sönüyor…' : 'Çıkış yap',
                          key: ValueKey(_cikiliyor),
                          style: TextStyle(
                            color: _cikiliyor
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFFFCA5A5),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _cikiliyor
                            ? 'masadan ayrılıyorsun'
                            : 'Başka bir hesapla girmek için',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_cikiliyor)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.red.shade300,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── profil onarılamadıysa: yaşayan boş durum + tekrar dene ──
  Widget _profilBosKarti() {
    return Stack(
      children: [
        const _ProfilToz(),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111A2B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NabizIkon(),
                  const SizedBox(height: 16),
                  const Text(
                    'HESAP HAZIRLANIYOR',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profilin oluşturulamadı — bağlantıyı kontrol edip tekrar dene.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _yukleniyor = true);
                        _profilYukle();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF1A1206),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TEKRAR DENE',
                              style: TextStyle(
                                color: Color(0xFF1A1206),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1,
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
          ),
        ),
      ],
    );
  }

  Widget _kart({required Widget child}) {
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
// KOPYALA DÜĞMESİ — basınca "kopyalandı" geri bildirimi
// ─────────────────────────────────────────────────────────────
class _KopyalaDugmesi extends StatefulWidget {
  final String kod;
  const _KopyalaDugmesi({required this.kod});
  @override
  State<_KopyalaDugmesi> createState() => _KopyalaDugmesiState();
}

class _KopyalaDugmesiState extends State<_KopyalaDugmesi> {
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
    final renk = _kopyalandi
        ? const Color(0xFF2DD4BF)
        : const Color(0xFF2DD4BF);
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
                  color: Color(0xFF2DD4BF),
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

// ─────────────────────────────────────────────────────────────
// NABIZ İKON — boş durum için yaşayan halka
// ─────────────────────────────────────────────────────────────
class _NabizIkon extends StatefulWidget {
  @override
  State<_NabizIkon> createState() => _NabizIkonState();
}

class _NabizIkonState extends State<_NabizIkon>
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
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: 72 + 6 * t,
          height: 72 + 6 * t,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF59E0B).withValues(alpha: 0.10 + 0.08 * t),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3 * t),
                blurRadius: 20 + 8 * t,
              ),
            ],
          ),
          child: Icon(
            Icons.person_search_rounded,
            color: const Color(0xFFFCD34D).withValues(alpha: 0.7 + 0.3 * t),
            size: 32,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFİL TOZU — ambient süzülen ışık parçacıkları
// ─────────────────────────────────────────────────────────────
class _ProfilToz extends StatefulWidget {
  const _ProfilToz();
  @override
  State<_ProfilToz> createState() => _ProfilTozState();
}

class _ProfilTozState extends State<_ProfilToz>
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
      builder: (context, _) => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _ProfilTozBoyaci(_p, _c.value)),
        ),
      ),
    );
  }
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
      renk = r.nextBool() ? const Color(0xFFF59E0B) : const Color(0xFF2DD4BF);
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
