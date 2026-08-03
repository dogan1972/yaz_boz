// lib/widgets/cagri_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/kullanici.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';

Future<void> cagriAcDialogu(BuildContext context, String uid) async {
  final profil = await AuthService().profilGarantile();
  if (!context.mounted) return;

  if (profil == null || profil.arkadasIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Önce arkadaş eklemelisin.'), backgroundColor: Colors.orange),
    );
    return;
  }

  // Form verilerini tutacak değişkenler
  String? secilenSaat;
  String secilenYer = '';
  String secilenKonum = '';
  final seciliArkadaslar = <String>{};

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111A2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Masayı Kur', style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 18, fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. SAAT SEÇİMİ
                  const Text('SAAT', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final now = TimeOfDay.now();
                      final time = await showTimePicker(
                        context: dialogContext,
                        initialTime: now,
                        builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFF59E0B), surface: Color(0xFF111A2B))), child: child!),
                      );
                      if (time != null) {
                        setDialogState(() => secilenSaat = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF0B1220), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E293B))),
                      child: Row(children: [
                        const Icon(Icons.schedule, color: Color(0xFFFCD34D), size: 16),
                        const SizedBox(width: 8),
                        Text(secilenSaat ?? 'Saat seçin...', style: TextStyle(color: secilenSaat != null ? const Color(0xFFF8FAFC) : const Color(0xFF475569), fontSize: 14)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. YER BİLGİSİ
                  const Text('YER / MEKAN', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
                    decoration: InputDecoration(hintText: 'Örn: Kadıköy Çarşı', hintStyle: const TextStyle(color: Color(0xFF475569)), filled: true, fillColor: const Color(0xFF0B1220), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    onChanged: (val) => secilenYer = val,
                  ),
                  const SizedBox(height: 16),

                  // 3. KONUM NOTU
                  const Text('KONUM DETAYI', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
                    decoration: InputDecoration(hintText: 'Örn: Saat kulesi önü', hintStyle: const TextStyle(color: Color(0xFF475569)), filled: true, fillColor: const Color(0xFF0B1220), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    onChanged: (val) => secilenKonum = val,
                  ),
                  const SizedBox(height: 20),

                  // 4. ARKADAŞ LİSTESİ
                  const Text('KİMİ ÇAĞIRAYIM?', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('kullanicilar').where(FieldPath.documentId, whereIn: profil.arkadasIds).get(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
                      final arkadaslar = (snap.data?.docs ?? []).map(Kullanici.fromFirestore).toList();
                      if (arkadaslar.isEmpty) return const Text('Arkadaş listesi boş.', style: TextStyle(color: Color(0xFF64748B)));
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: arkadaslar.length,
                        itemBuilder: (ctx, i) {
                          final k = arkadaslar[i];
                          final secili = seciliArkadaslar.contains(k.uid);
                          return CheckboxListTile(
                            activeColor: const Color(0xFF2DD4BF),
                            checkColor: const Color(0xFF0A0F1C),
                            value: secili,
                            title: Text(k.nick, style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700)),
                            onChanged: (val) => setDialogState(() => val == true ? seciliArkadaslar.add(k.uid) : seciliArkadaslar.remove(k.uid)),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal', style: TextStyle(color: Color(0xFF94A3B8)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF1A1206)),
              onPressed: (seciliArkadaslar.isEmpty || secilenSaat == null || secilenYer.trim().isEmpty) 
                  ? null 
                  : () => Navigator.pop(dialogContext, {
                      'saat': secilenSaat,
                      'yer': secilenYer.trim(),
                      'konum': secilenKonum.trim(),
                      'davetliler': seciliArkadaslar.toList(),
                    }),
              child: const Text('MASAYI KUR', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    ),
  ).then((sonuc) async {
    if (sonuc == null || !context.mounted) return;
    
    final data = sonuc as Map<String, dynamic>;
    await CagriServisi().cagriAc(
      acanId: uid,
      acanAd: profil.nick,
      davetliIds: List<String>.from(data['davetliler']),
      saat: data['saat'] as String,
      yer: data['yer'] as String,
      konumAd: (data['konum'] as String).isEmpty ? null : data['konum'] as String,
    );
  });
}