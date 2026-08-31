// lib/pages/oyunlar/oyun_widgets.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/models/oyun_model.dart';
import 'package:yaz_boz/services/oyun_servisi.dart';
import 'package:yaz_boz/theme/app_theme.dart';

/// Numara Rozeti
Widget oyunNumaraRozeti(
  int? n, {
  Color renk = AppColors.accentBlue,
  double? font,
}) {
  if (n == null) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: renk.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: renk.withValues(alpha: 0.55), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: renk.withValues(alpha: 0.30),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      '#$n',
      style: TextStyle(
        color: renk,
        fontWeight: FontWeight.w800,
        fontSize: font ?? 13,
        letterSpacing: 0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Silme Butonu
Widget oyunSilDugmesi({required VoidCallback onTap}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentRed.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentRed.withValues(alpha: 0.45),
            ),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: AppColors.accentRed,
            size: 22,
          ),
        ),
      ),
    ),
  );
}

/// Hero Aksiyon Butonu
Widget oyunHeroAksiyonButonu({
  required IconData icon,
  required Color renk,
  required String etiket,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: renk, size: 22),
          const SizedBox(height: 2),
          Text(
            etiket,
            style: TextStyle(
              color: renk.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> oyunFormuDiyalog(
  BuildContext context, {
  Oyun? oyun,
  required List<Oyuncu> guncelOyuncuListesi,
  required List<TurBilgisi> turnuvalar,
}) async {
  final tarihCtrl = TextEditingController(
    text: oyun?.oyunTarih ?? DateTime.now().toString().substring(0, 10),
  );
  final elSayisiCtrl = TextEditingController(
    text: oyun?.elSayisi.toString() ?? '8',
  );

  bool isEsli = oyun?.esliMi ?? false;
  bool isYuksekKazanir = oyun?.yuksekSkorKazanir ?? false;

  String? selectedTurId =
      oyun?.turId ?? (turnuvalar.isNotEmpty ? turnuvalar.first.id : null);

  // ✅ OYUNCU SEÇİMİNİ İSİM DEĞİL, UID ÜZERİNDEN YAPACAĞIZ
  // masaSirasi artık sadece isim tutacak (görsel için),
  // seciliUidler ise veritabanına gidecek asıl liste olacak.
  List<String> masaSirasiIsimleri = [];
  List<String> seciliUidler = [];

  if (oyun != null && oyun.oyuncu.isNotEmpty) {
    // Eski oyunlarda sadece isim var, uid yoksa boş bırakıyoruz.
    // Yeni sistemde oyun modelinde 'oyuncuIds' alanı olmalı.
    // Şimdilik geriye dönük uyumluluk için isimleri parse ediyoruz.
    masaSirasiIsimleri = oyun.oyuncu
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Eğer oyunda uid bilgisi varsa (Oyun modeline eklenmeli) buraya yükle
    // if (oyun.oyuncuIds != null) seciliUidler = List.from(oyun.oyuncuIds!);
  }

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Text(
          oyun == null ? 'Yeni Oyun Ekle' : 'Oyunu Düzenle',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TURNUVA SEÇİMİ
                if (turnuvalar.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedTurId,
                    decoration: InputDecoration(
                      labelText: 'Turnuva Seç',
                      labelStyle: const TextStyle(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    items: turnuvalar
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.turTarih),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => selectedTurId = val),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.accentRed,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Aktif turnuva bulunamadı! Önce turnuva oluşturun.',
                            style: TextStyle(
                              color: AppColors.accentRed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                TextField(
                  controller: tarihCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Oyun Tarihi / Adı',
                    labelStyle: const TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: elSayisiCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'El Sayısı',
                    labelStyle: const TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ OYUNCU HAVUZU - UID BAZLI SEÇİM
                const Text(
                  'Oyuncu Havuzu (Eklemek için tıkla):',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),

                if (guncelOyuncuListesi.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: AppColors.accentAmber,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Arkadaş listesi boş! Önce arkadaş ekleyin.',
                            style: TextStyle(
                              color: AppColors.accentAmber,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: guncelOyuncuListesi.map((o) {
                      final isSelected = seciliUidler.contains(o.id);
                      return FilterChip(
                        label: Text(
                          o.oyuncuAdSoyad,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (v) => setStateDialog(() {
                          if (v && !isSelected) {
                            seciliUidler.add(o.id);
                            masaSirasiIsimleri.add(o.oyuncuAdSoyad);
                          } else if (!v && isSelected) {
                            seciliUidler.remove(o.id);
                            masaSirasiIsimleri.removeWhere(
                              (element) => element == o.oyuncuAdSoyad,
                            );
                          }
                        }),
                        backgroundColor: AppColors.border,
                        selectedColor: AppColors.accentCyan,
                        checkmarkColor: Colors.black,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.accentCyan
                              : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 16),

                // ✅ MASADAKİLER LİSTESİ
                if (masaSirasiIsimleri.isNotEmpty) ...[
                  const Text(
                    'Masadaki Sıra:',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: List.generate(masaSirasiIsimleri.length, (
                        index,
                      ) {
                        final ad = masaSirasiIsimleri[index];
                        return ListTile(
                          key: ValueKey('player_$index'),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.accentAmber.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppColors.accentAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            ad,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => setStateDialog(() {
                                    final item = masaSirasiIsimleri.removeAt(
                                      index,
                                    );
                                    final uidItem = seciliUidler.removeAt(
                                      index,
                                    );
                                    masaSirasiIsimleri.insert(index - 1, item);
                                    seciliUidler.insert(index - 1, uidItem);
                                  }),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                  ),
                                ),
                              if (index < masaSirasiIsimleri.length - 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_downward,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => setStateDialog(() {
                                    final item = masaSirasiIsimleri.removeAt(
                                      index,
                                    );
                                    final uidItem = seciliUidler.removeAt(
                                      index,
                                    );
                                    masaSirasiIsimleri.insert(index + 1, item);
                                    seciliUidler.insert(index + 1, uidItem);
                                  }),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                  ),
                                ),
                            ],
                          ),
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ✅ EŞLİ OYUN TOGGLE
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEsli ? Icons.people : Icons.person,
                        color: isEsli
                            ? AppColors.accentCyan
                            : AppColors.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEsli
                                  ? 'Eşli Oyun (2v2 Takım)'
                                  : 'Bireysel Oyun',
                              style: TextStyle(
                                color: isEsli
                                    ? AppColors.accentCyan
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Eşli oyunda tahtada 4 oyuncu ikişerli takım olarak gruplanır',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isEsli,
                        onChanged: (v) => setStateDialog(() => isEsli = v),
                        activeThumbColor: AppColors.accentCyan,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ KAZANMA YÖNÜ TOGGLE
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isYuksekKazanir
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: isYuksekKazanir
                            ? AppColors.accentGreen
                            : AppColors.accentRed,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isYuksekKazanir
                                  ? 'En Yüksek Skor Kazanır'
                                  : 'En Düşük Skor Kazanır',
                              style: TextStyle(
                                color: isYuksekKazanir
                                    ? AppColors.accentGreen
                                    : AppColors.accentRed,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Oyun sonunda kazananı belirler',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isYuksekKazanir,
                        onChanged: (v) =>
                            setStateDialog(() => isYuksekKazanir = v),
                        activeThumbColor: AppColors.accentGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal', style: AppTextStyles.bodySecondary),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedTurId == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen bir turnuva seçin.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              if (seciliUidler.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('En az bir oyuncu seçmelisiniz!'),
                    backgroundColor: AppColors.accentRed,
                  ),
                );
                return;
              }

              try {
                final svc = OyunServisi();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                }

                final oyuncuString = masaSirasiIsimleri.join(', ');

                if (oyun == null) {
                  await svc.yeniOyunOlustur(
                    turId: selectedTurId!,
                    oyunTarih: tarihCtrl.text.trim(),
                    elSayisi: int.tryParse(elSayisiCtrl.text) ?? 8,
                    oyuncuSayisi: seciliUidler.length,
                    oyuncular: oyuncuString,
                    oyuncuIds: seciliUidler, // ✅ UID LİSTESİ GÖNDERİLİYOR
                    esliMi: isEsli,
                    yuksekSkorKazanir: isYuksekKazanir,
                  );
                } else {
                  await svc.oyunuGuncelle(oyun.id, {
                    'turId': selectedTurId,
                    'oyunTarih': tarihCtrl.text.trim(),
                    'elSayisi': int.tryParse(elSayisiCtrl.text) ?? 8,
                    'oyuncuSayisi': seciliUidler.length,
                    'oyuncu': oyuncuString,
                    'oyuncuIds': seciliUidler, // ✅ UID LİSTESİ GÜNCELLENİYOR
                    'esliMi': isEsli ? 1 : 0,
                    'yuksekSkorKazanir': isYuksekKazanir ? 1 : 0,
                  });
                }

                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: AppColors.accentRed,
                  ),
                );
              }
            },
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}
