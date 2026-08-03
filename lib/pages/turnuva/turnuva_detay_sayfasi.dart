import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yaz_boz/services/firestore_service.dart';
import 'package:yaz_boz/pages/eller/eller_sayfasi.dart';

class TurnuvaDetaySayfasi extends StatefulWidget {
  final String turnuvaId;
  final String turnuvaAdi;
  final int? turnuvaNumara;

  const TurnuvaDetaySayfasi({
    super.key,
    required this.turnuvaId,
    required this.turnuvaAdi,
    this.turnuvaNumara,
  });

  @override
  State<TurnuvaDetaySayfasi> createState() => _TurnuvaDetaySayfasiState();
}

class _TurnuvaDetaySayfasiState extends State<TurnuvaDetaySayfasi> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<Map<String, dynamic>> _detayFuture;

  @override
  void initState() {
    super.initState();
    _detayFuture = _verileriGetir();
  }

  Future<Map<String, dynamic>> _verileriGetir() async {
    try {
      final turDoc = await _firestoreService.getDocument(
        'turnuva',
        widget.turnuvaId,
      );
      final turData = turDoc.data() as Map<String, dynamic>? ?? {};

      final oyunlarSnap = await _firestoreService.getCollection('oyunlar');
      final turnuvaOyunlari = oyunlarSnap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['turId'] == widget.turnuvaId;
      }).toList();

      turnuvaOyunlari.sort((a, b) {
        final ta =
            (a.data() as Map<String, dynamic>)['oyunTarih']?.toString() ?? '';
        final tb =
            (b.data() as Map<String, dynamic>)['oyunTarih']?.toString() ?? '';
        return ta.compareTo(tb);
      });

      final biten = turnuvaOyunlari
          .where(
            (d) => (d.data() as Map<String, dynamic>)['oyunKaybeden'] != null,
          )
          .length;

      return {
        'turData': turData,
        'oyunlar': turnuvaOyunlari,
        'bitenOyun': biten,
        'toplamOyun': turnuvaOyunlari.length,
      };
    } catch (e) {
      debugPrint("Turnuva detayı yüklenirken hata: $e");
      return {
        'turData': <String, dynamic>{},
        'oyunlar': <DocumentSnapshot>[],
        'bitenOyun': 0,
        'toplamOyun': 0,
        'hata': e.toString(),
      };
    }
  }

  Widget _numaraRozeti(int? n, {Color renk = Colors.white, double? font}) {
    if (n == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: renk.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Text(
        '#$n',
        style: TextStyle(
          color: renk,
          fontWeight: FontWeight.w800,
          fontSize: font ?? 14,
          letterSpacing: 0.6,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numaraRozeti(widget.turnuvaNumara),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${widget.turnuvaAdi} Detayları',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detayFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            );
          }
          if (snapshot.hasError) return _hataEkrani(snapshot.error.toString());
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Veri yüklenemedi.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            );
          }

          final data = snapshot.data!;
          if (data['hata'] != null) {
            return _hataEkrani(data['hata'].toString());
          }

          final turData = data['turData'] as Map<String, dynamic>? ?? {};
          final oyunlar = data['oyunlar'] as List<DocumentSnapshot>? ?? [];
          final toplam = data['toplamOyun'] as int? ?? 0;
          final biten = data['bitenOyun'] as int? ?? 0;
          final sonlandi = turData['turKazanan'] != null;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _banner(turData, sonlandi, toplam, biten),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'OYUN GEÇMİŞİ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.4,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${oyunlar.length} kayıt',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              oyunlar.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _BosOyun(),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _oyunKarti(oyunlar[index], index),
                          childCount: oyunlar.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _banner(Map<String, dynamic> t, bool sonlandi, int toplam, int biten) {
    final kazanan = t['turKazanan']?.toString();
    final ikinci = t['turIkinci']?.toString();
    final ucuncu = t['turUcuncu']?.toString();
    final kaybeden = t['turKaybeden']?.toString();
    final podyumVar = [
      kazanan,
      ikinci,
      ucuncu,
      kaybeden,
    ].any((s) => s != null && s.isNotEmpty);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2740), Color(0xFF0E1626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _numaraRozeti(
                                widget.turnuvaNumara,
                                renk: const Color(0xFFFCD34D),
                                font: 15,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sonlandi
                                        ? const Color(
                                            0xFF4ADE80,
                                          ).withValues(alpha: 0.18)
                                        : const Color(
                                            0xFFF59E0B,
                                          ).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!sonlandi) const _PulseDot(),
                                      if (!sonlandi) const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          sonlandi
                                              ? 'TAMAMLANDI'
                                              : 'DEVAM EDİYOR',
                                          style: TextStyle(
                                            color: sonlandi
                                                ? const Color(0xFF4ADE80)
                                                : const Color(0xFFFCD34D),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t['turTarih']?.toString() ?? widget.turnuvaAdi,
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.05,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _ilerlemeModulu(toplam, biten, sonlandi),
                  ],
                ),
                if (podyumVar) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _madalya(
                        '🏆',
                        'Şampiyon',
                        kazanan,
                        const Color(0xFFFFD54F),
                      ),
                      _madalya('🥈', 'İkinci', ikinci, const Color(0xFFCFD8DC)),
                      _madalya('🥉', 'Üçüncü', ucuncu, const Color(0xFFFFAB91)),
                      _madalya(
                        '📉',
                        'Sonuncu',
                        kaybeden,
                        const Color(0xFFEF9A9A),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _aksiyonKapsul(
                      icon: Icons.delete_outline,
                      etiket: 'Sil',
                      renk: const Color(0xFFFCD34D),
                      onTap: _turnuvayiSil,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ilerlemeModulu(int toplam, int biten, bool sonlandi) {
    final oran = toplam == 0 ? 0.0 : (biten / toplam).clamp(0.0, 1.0);
    final vurgu = sonlandi ? const Color(0xFFFCD34D) : const Color(0xFF5EEAD4);
    return SizedBox(
      width: 112,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: oran),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.16),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(vurgu),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: vurgu.withValues(alpha: 0.35),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    sonlandi
                        ? const Icon(
                            Icons.emoji_events,
                            color: Color(0xFFFCD34D),
                            size: 32,
                          )
                        : Text(
                            '$biten',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                              height: 1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _turnuvayiSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF111A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_outline,
              color: Color(0xFFFCD34D),
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Turnuvayı Sil',
              style: TextStyle(color: Color(0xFFF8FAFC)),
            ),
          ],
        ),
        content: const Text(
          'Bu turnuvayı ve altındaki TÜM oyunları + girilmiş el skorlarını kalıcı olarak silmek istediğinize emin misiniz?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text(
              'Kalıcı Sil',
              style: TextStyle(
                color: Color(0xFFFCD34D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      ),
    );
    try {
      final tumOyunlarSnap = await _firestoreService.getCollection('oyunlar');
      final silinecekOyunlar = tumOyunlarSnap.docs
          .where(
            (d) =>
                (d.data() as Map<String, dynamic>)['turId'] == widget.turnuvaId,
          )
          .toList();
      for (var oyunDoc in silinecekOyunlar) {
        final oyunId = oyunDoc.id;
        final tumEllerSnap = await _firestoreService.getCollection('eller');
        final silinecekEller = tumEllerSnap.docs
            .where(
              (d) => (d.data() as Map<String, dynamic>)['oyunId'] == oyunId,
            )
            .map((d) => d.id)
            .toList();
        for (var elId in silinecekEller) {
          await _firestoreService.deleteDocument('eller', elId);
        }
        await _firestoreService.deleteDocument('oyunlar', oyunId);
      }
      await _firestoreService.deleteDocument('turnuva', widget.turnuvaId);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Turnuva ve tüm alt verileri silindi.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      debugPrint('Turnuva silme hatası: $e');
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _aksiyonKapsul({
    required IconData icon,
    required String etiket,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.white.withValues(alpha: 0.10),
        splashColor: renk.withValues(alpha: 0.30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: renk, size: 18),
              const SizedBox(width: 8),
              Text(
                etiket,
                style: TextStyle(
                  color: renk,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _madalya(String emoji, String etiket, String? ad, Color renk) {
    if (ad == null || ad.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.5), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  etiket,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  ad,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _oyunKarti(DocumentSnapshot doc, int index) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final kaybeden = d['oyunKaybeden']?.toString();
    final bitti = kaybeden != null;
    final esli = d['esliMi'] == true || d['esliMi'] == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EllerSayfasi(oyunId: doc.id, isHighestWins: esli),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: bitti
                    ? const Color(0xFF4ADE80).withValues(alpha: 0.30)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: bitti
                            ? [const Color(0xFF4ADE80), const Color(0xFF15803D)]
                            : [
                                const Color(0xFFF59E0B),
                                const Color(0xFFC2410C),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d['oyunTarih']?.toString() ??
                                    'Oyun #${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFFF8FAFC),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!bitti) const _PulseDot(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d['oyuncu']?.toString() ?? '',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        bitti
                            ? Row(
                                children: [
                                  const Text(
                                    '🏆 ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Expanded(
                                    child: Text(
                                      d['oyunKazanan']?.toString() ?? '-',
                                      style: const TextStyle(
                                        color: Color(0xFF4ADE80),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Text(
                                    '📉 ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Flexible(
                                    child: Text(
                                      kaybeden,
                                      style: const TextStyle(
                                        color: Color(0xFFF87171),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Devam ediyor…',
                                style: TextStyle(
                                  color: Color(0xFFFCD34D),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hataEkrani(String hata) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Color(0xFFFCA5A5), size: 56),
            const SizedBox(height: 16),
            const Text(
              'Veri yüklenirken hata oluştu',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFFFCA5A5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hata,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => setState(() => _detayFuture = _verileriGetir()),
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF1A1206),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CANLI NABIZ NOKTASI (KORUNDU)
// ─────────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Opacity(
        opacity: 0.4 + 0.6 * _c.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.orange.shade400,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.6 * _c.value),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOŞ OYUN DURUMU
// ─────────────────────────────────────────────────────────────
class _BosOyun extends StatelessWidget {
  const _BosOyun();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_esports, size: 56, color: Color(0xFF334155)),
          const SizedBox(height: 12),
          const Text(
            'Bu turnuvada henüz oyun oynanmamış.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'İlk oyun başlatıldığında burada görünecek.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
