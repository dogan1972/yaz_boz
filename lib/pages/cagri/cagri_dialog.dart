// lib/pages/cagri/cagri_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:yaz_boz/models/cagri_model.dart';
import 'package:yaz_boz/models/kullanici_model.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/theme/app_theme.dart';

Future<void> cagriAcDialogu(
  BuildContext context,
  String uid, {
  Cagri? mevcutCagri,
}) async {
  final profil = await AuthService().profilGarantile();

  // ✅ HATA DÜZELTMESİ 1: Async işlem sonrası context güvenliği
  if (!context.mounted) return;

  if (profil == null || profil.arkadasIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Önce arkadaş eklemelisin.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // AÇIK ÇAĞRI KONTROLÜ
  if (mevcutCagri == null) {
    final acikCagri = await FirebaseFirestore.instance
        .collection('cagrilar')
        .where('acanId', isEqualTo: uid)
        .where('durum', isEqualTo: 'acik')
        .limit(1)
        .get();

    if (acikCagri.docs.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Zaten açık bir çağrınız var. Önce onu sonlandırın veya iptal edin.',
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
  }

  // Form değişkenleri
  String? secilenSaat = mevcutCagri?.saat;
  String? secilenTarih = mevcutCagri?.tarih;

  // Birleştirilmiş Yer/Konum başlangıç değeri
  String birlesikYer = '';
  if (mevcutCagri != null) {
    final parts = <String>[];
    if (mevcutCagri.yer != null && mevcutCagri.yer!.isNotEmpty) {
      parts.add(mevcutCagri.yer!);
    }
    if (mevcutCagri.konumAd != null && mevcutCagri.konumAd!.isNotEmpty) {
      parts.add(mevcutCagri.konumAd!);
    }
    birlesikYer = parts.join(', ');
  }
  String secilenYer = birlesikYer;

  // GRUP BAZLI SEÇİM
  final seciliArkadaslar = <String>{};

  // ✅ HATA DÜZELTMESİ 2: Gereksiz null kontrolleri kaldırıldı
  // Blocun içinde olduğumuz için mevcutCagri ve davetliIds güvenli kabul edilir
  if (mevcutCagri != null) {
    seciliArkadaslar.addAll(mevcutCagri.davetliIds);
  } else if (profil.grupId != null) {
    // Yeni çağrı için grup mantığı
  }

  // Controller dialog öncesinde tanımlandı
  final yerController = TextEditingController(text: secilenYer);
  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            mevcutCagri == null ? 'Masayı Kur' : 'Çağrıyı Düzenle',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TARİH
                  const Text('TARİH', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: secilenTarih != null
                            ? DateFormat('dd.MM.yyyy').parse(secilenTarih!)
                            : DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accentAmber,
                              surface: AppColors.cardBg,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null && dialogContext.mounted) {
                        setDialogState(
                          () => secilenTarih = DateFormat(
                            'dd.MM.yyyy',
                          ).format(date),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.accentAmber,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            secilenTarih ?? 'Tarih seçin...',
                            style: TextStyle(
                              color: secilenTarih != null
                                  ? AppColors.textPrimary
                                  : AppColors.divider,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SAAT
                  const Text('SAAT', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: dialogContext,
                        initialTime: secilenSaat != null
                            ? TimeOfDay(
                                hour: int.parse(secilenSaat!.split(':')[0]),
                                minute: int.parse(secilenSaat!.split(':')[1]),
                              )
                            : TimeOfDay.now(),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accentAmber,
                              surface: AppColors.cardBg,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (time != null && dialogContext.mounted) {
                        setDialogState(
                          () => secilenSaat =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            color: AppColors.accentAmber,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            secilenSaat ?? 'Saat seçin...',
                            style: TextStyle(
                              color: secilenSaat != null
                                  ? AppColors.textPrimary
                                  : AppColors.divider,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // BİRLEŞTİRİLMİŞ YER / MEKAN ALANI
                  const Text('YER / MEKAN', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  TextField(
                    controller: yerController,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Örn: Delta Cafe, Saat Kulesi yanı',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) => secilenYer = val,
                  ),
                  const SizedBox(height: 20),

                  // ARKADAŞ LİSTESİ
                  const Text('KİMİ ÇAĞIRAYIM?', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('kullanicilar')
                        .where(FieldPath.documentId, whereIn: profil.arkadasIds)
                        .get(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentAmber,
                          ),
                        );
                      }
                      final arkadaslar = (snap.data?.docs ?? [])
                          .map(Kullanici.fromFirestore)
                          .toList();

                      if (seciliArkadaslar.isEmpty && profil.grupId != null) {
                        for (var k in arkadaslar) {
                          if (k.grupId == profil.grupId) {
                            seciliArkadaslar.add(k.uid);
                          }
                        }
                      }

                      if (arkadaslar.isEmpty) {
                        return const Text(
                          'Arkadaş listesi boş.',
                          style: AppTextStyles.bodySecondary,
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: arkadaslar.length,
                        itemBuilder: (ctx, i) {
                          final k = arkadaslar[i];
                          final secili = seciliArkadaslar.contains(k.uid);
                          return CheckboxListTile(
                            activeColor: AppColors.accentCyan,
                            checkColor: AppColors.bgPrimary,
                            value: secili,
                            title: Text(
                              k.nick,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onChanged: (val) => setDialogState(
                              () => val == true
                                  ? seciliArkadaslar.add(k.uid)
                                  : seciliArkadaslar.remove(k.uid),
                            ),
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç', style: AppTextStyles.bodySecondary),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentAmber,
                foregroundColor: const Color(0xFF1A1206),
              ),
              onPressed:
                  (seciliArkadaslar.isEmpty ||
                      secilenTarih == null ||
                      secilenYer.trim().isEmpty)
                  ? null
                  : () async {
                      final data = {
                        'saat': secilenSaat,
                        'tarih': secilenTarih,
                        'yer': secilenYer.trim(),
                        'davetliler': seciliArkadaslar.toList(),
                      };
                      Navigator.pop(dialogContext, data);
                    },
              child: Text(
                mevcutCagri == null ? 'MASAYI KUR' : 'GÜNCELLE',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    ),
  ).then((sonuc) async {
    if (sonuc == null || !context.mounted) return;
    final data = sonuc as Map<String, dynamic>;

    if (mevcutCagri != null) {
      await CagriServisi().cagriGuncelle(
        cagriId: mevcutCagri.id,
        saat: data['saat'] as String?,
        tarih: data['tarih'] as String?,
        yer: data['yer'] as String,
        konumAd: null,
        davetliIds: List<String>.from(data['davetliler']),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çağrı güncellendi.'),
            backgroundColor: AppColors.accentCyan,
          ),
        );
      }
    } else {
      await CagriServisi().cagriAc(
        acanId: uid,
        acanAd: profil.nick,
        davetliIds: List<String>.from(data['davetliler']),
        saat: data['saat'] as String?,
        yer: data['yer'] as String,
        konumAd: null,
        tarih: data['tarih'] as String?,
      );
    }
  });
}
