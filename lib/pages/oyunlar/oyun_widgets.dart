// lib/pages/oyunlar/oyun_widgets.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:yaz_boz/models/oyun_model.dart';
import 'package:yaz_boz/services/auth_service.dart'; // ✅ EKLENDİ (grupId için)
import 'package:yaz_boz/theme/app_theme.dart';

/// Numara Rozeti
Widget oyunNumaraRozeti({
  int? n,
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
  BuildContext pageContext, {
  Oyun? oyun,
  required List<Oyuncu> guncelOyuncuListesi,
  required List<dynamic> turnuvalar,
}) async {
  // ✅ TARİH VE NUMARA HAZIRLIĞI
  String bugunTarih = DateFormat('dd.MM.yyyy').format(DateTime.now());
  int mevcutOyunNo = oyun?.numara ?? 0;

  String varsayilanBaslik =
      '$bugunTarih - Oyun ${mevcutOyunNo > 0 ? mevcutOyunNo : '?'}';

  final tarihCtrl = TextEditingController(
    text: oyun?.oyunTarih ?? varsayilanBaslik,
  );

  final elSayisiCtrl = TextEditingController(
    text: oyun?.elSayisi.toString() ?? '8',
  );

  // ✅ BOOL KARŞILAŞTIRMALARI DÜZELTİLDİ (int/bool karışıklığı giderildi)
  bool isEsli =
      oyun?.esliMi == true ||
      (oyun?.esliMi is int && (oyun?.esliMi as int) == 1);
  bool isYuksekKazanir =
      oyun?.yuksekSkorKazanir == true ||
      (oyun?.yuksekSkorKazanir is int && (oyun?.yuksekSkorKazanir as int) == 1);
  // ✅ TURNUVA FİLTRESİ (Tip güvenliği eklendi)
  final aktifTurnuvalar = <dynamic>[];
  for (var t in turnuvalar) {
    try {
      if (t.turKazanan == null && t.aktifMi == true) {
        aktifTurnuvalar.add(t);
      }
    } catch (_) {}
  }

  String? selectedTurId;
  if (oyun != null) {
    selectedTurId = oyun.turId;
  } else if (aktifTurnuvalar.isNotEmpty) {
    selectedTurId = aktifTurnuvalar.first.id;
  }

  if (oyun != null && selectedTurId != null) {
    dynamic seciliTurnuva;
    try {
      seciliTurnuva = turnuvalar.firstWhere((t) => t.id == selectedTurId);
    } catch (_) {
      seciliTurnuva = null;
    }

    if (seciliTurnuva == null || seciliTurnuva.turKazanan != null) {
      selectedTurId = aktifTurnuvalar.isNotEmpty
          ? aktifTurnuvalar.first.id
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageContext.mounted) {
          ScaffoldMessenger.of(pageContext).showSnackBar(
            const SnackBar(
              content: Text(
                'Bağlı turnuva sonlandırıldığı için yeni bir turnuva seçmeniz gerekiyor.',
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      });
    }
  }

  // ✅ 177-189. SATIRLAR (Oyuncu listesi - güvenli erişim)
  List<String> masaSirasiIsimleri = [];
  List<String> seciliUidler = [];

  if (oyun != null) {
    // Oyuncu ID'leri
    if (oyun.oyuncuIds != null && oyun.oyuncuIds!.isNotEmpty) {
      seciliUidler = List.from(oyun.oyuncuIds!);
    }

    // Oyuncu isimleri (split işlemi için null kontrolü)
    final oyuncuStr = oyun.oyuncu;
    if (oyuncuStr.isNotEmpty) {
      masaSirasiIsimleri = oyuncuStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  await showDialog(
    context: pageContext,
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
                // ✅ DROPDOWN (Tip dönüşümü yapıldı)
                if (aktifTurnuvalar.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedTurId,
                    decoration: InputDecoration(
                      labelText: 'Turnuva Seç',
                      labelStyle: const TextStyle(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: aktifTurnuvalar
                        .map<DropdownMenuItem<String>>(
                          (t) => DropdownMenuItem<String>(
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
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                            'Arkadaş listesi boş!',
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
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 16),
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

                // Eşli/Bireysel Switch
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
                              isEsli ? 'Eşli Oyun (2v2)' : 'Bireysel Oyun',
                              style: TextStyle(
                                color: isEsli
                                    ? AppColors.accentCyan
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
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

                // Kazanma Şartı Switch
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
                              ),
                            ),
                            const SizedBox(height: 2),
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
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (pageContext.mounted) {
                  showDialog(
                    context: pageContext,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                }

                final oyuncuString = masaSirasiIsimleri.join(', ');

                // ✅ GLOBAL NUMARATOR GÜNCELLEMESİ
                int oyunNo = mevcutOyunNo;
                if (oyun == null) {
                  final nRef = FirebaseFirestore.instance
                      .collection('metadata')
                      .doc('oyun_numarasi');
                  await FirebaseFirestore.instance.runTransaction((tx) async {
                    final doc = await tx.get(nRef);
                    if (doc.exists) {
                      oyunNo = (doc.data()?['son_numara'] ?? 0) + 1;
                      tx.update(nRef, {'son_numara': oyunNo});
                    } else {
                      tx.set(nRef, {'son_numara': 1});
                      oyunNo = 1;
                    }
                  });

                  String finalTarih = tarihCtrl.text.trim();
                  if (!finalTarih.contains('Oyun')) {
                    finalTarih = '$finalTarih - Oyun $oyunNo';
                  }
                  tarihCtrl.text = finalTarih;
                }

                // ✅ GRUP ID ALMA (AuthService üzerinden)
                final k = await AuthService().profilGarantile();
                final grupId = k?.grupId;

                if (oyun == null) {
                  await FirebaseFirestore.instance.collection('oyunlar').add({
                    'turId': selectedTurId,
                    'oyunTarih': tarihCtrl.text.trim(),
                    'elSayisi': int.tryParse(elSayisiCtrl.text) ?? 8,
                    'oyuncuSayisi': seciliUidler.length,
                    'oyuncular': oyuncuString,
                    'oyuncuIds': seciliUidler,
                    'esliMi': isEsli,
                    'yuksekSkorKazanir': isYuksekKazanir,
                    'numara': oyunNo,
                    'grupId': grupId,
                    'aktifMi': true,
                    'olusturma': FieldValue.serverTimestamp(),
                  });
                } else {
                  await FirebaseFirestore.instance
                      .collection('oyunlar')
                      .doc(oyun.id)
                      .update({
                        'turId': selectedTurId,
                        'oyunTarih': tarihCtrl.text.trim(),
                        'elSayisi': int.tryParse(elSayisiCtrl.text) ?? 8,
                        'oyuncuSayisi': seciliUidler.length,
                        'oyuncu': oyuncuString,
                        'oyuncuIds': seciliUidler,
                        'esliMi': isEsli,
                        'yuksekSkorKazanir': isYuksekKazanir,
                        'guncelleme': FieldValue.serverTimestamp(),
                      });
                }

                if (!pageContext.mounted) return;
                Navigator.pop(pageContext);
              } catch (e) {
                if (!pageContext.mounted) return;
                Navigator.pop(pageContext);
                ScaffoldMessenger.of(pageContext).showSnackBar(
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
