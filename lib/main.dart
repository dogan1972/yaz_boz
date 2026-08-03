// lib/main.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/pages/login/login_page.dart';
import 'package:yaz_boz/pages/cagri/cagri_ana_sayfasi.dart';
import 'package:yaz_boz/pages/oyunlar/oyunlar_sayfasi.dart';
import 'package:yaz_boz/pages/sezon/sezonlar_sayfasi.dart';
import 'package:yaz_boz/pages/turnuva/turnuva_sayfasi.dart';
import 'package:yaz_boz/pages/oyuncu/oyuncu_sayfasi.dart';
import 'package:yaz_boz/pages/sehirler/sehirler_sayfasi.dart';
import 'package:yaz_boz/pages/arkadas/arkadas_sayfasi.dart';
import 'package:yaz_boz/pages/profil/profil_sayfasi.dart';
import 'package:yaz_boz/widgets/cagri_panosu_wrapper.dart';

// ─────────────────────────────────────────────────────────────
// GLOBAL KALKAN — beyaz ekranı imkânsız kılar (debug + release)
// ─────────────────────────────────────────────────────────────
void main() async {
  ErrorWidget.builder = (FlutterErrorDetails details) => _HataKarti(
    baslik: 'SAYFA YÜKLENEMEDİ',
    hata: '${details.exception}',
    stack: details.stack?.toString(),
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 FlutterError: ${details.exception}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('🔴 PlatformDispatcher hata: $error\n$stack');
    return true;
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      runApp(const MyApp());
    },
    (Object error, StackTrace stack) {
      debugPrint('🔴 runZonedGuarded: $error\n$stack');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaz Boz',
      debugShowCheckedModeBanner: false,
      // ✅ TEK TEMA = KOYU. Efektlerin DNA'sı karanlık.
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0F1C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1220),
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
        ),
        cardColor: const Color(0xFF111A2B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFF2DD4BF),
          surface: Color(0xFF111A2B),
        ),
        dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF111A2B)),
      ),
      routes: {'/dashboard': (context) => const AnaSayfa()},
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
              ),
            );
          }
          if (snapshot.hasData) return const AnaSayfa();
          return const LoginPage();
        },
      ),
    );
  }
}

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isYatay =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        toolbarHeight: 45.0,
        title: const Text(
          'Yaz Boz',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: CagriPanoWrapper(),
        ),
        actions: [
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.settings_power, color: Color(0xFFFCA5A5)),
            tooltip: 'Uygulamadan Çık',
            onPressed: () async {
              bool? onay = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF111A2B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Color(0xFFFCA5A5)),
                      SizedBox(width: 8),
                      Text(
                        'Uygulamadan Çık',
                        style: TextStyle(color: Color(0xFFF8FAFC)),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Uygulamadan çıkmak istediğinize emin misiniz? Devam eden oyunlarınız kaydedilmiştir.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text(
                        'İptal',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (onay == true) await SystemNavigator.pop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ✅ KATMANLI SAHNE: toz arkada, içerik önde
      body: Stack(
        children: [
          const _DashboardToz(),
          // üstte hafif amber/teal ambient glow — sahne "yaşıyor"
          Positioned(
            top: -120,
            left: -80,
            child: _glow(const Color(0xFFF59E0B), 260),
          ),
          Positioned(
            bottom: -140,
            right: -90,
            child: _glow(const Color(0xFF2DD4BF), 280),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double genislik = constraints.maxWidth;
                int sutunSayisi = isYatay ? 3 : 2;
                final double kartGenisligi =
                    (genislik - (32 + (sutunSayisi - 1) * 12.0)) / sutunSayisi;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: isYatay ? 10.0 : 14.0,
                    bottom: isYatay ? 10.0 : 14.0,
                  ),
                  child: Center(
                    child: Wrap(
                      spacing: 12.0,
                      runSpacing: 12.0,
                      alignment: WrapAlignment.center,
                      children: [
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.calendar_month,
                          renk: Colors.orange,
                          baslik: "Sezonlar",
                          altBaslik: "Sezon yönetimi yapın",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SezonlarSayfasi(),
                            ),
                          ),
                        ),
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.emoji_events,
                          renk: Colors.amber.shade700,
                          baslik: "Turnuvalar",
                          altBaslik: "Etkinlikleri duzenleyin",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TurnuvaSayfasi(),
                            ),
                          ),
                        ),
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.sports_esports,
                          renk: Colors.purple.shade300,
                          baslik: "Oyunlar",
                          altBaslik: "Yeni oyun başlatın",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OyunlarSayfasi(),
                            ),
                          ),
                        ),
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.people,
                          renk: const Color(0xFF60A5FA),
                          baslik: "Oyuncular",
                          altBaslik: "Masadaki katılımcılar",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OyuncuSayfasi(),
                            ),
                          ),
                        ),
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.location_city,
                          renk: const Color(0xFF94A3B8),
                          baslik: "Şehirler",
                          altBaslik: "Bölge kayıtları",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SehirlerSayfasi(),
                            ),
                          ),
                        ),
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.group_add,
                          renk: const Color(0xFF2DD4BF),
                          baslik: "Arkadaşlar",
                          altBaslik: "QR, kod veya nick ile ekle",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ArkadasSayfasi(),
                            ),
                          ),
                        ),
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.notifications_active_rounded,
                          renk: const Color(0xFF38BDF8),
                          baslik: "Çağrılar",
                          altBaslik: "Masa kur & çağrıları gör",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CagriAnaSayfasi(),
                            ),
                          ),
                        ),
                        _buton(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.account_circle,
                          renk: const Color(0xFFF59E0B),
                          baslik: "Profil",
                          altBaslik: "Nick, QR ve müsaitlik",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfilSayfasi(),
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
        ],
      ),
    );
  }

  // ambient köşe ışığı
  Widget _glow(Color renk, double boyut) {
    return IgnorePointer(
      child: Container(
        width: boyut,
        height: boyut,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [renk.withValues(alpha: 0.10), Colors.transparent],
          ),
        ),
      ),
    );
  }

  Widget _buton({
    required double genislik,
    required bool isYatay,
    required IconData icon,
    required Color renk,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        // dokunma anında renk dalgası — micro-interaction
        splashColor: renk.withValues(alpha: 0.18),
        highlightColor: renk.withValues(alpha: 0.10),
        child: Container(
          width: genislik,
          height: isYatay ? 104.0 : 122.0,
          decoration: BoxDecoration(
            // ✅ gece zemini + renk kenarlık + renk gölge = yaşayan kart
            color: const Color(0xFF111A2B),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: renk.withValues(alpha: 0.35), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: renk.withValues(alpha: 0.18),
                blurRadius: 14.0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 10.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ tint'li yuvarlak yuva — beyaz avatar yerine geceye uyumlu
                Container(
                  width: (isYatay ? 30.0 : 38.0),
                  height: (isYatay ? 30.0 : 38.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: renk.withValues(alpha: 0.16),
                    border: Border.all(
                      color: renk.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(icon, color: renk, size: isYatay ? 18.0 : 22.0),
                ),
                SizedBox(height: isYatay ? 6.0 : 8.0),
                Text(
                  baslik,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isYatay ? 13.0 : 14.0,
                    color: const Color(0xFFF8FAFC),
                    letterSpacing: -0.2,
                    height: 1.12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3.0),
                Text(
                  altBaslik,
                  style: const TextStyle(
                    fontSize: 10.0,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DASHBOARD TOZU — ambient süzülen ışık (profil/çağrı ile aynı dil)
// ─────────────────────────────────────────────────────────────
class _DashboardToz extends StatefulWidget {
  const _DashboardToz();
  @override
  State<_DashboardToz> createState() => _DashboardTozState();
}

class _DashboardTozState extends State<_DashboardToz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_DT> _p;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    final r = Random();
    _p = List.generate(14, (_) => _DT(r));
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
          child: CustomPaint(painter: _DashboardTozBoyaci(_p, _c.value)),
        ),
      ),
    );
  }
}

class _DT {
  final double x, y0, r, hiz, faz;
  final Color renk;
  _DT(Random r)
    : x = r.nextDouble(),
      y0 = r.nextDouble(),
      r = 1 + r.nextDouble() * 2.0,
      hiz = 0.25 + r.nextDouble() * 0.6,
      faz = r.nextDouble(),
      renk = r.nextBool() ? const Color(0xFFF59E0B) : const Color(0xFF2DD4BF);
}

class _DashboardTozBoyaci extends CustomPainter {
  final List<_DT> p;
  final double t;
  _DashboardTozBoyaci(this.p, this.t);
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
  bool shouldRepaint(covariant _DashboardTozBoyaci old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────
// GLOBAL HATA KARTI — ErrorWidget.builder burayı basar
//   (bir "alarm" olarak bilinçli beyaz+kırmızı; temadan bağımsız)
// ─────────────────────────────────────────────────────────────
class _HataKarti extends StatelessWidget {
  final String baslik;
  final String hata;
  final String? stack;

  const _HataKarti({required this.baslik, required this.hata, this.stack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
                  color: const Color(0x59000000),
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
                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
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
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bug_report_outlined,
                                  color: Color(0xFFDC2626),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      baslik,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 1.6,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Bir hata yakalandı — uygulama çökmedi.',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
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
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  '$hata${stack != null ? '\n\n— stack —\n$stack' : ''}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.5,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Bu metni geliştiriciye iletin — kök neden burada yazar.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
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
}
