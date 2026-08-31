// lib/pages/sezon/sezon_detay_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/services/sezon_servisi.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class OyuncuDetayIstatistik {
  final String oyuncuAdi;
  final int oynadigiOyun, kazandigiOyun, kaybettigiOyun;
  OyuncuDetayIstatistik({
    required this.oyuncuAdi,
    required this.oynadigiOyun,
    required this.kazandigiOyun,
    required this.kaybettigiOyun,
  });
}

class SezonDetaySayfasi extends StatefulWidget {
  final String sezonId;
  final String sezonAdi;
  final int? sezonNumara;
  const SezonDetaySayfasi({
    super.key,
    required this.sezonId,
    required this.sezonAdi,
    this.sezonNumara,
  });

  @override
  State<SezonDetaySayfasi> createState() => _SezonDetaySayfasiState();
}

class _SezonDetaySayfasiState extends State<SezonDetaySayfasi> {
  late Future<Map<String, dynamic>> _istatistikFuture;

  @override
  void initState() {
    super.initState();
    _istatistikFuture = SezonServisi().sezonIstatistikHesapla(widget.sezonId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _istatistikFuture,
          builder: (context, snapshot) {
            final bool isLowestWins =
                (snapshot.data?['isLowestWins'] as bool?) ?? true;
            return Row(
              children: [
                Flexible(
                  child: Text(
                    '${widget.sezonAdi} Detayları',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isLowestWins
                                ? AppColors.accentGreen
                                : AppColors.accentRed)
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isLowestWins ? '↓ Düşük' : '↑ Yüksek',
                    style: TextStyle(
                      fontSize: 10,
                      color: isLowestWins
                          ? AppColors.accentGreen
                          : AppColors.accentRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _istatistikFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentAmber),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Hata: ${snapshot.error}',
                style: const TextStyle(color: AppColors.accentRed),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Veri yok',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final data = snapshot.data!;
          final toplamOyun = data['toplamOyun'] as int? ?? 0;
          final oyuncuListesi =
              (data['oyuncuIstatistikleri'] as List?)
                  ?.whereType<OyuncuDetayIstatistik>()
                  .toList() ??
              [];

          // ✅ BOŞ SEZON ÖZEL GÖRÜNÜMÜ
          if (toplamOyun == 0 && oyuncuListesi.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: AppColors.divider,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bu sezon boş olarak sonlandırılmış.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Henüz hiç oyun oynanmamış veya tüm veriler silinmiş.',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          // ✅ YATAY/DİKEY HER İKİ MODDA GÜVENLİ SCROLL
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _tarihBloku(
                            "Başlangıç",
                            data['baslangicTarihi'],
                            Icons.play_circle_outline,
                            AppColors.accentGreen,
                          ),
                          SizedBox(
                            height: 40,
                            child: VerticalDivider(
                              width: 20,
                              thickness: 1,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          _tarihBloku(
                            "Bitiş",
                            data['bitisTarihi'],
                            Icons.stop_circle_outlined,
                            AppColors.accentRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Sezon Rekor Verileri",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  _detayKarti(
                    icon: Icons.tag,
                    renk: AppColors.accentPurple,
                    baslik: "Toplam Oynanan Oyun",
                    deger: "${data['toplamOyun']} Maç",
                  ),
                  _detayKarti(
                    icon: Icons.emoji_events,
                    renk: AppColors.accentGreen,
                    baslik: "En Çok Kazanan",
                    deger: data['enCokKazanan'],
                  ),
                  _detayKarti(
                    icon: Icons.trending_down,
                    renk: AppColors.accentRed,
                    baslik: "En Çok Yenilen",
                    deger: data['enCokYenilen'],
                  ),
                  _detayKarti(
                    icon: Icons.star,
                    renk: AppColors.accentAmber,
                    baslik: "En İyi Skor",
                    deger: data['enIyiSkor'],
                  ),
                  _detayKarti(
                    icon: Icons.gavel,
                    renk: const Color(0xFFB45309),
                    baslik: "En Kötü Skor",
                    deger: data['enKotuSkor'],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Oyuncu İstatistikleri",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),

                  // ✅ YATAY SCROLL + DİNAMİK SÜTUN GENİŞLİĞİ
                  oyuncuListesi.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "Bu sezona ait oyuncu verisi bulunmuyor.",
                              style: TextStyle(color: AppColors.textHint),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.divider,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Table(
                              columnWidths: const {
                                0: IntrinsicColumnWidth(),
                                1: FixedColumnWidth(70),
                                2: FixedColumnWidth(70),
                                3: FixedColumnWidth(70),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              border: const TableBorder(
                                horizontalInside: BorderSide(
                                  color: AppColors.divider,
                                  width: 1,
                                ),
                                verticalInside: BorderSide(
                                  color: AppColors.divider,
                                  width: 1,
                                ),
                              ),
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Oyuncu',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Oynadı',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Kazandı',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Kaybetti',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                ...oyuncuListesi.map(
                                  (istatistik) => TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8.0,
                                        ),
                                        child: Text(
                                          istatistik.oyuncuAdi,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          istatistik.oynadigiOyun.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          istatistik.kazandigiOyun.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.accentGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          istatistik.kaybettigiOyun.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.accentRed,
                                            fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tarihBloku(String baslik, String deger, IconData icon, Color renk) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: renk, size: 16),
            const SizedBox(width: 4),
            Text(
              baslik,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          deger,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _detayKarti({
    required IconData icon,
    required Color renk,
    required String baslik,
    required String deger,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: renk.withValues(alpha: 0.1),
            child: Icon(icon, color: renk, size: 18),
          ),
          title: Text(
            baslik,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
          trailing: Text(
            deger,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
