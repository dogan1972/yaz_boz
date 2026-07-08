import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaz_boz/helper/database_helper.dart';
import 'package:yaz_boz/models/oyunlar_model.dart';

// Sayfa Importları
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8FA),
      ),
      home: const AnaSayfa(),
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
      appBar: AppBar(
        toolbarHeight: 45.0,
        title: const Text('Yaz Boz Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.settings_power, color: Colors.white),
            tooltip: 'Uygulamadan Çık',
            onPressed: () async {
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
                    'Uygulamadan çıkmak istediğinize emin misiniz? Devam eden oyunlarınız kaydedilmiştir.',
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
              if (onay == true) {
                await SystemNavigator.pop();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double genislik = constraints.maxWidth;
            int sutunSayisi = isYatay ? 3 : 2;

            // Öğelerin dağılmasını ve taşmasını donanımsal olarak önleyen genişlik paylaştırma formülü
            final double kartGenisligi =
                (genislik - (32 + (sutunSayisi - 1) * 14.0)) / sutunSayisi;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: isYatay ? 12.0 : 20.0,
                bottom: isYatay ? 12.0 : 20.0,
              ),
              child: Center(
                child: Wrap(
                  spacing: 14.0,
                  runSpacing: 14.0,
                  alignment: WrapAlignment.center,
                  children: [
                    _dashboardButonuOlustur(
                      genislik: kartGenisligi,
                      isYatay: isYatay,
                      icon: Icons.calendar_month,
                      renk: Colors.orange,
                      baslik: "Sezonlar",
                      altBaslik: "Sezon yönetimi yapın",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SezonlarSayfasi(),
                        ),
                      ),
                    ),
                    _dashboardButonuOlustur(
                      genislik: kartGenisligi,
                      isYatay: isYatay,
                      icon: Icons.emoji_events,
                      renk: Colors.amber.shade700,
                      baslik: "Turnuvalar",
                      altBaslik: "Etkinlikleri duzenleyin",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TurnuvaSayfasi(),
                        ),
                      ),
                    ),
                    _dashboardButonuOlustur(
                      genislik: kartGenisligi,
                      isYatay: isYatay,
                      icon: Icons.sports_esports,
                      renk: Colors.purple,
                      baslik: "Oyunlar",
                      altBaslik: "Yeni oyun başlatın",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OyunlarSayfasi(),
                        ),
                      ),
                    ),
                    _dashboardButonuOlustur(
                      genislik: kartGenisligi,
                      isYatay: isYatay,
                      icon: Icons.style,
                      renk: Colors.teal,
                      baslik: "Yaz Boz Tahtası",
                      altBaslik: "Skor ve el girişleri",
                      onTap: () async {
                        final aktifOyun = await Oyun.enSonAktifOyunuGetir();
                        if (!context.mounted) return;
                        if (aktifOyun != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EllerSayfasi(
                                oyunId: aktifOyun.oyunId!,
                                isHighestWins: false,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "⚠️ Devam eden aktif bir oyun bulunamadi!",
                              ),
                              backgroundColor: Colors.orangeAccent,
                            ),
                          );
                        }
                      },
                    ),
                    _dashboardButonuOlustur(
                      genislik: kartGenisligi,
                      isYatay: isYatay,
                      icon: Icons.people,
                      renk: Colors.blue,
                      baslik: "Oyuncular",
                      altBaslik: "Masadaki katılımcılar",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OyuncuSayfasi(),
                        ),
                      ),
                    ),
                    _dashboardButonuOlustur(
                      genislik: kartGenisligi,
                      isYatay: isYatay,
                      icon: Icons.location_city,
                      renk: Colors.blueGrey,
                      baslik: "Şehirler",
                      altBaslik: "Bölge kayıtları",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SehirlerSayfasi(),
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

  // 🚀 ÖĞELERİN DAĞILMASINI ÖNLEYEN VE SABİT ORANDA TUTAN BÜYÜK BOYUTLU KART ŞABLONU
  Widget _dashboardButonuOlustur({
    required double genislik,
    required bool isYatay,
    required IconData icon,
    required Color renk,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        width: genislik,
        // Kart yüksekliği dikey/yatay oranlarına göre sabitlenerek kaymalar engellendi
        height: isYatay ? 140.0 : 165.0,
        decoration: BoxDecoration(
          // 🎯 PASTEL ARKA PLAN: İstediğiniz #03E7F7 yumuşatılmış turkuaz opaklık tonu
          color: const Color.fromARGB(255, 3, 231, 247).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: renk.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: renk.withValues(alpha: 0.15),
              blurRadius: 8.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🎯 İKON ALANI: Seçtiğiniz büyük ölçekli ve şık dairesel ikon yerleşimi
              CircleAvatar(
                radius: isYatay ? 18.0 : 22.0,
                backgroundColor: Colors.white,
                child: Icon(icon, color: renk, size: isYatay ? 22.0 : 26.0),
              ),
              SizedBox(height: isYatay ? 8.0 : 12.0),
              // Ana Başlık (Yazı boyutu büyük olsa bile ellipsis ile arayüzü korur)
              Text(
                baslik,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isYatay ? 15.0 : 17.0,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4.0),
              // 🎯 ALT BAŞLIK: Dağılmayı önleyen 1 satırlık akıllı sönümleme filtresi
              Text(
                altBaslik,
                style: TextStyle(
                  fontSize: isYatay ? 11.0 : 11.0,
                  color: Colors.grey.shade600,
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
    );
  }
}
