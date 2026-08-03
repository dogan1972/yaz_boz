import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/models/kullanici.dart';
import 'package:yaz_boz/services/arkadas_servisi.dart';

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

  // ✅ istek akışı
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
    final snap = await _fs.collection('kullanicilar').get();
    if (!mounted) return;
    setState(() {
      _tumKullanicilar = snap.docs.map(Kullanici.fromFirestore).toList();
      _yukleniyor = false;
    });
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
    for (final k in _tumKullanicilar) {
      if (k.uid == uid) return k;
    }
    return null;
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
        backgroundColor: hata ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // ✅ ARTIK İSTEK GÖNDERİR — otomatik eklemez
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
      await _kullanicilariYukle(); // arkadaşlarım listesi yenilensin
      _bildir('Arkadaşlık onaylandı.', hata: false);
    } catch (e) {
      _bildir('Hata: $e', hata: true);
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
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Arkadaşlar',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _kodKarti(),
                const SizedBox(height: 14),
                _aramaKarti(),
                const SizedBox(height: 24),
                // ✅ GELEN İSTEKLER — bekleyen aksiyon, en üstte
                if (_gelenIstekler.isNotEmpty) ...[
                  _gelenIsteklerBolumu(),
                  const SizedBox(height: 24),
                ],
                _arkadaslarimBolumu(),
              ],
            ),
    );
  }

  // ── Davet kodu ile istek gönder ───────────────────────────
  Widget _kodKarti() {
    return _kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAVET KODU',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
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
                    color: Color(0xFFE2E8F0),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'YB7K2Q',
                    hintStyle: const TextStyle(color: Color(0xFF334155)),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF0B1220),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _aksiyonButonu(
                'İSTEK GÖNDER',
                const Color(0xFF2DD4BF),
                _kodIleEkle,
                yukleniyor: _ekliyor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Nick ile ara ──────────────────────────────────────────
  Widget _aramaKarti() {
    final sonuclar = _aramaSonuclari;
    final q = _aramaController.text.trim();
    return _kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NICK İLE ARA',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _aramaController,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
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
                      color: Color(0xFF64748B),
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
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
          _avatar(k.nick, 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              k.nick,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          zatenArkadas
              ? const Text(
                  '✓ Arkadaş',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
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
                      color: Color(0xFF94A3B8),
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Gönderildi',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : _aksiyonButonu(
                  'İSTEK',
                  const Color(0xFF2DD4BF),
                  () => _istekGonder(k),
                  kucuk: true,
                  yukleniyor: _ekliyor,
                ),
        ],
      ),
    );
  }

  // ── Gelen istekler ────────────────────────────────────────
  Widget _gelenIsteklerBolumu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.person_add_alt_1,
              color: Color(0xFFF59E0B),
              size: 14,
            ),
            const SizedBox(width: 8),
            const Text(
              'GELEN İSTEKLER',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_gelenIstekler.length}',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _kart(
          child: Column(
            children: [
              for (var i = 0; i < _gelenIstekler.length; i++) ...[
                if (i > 0)
                  const Divider(
                    color: Color(0xFF1E293B),
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
          _avatar(nick, 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nick,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          _aksiyonButonu(
            'REDDET',
            const Color(0xFF64748B),
            () => _istegiReddet(i),
            kucuk: true,
          ),
          const SizedBox(width: 8),
          _aksiyonButonu(
            'ONAYLA',
            const Color(0xFF2DD4BF),
            () => _istegiOnayla(i),
            kucuk: true,
          ),
        ],
      ),
    );
  }

  // ── Arkadaşlarım ──────────────────────────────────────────
  Widget _arkadaslarimBolumu() {
    final liste = _arkadaslarim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ARKADAŞLARIM',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${liste.length}',
                style: const TextStyle(
                  color: Color(0xFF2DD4BF),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (liste.isEmpty)
          _kart(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    const Icon(
                      Icons.group_add,
                      size: 40,
                      color: Color(0xFF334155),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Henüz arkadaşın yok.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
          _kart(
            child: Column(
              children: [
                for (var i = 0; i < liste.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      color: Color(0xFF1E293B),
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
          _avatar(k.nick, 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              k.nick,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.person_remove_alt_1,
              color: Color(0xFF64748B),
              size: 20,
            ),
            tooltip: 'Arkadaşlıktan çıkar',
            onPressed: () => _arkadasKaldir(k),
          ),
        ],
      ),
    );
  }

  // ── ortak parçalar ────────────────────────────────────────
  Widget _kart({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: child,
    );
  }

  Widget _avatar(String nick, double r) {
    final harf = nick.trim().isEmpty ? '?' : nick.trim()[0].toUpperCase();
    return Container(
      width: r * 2,
      height: r * 2,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        harf,
        style: TextStyle(
          color: const Color(0xFF1A1206),
          fontWeight: FontWeight.w900,
          fontSize: r * 0.9,
        ),
      ),
    );
  }

  Widget _aksiyonButonu(
    String etiket,
    Color renk,
    VoidCallback onTap, {
    bool kucuk = false,
    bool yukleniyor = false,
  }) {
    return Material(
      color: renk,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: yukleniyor ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: kucuk ? 12 : 18,
            vertical: kucuk ? 8 : 12,
          ),
          child: Text(
            etiket,
            style: TextStyle(
              color: renk == const Color(0xFF64748B)
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFF0A0F1C),
              fontWeight: FontWeight.w900,
              fontSize: kucuk ? 11 : 13,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
