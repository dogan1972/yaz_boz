// lib/pages/eller/eller_widgets.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/theme/app_theme.dart'; // ✅ YENİ IMPORT

/// Geri Butonu (AppBar dışı kullanım için)
class EllerGeriButonu extends StatelessWidget {
  const EllerGeriButonu({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        hoverColor: AppColors.divider,
        splashColor: AppColors.accentGreen.withValues(alpha: 0.35),
        onTap: () => Navigator.of(context).maybePop(),
        child: Tooltip(
          message: 'Geri Dön',
          waitDuration: const Duration(milliseconds: 400),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider, width: 1.2),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Yükleniyor Ekranı
class EllerYukleniyorEkrani extends StatefulWidget {
  const EllerYukleniyorEkrani({super.key});
  @override
  State<EllerYukleniyorEkrani> createState() => _EllerYukleniyorEkraniState();
}

class _EllerYukleniyorEkraniState extends State<EllerYukleniyorEkrani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: EllerGeriButonu(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentGreen.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                final t = _c.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72 + 8 * t,
                      height: 72 + 8 * t,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentGreen.withValues(
                          alpha: 0.14 + 0.10 * t,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGreen.withValues(
                              alpha: 0.4 * t,
                            ),
                            blurRadius: 22 + 8 * t,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.style,
                        color: const Color(0xFF5EEAD4),
                        size: 34 + 3 * t,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'YAZ BOZ TAHTASI',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Yükleniyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Aktif Oyun Yok Ekranı
class EllerAktifOyunYokEkrani extends StatefulWidget {
  final VoidCallback onBaslat;
  final VoidCallback onYenile;
  const EllerAktifOyunYokEkrani({
    super.key,
    required this.onBaslat,
    required this.onYenile,
  });
  @override
  State<EllerAktifOyunYokEkrani> createState() =>
      _EllerAktifOyunYokEkraniState();
}

class _EllerAktifOyunYokEkraniState extends State<EllerAktifOyunYokEkrani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: EllerGeriButonu(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            left: -90,
            bottom: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0E7490).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              color: AppColors.accentGreen.withValues(alpha: 0.6),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _c,
                      builder: (_, _) {
                        final t = _c.value;
                        return Container(
                          width: 104 + 10 * t,
                          height: 104 + 10 * t,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.border,
                            border: Border.all(
                              color: AppColors.divider,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGreen.withValues(
                                  alpha: 0.35 * t,
                                ),
                                blurRadius: 30 + 12 * t,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sports_esports_outlined,
                            color: AppColors.textSecondary,
                            size: 44,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'YAZ BOZ · DURUM',
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'MASADA AKTİF\nOYUN YOK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                        height: 1.04,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tahta bir oyuna bağlıdır. Şu an devam eden bir maç bulunmuyor — yeni bir oyun başlat, defter anında açılsın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: widget.onBaslat,
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        label: const Text(
                          'Oyun Başlat',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton.icon(
                        onPressed: widget.onYenile,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text(
                          'Tekrar Ara',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.divider),
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
      ),
    );
  }
}

/// Hata Ekranı
Widget ellerHataEkrani(
  String hata,
  String? stack,
  VoidCallback onRetry,
  BuildContext context,
) {
  return Scaffold(
    backgroundColor: AppColors.bgSecondary,
    appBar: AppBar(
      backgroundColor: AppColors.bgSecondary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      title: const Text('Yaz Boz Tahtası'),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.accentRed, Color(0xFFB91C1C)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppColors.accentRed.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.bug_report_outlined,
                                color: Color(0xFFDC2626),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TAHTA YÜKLENEMEDİ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1.6,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Bir hata yakalandı — uygulama çökmedi.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                '$hata${stack != null ? '\n\n— stack —\n$stack' : ''}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Tekrar Dene'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.border,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text('Geri Dön'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Kilit Şeridi
class EllerKilitSeridi extends StatelessWidget {
  const EllerKilitSeridi({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.border, AppColors.divider],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFFCBD5E1),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BU OYUN SONUÇLANDI',
                        style: TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Skorlar salt okunur — geçmiş değiştirilemez.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// İlerleme Çubuğu
Widget ellerIlerlemeCubugu(int mevcut, int hedef) {
  final gosterilen = mevcut.clamp(0, hedef);
  final oran = hedef == 0 ? 0.0 : (gosterilen / hedef).clamp(0.0, 1.0);
  final kalan = (hedef - mevcut).clamp(0, hedef);
  final asildi = mevcut > hedef;

  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: AppColors.cardBg,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.route,
              size: 15,
              color: asildi ? AppColors.accentRed : AppColors.accentCyan,
            ),
            const SizedBox(width: 6),
            const Text(
              'İLERLEME',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$gosterilen / $hedef el',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: oran,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              asildi ? AppColors.accentRed : AppColors.accentCyan,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          asildi
              ? 'Hedef aşıldı · $mevcut el girildi'
              : (kalan > 0 ? '$kalan el kaldı' : 'Hedef el tamamlandı'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: asildi
                ? AppColors.accentRed
                : (kalan > 0 ? AppColors.textSecondary : AppColors.accentCyan),
          ),
        ),
      ],
    ),
  );
}
