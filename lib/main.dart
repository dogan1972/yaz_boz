// lib/main.dart
import 'dart:async';
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
import 'package:yaz_boz/pages/arkadas/arkadas_sayfasi.dart';
import 'package:yaz_boz/pages/profil/profil_sayfasi.dart';
import 'package:yaz_boz/pages/cagri/cagri_panosu_wrapper.dart';
import 'package:yaz_boz/widgets/app_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

void main() async {
  ErrorWidget.builder = (FlutterErrorDetails details) => AppHataKarti(
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
      theme: appTheme, // ✅ TEMADAN ÇEKİLİYOR
      routes: {'/dashboard': (context) => const AnaSayfa()},
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentAmber,
                ), // ✅ RENK GÜNCELLENDİ
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
      backgroundColor: AppColors.bgPrimary, // ✅ TEMADAN
      appBar: AppBar(
        toolbarHeight: 45.0,
        title: const Text('Yaz Boz', style: AppTextStyles.heading), // ✅ STİLDEN
        actions: [
          IconButton(
            iconSize: 40,
            icon: const Icon(
              Icons.settings_power,
              color: AppColors.accentRed,
            ), // ✅ RENKTEN
            tooltip: 'Uygulamadan Çık',
            onPressed: () async {
              bool? onay = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: AppColors.cardBg, // ✅ RENKTEN
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.exit_to_app, color: AppColors.accentRed),
                      SizedBox(width: 8),
                      Text('Uygulamadan Çık', style: AppTextStyles.bodyPrimary),
                    ],
                  ),
                  content: const Text(
                    'Uygulamadan çıkmak istediğinize emin misiniz? Devam eden oyunlarınız kaydedilmiştir.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text(
                        'İptal',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: AppColors.accentRed,
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: CagriPanoWrapper(),
        ),
      ),
      body: Stack(
        children: [
          const AppDashboardToz(),
          Positioned(
            top: -120,
            left: -80,
            child: appGlow(AppColors.accentAmber, 260),
          ), // ✅ RENKTEN
          Positioned(
            bottom: -140,
            right: -90,
            child: appGlow(AppColors.accentCyan, 280),
          ), // ✅ RENKTEN
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
                        appMenuButon(
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
                        appMenuButon(
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
                        appMenuButon(
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
                        appMenuButon(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.group_add,
                          renk: AppColors.accentCyan,
                          baslik: "Arkadaşlar",
                          altBaslik: "QR, kod veya nick ile ekle",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ArkadasSayfasi(),
                            ),
                          ),
                        ),
                        appMenuButon(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.notifications_active_rounded,
                          renk: AppColors.accentBlue,
                          baslik: "Çağrılar",
                          altBaslik: "Masa kur & çağrıları gör",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CagriAnaSayfasi(),
                            ),
                          ),
                        ),
                        appMenuButon(
                          genislik: kartGenisligi,
                          isYatay: isYatay,
                          icon: Icons.account_circle,
                          renk: AppColors.accentAmber,
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
}
