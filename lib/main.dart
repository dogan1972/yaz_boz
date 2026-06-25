import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaz_boz/helper/database_helper.dart';
import 'package:yaz_boz/models/oyunlar_model.dart';
import 'package:yaz_boz/pages/sezonlar_sayfasi.dart';
import 'package:yaz_boz/pages/turnuva_sayfasi.dart';
import 'package:yaz_boz/pages/oyunlar_sayfasi.dart';
import 'package:yaz_boz/pages/eller_sayfasi.dart';
import 'package:yaz_boz/pages/oyuncu_sayfasi.dart';
import 'package:yaz_boz/pages/sehirler_sayfasi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper().database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaz Boz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yaz Boz Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.power_settings_new,
              color: Colors.white,
            ), // Güç/Kapatma ikonu
            tooltip: 'Uygulamadan Çık',
            onPressed: () async {
              // Yanlışlıkla basılmalara karşı onay penceresi açıyoruz
              bool? onay = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Uygulamadan Çık'),
                    ],
                  ),
                  content: const Text(
                    'Uygulamadan çıkmak istediğinize emin misiniz? Devam eden tüm oyunlarınız veritabanına kaydedilmiştir.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              // Kullanıcı onay verdiyse uygulamayı tamamen kapatır
              if (onay == true) {
                await SystemNavigator.pop();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          children: [
            // 1. KUTU: SEZONLAR
            _dashboardButonuOlustur(
              icon: Icons.calendar_month,
              renk: Colors.orange,
              baslik: "Sezonlar",
              altBaslik: "Sezon yonetimi yapin",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SezonlarSayfasi(),
                  ),
                );
              },
            ),
            // 2. KUTU: TURNUVALAR
            _dashboardButonuOlustur(
              icon: Icons.emoji_events,
              renk: Colors.amber.shade700,
              baslik: "Turnuvalar",
              altBaslik: "Etkinlikleri duzenleyin",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TurnuvaSayfasi(),
                  ),
                );
              },
            ),
            // 3. KUTU: OYUNLAR
            _dashboardButonuOlustur(
              icon: Icons.sports_esports,
              renk: Colors.purple,
              baslik: "Oyunlar",
              altBaslik: "Yeni oyun baslatin",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OyunlarSayfasi(),
                  ),
                );
              },
            ),
            // 4. KUTU: YAZ BOZ TAHTASI
            _dashboardButonuOlustur(
              icon: Icons.style,
              renk: Colors.teal,
              baslik: "Yaz Boz Tahtasi",
              altBaslik: "Skor ve el girisleri",
              onTap: () async {
                final aktifOyun = await Oyun.enSonAktifOyunuGetir();
                if (!context.mounted) return;

                if (aktifOyun != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EllerSayfasi(
                        oyunId: aktifOyun.oyunId!,
                        isHighestWins:
                            false, // 🚀 GÖRSELDEKİ GETTER HATASI BURADA 112. SATIRDA SIFIRLANDI
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "⚠️ Devam eden aktif bir oyun bulunamadi! Once 'Oyunlar' menusunden yeni bir oyun acin.",
                      ),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                }
              },
            ),
            // 5. KUTU: OYUNCULAR
            _dashboardButonuOlustur(
              icon: Icons.people,
              renk: Colors.blue,
              baslik: "Oyuncular",
              altBaslik: "Masadaki katilimcilar",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OyuncuSayfasi(),
                  ),
                );
              },
            ),
            // 6. KUTU: ŞEHİRLER
            _dashboardButonuOlustur(
              icon: Icons.location_city,
              renk: Colors.blueGrey,
              baslik: "Sehirler",
              altBaslik: "Bolge kayitlari",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SehirlerSayfasi(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardButonuOlustur({
    required IconData icon,
    required Color renk,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Card(
        elevation: 4.0,
        shadowColor: renk.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26.0,
                backgroundColor: renk.withValues(alpha: 0.15),
                child: Icon(icon, color: renk, size: 28.0),
              ),
              const SizedBox(height: 12.0),
              Text(
                baslik,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4.0),
              Text(
                altBaslik,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
