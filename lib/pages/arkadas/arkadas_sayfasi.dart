// lib/pages/arkadas/arkadas_sayfasi.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/kullanici_model.dart';
import 'package:yaz_boz/services/arkadas_servisi.dart';
import 'package:yaz_boz/pages/arkadas/arkadas_widgets.dart';
import 'package:yaz_boz/theme/app_theme.dart';

class ArkadasSayfasi extends StatefulWidget {
  const ArkadasSayfasi({super.key});
  @override
  State<ArkadasSayfasi> createState() => _ArkadasSayfasiState();
}

class _ArkadasSayfasiState extends State<ArkadasSayfasi> {
  final _fs = FirebaseFirestore.instance;
  final _kodController = TextEditingController();
  final _aramaController = TextEditingController();

  List<Kullanici> _tumKullanicilar = [];
  bool _yukleniyor = true;
  bool _ekliyor = false;

  List<ArkadaslikIstegi> _gelenIstekler = [];
  Set<String> _gidenAlanIds = {};
  StreamSubscription<List<ArkadaslikIstegi>>? _gelenSub;
  StreamSubscription<List<ArkadaslikIstegi>>? _gidenSub;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(() => setState(() {}));
    _kullanicilariYukle();
    _istekleriDinle();
  }

  @override
  void dispose() {
    _kodController.dispose();
    _aramaController.dispose();
    _gelenSub?.cancel();
    _gidenSub?.cancel();
    super.dispose();
  }

  void _istekleriDinle() {
    final uid = _uid;
    if (uid == null) return;
    _gelenSub = ArkadasServisi().gelenIsteklerStreami(uid).listen((liste) {
      if (mounted) setState(() => _gelenIstekler = liste);
    });
    _gidenSub = ArkadasServisi().gidenIsteklerStreami(uid).listen((liste) {
      if (mounted) {
        setState(() => _gidenAlanIds = {for (final i in liste) i.alan});
      }
    });
  }

  Future<void> _kullanicilariYukle() async {
    try {
      final snap = await _fs.collection('kullanicilar').get();
      if (!mounted) return;

      final kullanicilar = snap.docs.map(Kullanici.fromFirestore).toList();

      setState(() {
        _tumKullanicilar = kullanicilar;
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint("Kullanıcılar yüklenirken hata: $e");
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // lib/pages/arkadas/arkadas_sayfasi.dart - _grupAdiDuzenleDialog metodu

  Future<void> _grupAdiDuzenleDialog() async {
    final safeContext = context;

    final ben = _ben;
    if (ben == null || ben.uid.isEmpty) {
      if (mounted) _bildir('Kullanıcı bilgisi bulunamadı.', hata: true);
      return;
    }

    // ✅ YENİ: GRUP ID'Yİ DOĞRUDAN FIRESTORE'DAN ÇEK (MODEL HATASINI ÖNLER)
    final userDoc = await _fs.collection('kullanicilar').doc(ben.uid).get();
    if (!safeContext.mounted) return;

    final userData = userDoc.data();
    final String? grupId = userData?['grupId'] as String?;
    final String? grupAdi = userData?['grupAdi'] as String?;

    if (grupId == null || grupId.isEmpty) {
      debugPrint('❌ HATA: Firestore\'da grupId yok! UserData: $userData');
      if (mounted) {
        _bildir(
          'Grup bilgisi bulunamadı. Lütfen gruptan ayrılıp tekrar katılın.',
          hata: true,
        );
      }
      return;
    }

    debugPrint('✅ Başarılı: Grup ID bulundu -> $grupId');

    final grupRef = _fs.collection('gruplar').doc(grupId.trim());
    final grupDoc = await grupRef.get();

    if (!safeContext.mounted) return;

    if (!grupDoc.exists) {
      debugPrint('❌ HATA: Grup dokümanı gerçekten yok! ID: $grupId');
      _bildir(
        'Grup dokümanı bulunamadı! (ID: $grupId)\nLütfen gruptan ayrılıp tekrar katılın.',
        hata: true,
      );
      return;
    }

    final ctrl = TextEditingController(text: grupAdi ?? '');

    final yeniAd = await showDialog<String>(
      context: safeContext,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Grup Adını Değiştir',
          style: AppTextStyles.bodyPrimary,
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Yeni Grup Adı',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(color: AppColors.textHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('İptal', style: AppTextStyles.bodySecondary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
            ),
            child: const Text(
              'Kaydet',
              style: TextStyle(
                color: Color(0xFF1A1206),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    // Dialog sonrası mounted kontrolü
    if (!mounted || yeniAd == null || yeniAd.isEmpty || yeniAd == grupAdi) {
      ctrl.dispose();
      return;
    }

    try {
      // ✅ 1. ADIM: Grup ID'sini tekrar al (Güvenlik için)
      final currentGrupId = ben.grupId?.trim();
      if (currentGrupId == null || currentGrupId.isEmpty) {
        if (mounted) _bildir('Grup bilgisi kayboldu.', hata: true);
        return;
      }

      // Güncelleme öncesi son güvenlik kontrolü
      if (!(await grupRef.get()).exists) {
        if (mounted) _bildir('Grup silinmiş, güncellenemedi.', hata: true);
        return;
      }

      // 2. Grup dokümanını güncelle
      await grupRef.update({'grupAdi': yeniAd});

      // ✅ 3. YENİ: O gruptaki TÜM kullanıcıların profilini güncelle
      final kullanicilarSnap = await _fs
          .collection('kullanicilar')
          .where(
            'grupId',
            isEqualTo: currentGrupId,
          ) // ✅ Artık temizGrupId yerine currentGrupId
          .get();

      if (kullanicilarSnap.docs.isNotEmpty) {
        final batch = _fs.batch();
        for (var doc in kullanicilarSnap.docs) {
          batch.update(doc.reference, {'grupAdi': yeniAd});
        }
        await batch.commit();
        debugPrint(
          '✅ Grup adı güncellendi ve ${kullanicilarSnap.docs.length} kullanıcı profili yenilendi.',
        );
      }

      if (mounted) {
        await _kullanicilariYukle(); // Listeyi yenile
        _bildir('Grup adı başarıyla güncellendi.', hata: false);
      }
    } catch (e) {
      if (mounted) _bildir('Güncelleme hatası: $e', hata: true);
    } finally {
      ctrl.dispose();
    }
  }

  Kullanici? get _ben {
    final uid = _uid;
    if (uid == null) return null;
    for (final k in _tumKullanicilar) {
      if (k.uid == uid) return k;
    }
    return null;
  }

  Kullanici? _kullaniciBul(String uid) {
    try {
      return _tumKullanicilar.firstWhere((k) => k.uid == uid);
    } catch (_) {
      return null;
    }
  }

  List<Kullanici> get _arkadaslarim {
    final ben = _ben;
    if (ben == null) return [];
    return _tumKullanicilar
        .where((k) => ben.arkadasIds.contains(k.uid))
        .toList();
  }

  List<Kullanici> get _aramaSonuclari {
    final q = _aramaController.text.trim().toLowerCase();
    final benUid = _uid;
    if (q.isEmpty) return [];
    return _tumKullanicilar.where((k) {
      if (k.uid == benUid) return false;
      return k.nick.toLowerCase().contains(q);
    }).toList();
  }

  void _bildir(String m, {required bool hata}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: hata ? AppColors.accentRed : AppColors.accentGreen,
      ),
    );
  }

  Future<void> _istekGonder(Kullanici hedef) async {
    final ben = _ben;
    if (ben == null) return;
    if (ben.arkadasIds.contains(hedef.uid)) {
      _bildir('${hedef.nick} zaten arkadaşın.', hata: false);
      return;
    }
    setState(() => _ekliyor = true);
    try {
      await ArkadasServisi().istekGonder(ben.uid, hedef.uid);
      _bildir('${hedef.nick} kişisine istek gönderildi.', hata: false);
    } catch (e) {
      _bildir('Gönderilemedi: $e', hata: true);
    } finally {
      if (mounted) setState(() => _ekliyor = false);
    }
  }

  Future<void> _istegiOnayla(ArkadaslikIstegi i) async {
    final ben = _uid;
    if (ben == null) return;
    try {
      await ArkadasServisi().istegiOnayla(i.id, i.gonderen, ben);
      await _kullanicilariYukle();
      _bildir('Arkadaşlık onaylandı ve gruba dahil oldunuz.', hata: false);
    } catch (e) {
      _bildir(e.toString(), hata: true);
    }
  }

  Future<void> _istegiReddet(ArkadaslikIstegi i) async {
    try {
      await ArkadasServisi().istegiReddet(i.id);
    } catch (e) {
      _bildir('Hata: $e', hata: true);
    }
  }

  Future<void> _arkadasKaldir(Kullanici hedef) async {
    final ben = _ben;
    if (ben == null) return;
    try {
      await _fs.collection('kullanicilar').doc(ben.uid).update({
        'arkadasIds': FieldValue.arrayRemove([hedef.uid]),
      });
      await _fs.collection('kullanicilar').doc(hedef.uid).update({
        'arkadasIds': FieldValue.arrayRemove([ben.uid]),
      });
      await _kullanicilariYukle();
      _bildir('${hedef.nick} arkadaşlıktan çıkarıldı.', hata: false);
    } catch (e) {
      _bildir('Hata: $e', hata: true);
    }
  }

  Future<void> _gruptanAyril() async {
    final ben = _ben;
    if (ben == null || ben.grupId == null) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Gruptan Ayrıl', style: AppTextStyles.bodyPrimary),
        content: const Text(
          'Bu gruptan ayrılmak istediğinize emin misiniz?\n\nGrup üyeleriyle olan sezon/turnuva erişiminiz kesilecek ancak arkadaşlığınız devam edecek.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: AppTextStyles.bodySecondary),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );

    if (onay == true && mounted) {
      try {
        await ArkadasServisi().gruptanAyril(ben.uid);
        await _kullanicilariYukle();
        _bildir('Gruptan başarıyla ayrıldınız.', hata: false);
      } catch (e) {
        _bildir('Ayrılma hatası: $e', hata: true);
      }
    }
  }

  Future<void> _kodIleEkle() async {
    final kod = _kodController.text.trim().toUpperCase();
    if (kod.length != 6) {
      _bildir('Davet kodu 6 haneli olmalı.', hata: true);
      return;
    }
    setState(() => _ekliyor = true);
    try {
      final snap = await _fs
          .collection('kullanicilar')
          .where('davetKodu', isEqualTo: kod)
          .get();
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        _bildir('Bu kodla kullanıcı bulunamadı.', hata: true);
        return;
      }
      final hedef = Kullanici.fromFirestore(snap.docs.first);
      if (hedef.uid == _uid) {
        _bildir('Kendi kodunu ekleyemezsin.', hata: true);
        return;
      }
      await _istekGonder(hedef);
      _kodController.clear();
    } catch (e) {
      _bildir('Hata: $e', hata: true);
    } finally {
      if (mounted) setState(() => _ekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Arkadaşlar', style: AppTextStyles.heading),
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentAmber),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _grupBilgiKarti(),
                const SizedBox(height: 14),
                _kodKarti(),
                const SizedBox(height: 14),
                _aramaKarti(),
                const SizedBox(height: 24),
                if (_gelenIstekler.isNotEmpty) ...[
                  _gelenIsteklerBolumu(),
                  const SizedBox(height: 24),
                ],
                _arkadaslarimBolumu(),
              ],
            ),
    );
  }

  Widget _grupBilgiKarti() {
    final ben = _ben;
    final grupAdi = ben?.grupAdi ?? ben?.grupId;

    return arkadasKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      color: grupAdi != null
                          ? AppColors.accentCyan
                          : AppColors.textHint,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('GRUP DURUMU', style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (grupAdi != null)
                IconButton(
                  icon: const Icon(
                    Icons.edit_note,
                    color: AppColors.accentAmber,
                    size: 20,
                  ),
                  tooltip: 'Grup Adını Değiştir',
                  onPressed: _grupAdiDuzenleDialog,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (grupAdi != null) ...[
            Text(
              grupAdi,
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sezon ve turnuvalara sadece bu grup üzerinden erişebilirsiniz.',
              style: TextStyle(color: Color(0xFF475569), fontSize: 11),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _gruptanAyril,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('GRUPTAN AYRIL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentRed,
                  side: BorderSide(
                    color: AppColors.accentRed.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Henüz bir gruba dahil değilsiniz.',
              style: TextStyle(color: Color(0xFF475569), fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bir arkadaşlık isteğini onayladığınızda otomatik olarak o kişinin grubuna dahil olursunuz.',
              style: TextStyle(color: Color(0xFF334155), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kodKarti() {
    return arkadasKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAVET KODU', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          const Text(
            'Arkadaşının profilindeki kodu buraya yaz',
            style: TextStyle(color: Color(0xFF475569), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kodController,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'YB7K2Q',
                    hintStyle: const TextStyle(color: AppColors.divider),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              arkadasAksiyonButonu(
                'İSTEK GÖNDER',
                AppColors.accentCyan,
                _kodIleEkle,
                yukleniyor: _ekliyor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aramaKarti() {
    final sonuclar = _aramaSonuclari;
    final q = _aramaController.text.trim();
    return arkadasKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NICK İLE ARA', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: AppColors.textHint, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _aramaController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Takma ad yaz…',
                      hintStyle: TextStyle(color: Color(0xFF475569)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (q.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textHint,
                      size: 18,
                    ),
                    onPressed: () => _aramaController.clear(),
                  ),
              ],
            ),
          ),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (sonuclar.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Eşleşen kullanıcı yok.',
                  style: AppTextStyles.bodySecondary,
                ),
              )
            else
              ...sonuclar.map(_sonucSatiri),
          ],
        ],
      ),
    );
  }

  Widget _sonucSatiri(Kullanici k) {
    final zatenArkadas = _ben?.arkadasIds.contains(k.uid) ?? false;
    final istekGonderildi = _gidenAlanIds.contains(k.uid);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          arkadasAvatar(k.nick, 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              k.nick,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          zatenArkadas
              ? const Text(
                  '✓ Arkadaş',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                )
              : istekGonderildi
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.textSecondary,
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text('Gönderildi', style: AppTextStyles.bodySecondary),
                  ],
                )
              : arkadasAksiyonButonu(
                  'İSTEK',
                  AppColors.accentCyan,
                  () => _istekGonder(k),
                  kucuk: true,
                  yukleniyor: _ekliyor,
                ),
        ],
      ),
    );
  }

  Widget _gelenIsteklerBolumu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        arkadasBolumBasligi(
          'GELEN İSTEKLER',
          _gelenIstekler.length,
          AppColors.accentAmber,
        ),
        const SizedBox(height: 10),
        arkadasKart(
          child: Column(
            children: [
              for (var i = 0; i < _gelenIstekler.length; i++) ...[
                if (i > 0)
                  const Divider(
                    color: AppColors.border,
                    height: 1,
                    thickness: 1,
                  ),
                _istekSatiri(_gelenIstekler[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _istekSatiri(ArkadaslikIstegi i) {
    final k = _kullaniciBul(i.gonderen);
    final nick = k?.nick ?? 'Bilinmeyen';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          arkadasAvatar(nick, 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nick,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          arkadasAksiyonButonu(
            'REDDET',
            AppColors.textHint,
            () => _istegiReddet(i),
            kucuk: true,
          ),
          const SizedBox(width: 8),
          arkadasAksiyonButonu(
            'ONAYLA',
            AppColors.accentCyan,
            () => _istegiOnayla(i),
            kucuk: true,
          ),
        ],
      ),
    );
  }

  Widget _arkadaslarimBolumu() {
    final liste = _arkadaslarim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        arkadasBolumBasligi('ARKADAŞLARIM', liste.length, AppColors.accentCyan),
        const SizedBox(height: 10),
        if (liste.isEmpty)
          arkadasKart(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    const Icon(
                      Icons.group_add,
                      size: 40,
                      color: AppColors.divider,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Henüz arkadaşın yok.',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Yukarıdan kod ya da nick ile istek gönder.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          arkadasKart(
            child: Column(
              children: [
                for (var i = 0; i < liste.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      color: AppColors.border,
                      height: 1,
                      thickness: 1,
                    ),
                  _arkadasSatiri(liste[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _arkadasSatiri(Kullanici k) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          arkadasAvatar(k.nick, 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              k.nick,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.person_remove_alt_1,
              color: AppColors.textHint,
              size: 20,
            ),
            tooltip: 'Arkadaşlıktan çıkar',
            onPressed: () => _arkadasKaldir(k),
          ),
        ],
      ),
    );
  }
}
