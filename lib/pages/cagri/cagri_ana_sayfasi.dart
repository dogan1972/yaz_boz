// lib/pages/cagri/cagri_ana_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:yaz_boz/widgets/cagri_panosu_wrapper.dart';
import 'package:yaz_boz/services/auth_service.dart';
import 'package:yaz_boz/services/cagri_servisi.dart';
import 'package:yaz_boz/models/cagri.dart';
import 'package:yaz_boz/pages/salon/salon_sayfasi.dart';
import 'package:yaz_boz/widgets/cagri_dialog.dart';

class CagriAnaSayfasi extends StatefulWidget {
  const CagriAnaSayfasi({super.key});
  @override
  State<CagriAnaSayfasi> createState() => _CagriAnaSayfasiState();
}

class _CagriAnaSayfasiState extends State<CagriAnaSayfasi> {
  late final String? _uid;
  late final Stream<List<Cagri>> _listeStream;

  @override
  void initState() {
    super.initState();
    _uid = AuthService().uid;
    _listeStream = CagriServisi().son24SaatCagrilariStreami(_uid!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text(
          'YAZ BOZ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Color(0xFFF8FAFC),
          ),
        ),
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ✅ ÜSTTE canlı pano (nabız + zil + kilit)
          const CagriPanoWrapper(),

          // ✅ ALTTA son 24 saatin defteri
          Expanded(
            child: StreamBuilder<List<Cagri>>(
              stream: _listeStream,
              builder: (context, snap) {
                final liste = snap.data ?? const [];
                if (liste.isEmpty) return _BosDurumEkrani(uid: _uid);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: liste.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 10, top: 4),
                        child: Text(
                          'SON 24 SAAT',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      );
                    }
                    return _CagriKarti(cagri: liste[i - 1], uid: _uid!);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ÇAĞRI KARTI — tıkla → masa açılır (aktif / mühürlü / sonlandı)
// ─────────────────────────────────────────────────────────────
class _DurumBilgisi {
  final String etiket;
  final Color renk;
  final IconData ikon;
  const _DurumBilgisi(this.etiket, this.renk, this.ikon);
}

class _CagriKarti extends StatelessWidget {
  final Cagri cagri;
  final String uid;
  const _CagriKarti({required this.cagri, required this.uid});

  bool get _benAcan => cagri.acanId == uid;

  _DurumBilgisi get _durum {
    switch (cagri.durum) {
      case 'acik':
        return const _DurumBilgisi(
          'AÇIK',
          Color(0xFFF59E0B),
          Icons.table_restaurant,
        );
      case 'onaylandi':
        return const _DurumBilgisi(
          'MÜHÜRLÜ',
          Color(0xFF2DD4BF),
          Icons.verified_user_rounded,
        );
      case 'sonlandi':
        return const _DurumBilgisi(
          'SONLANDI',
          Color(0xFF64748B),
          Icons.power_settings_new,
        );
      default:
        return _DurumBilgisi(
          cagri.durum.toUpperCase(),
          const Color(0xFF64748B),
          Icons.circle,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _durum;
    // ✅ AÇAN 1. ONAYDIR — 4 kişilik masa 1/4 başlar, 4/4 biter
    final onay = cagri.onaylar.length + 1;
    final toplam = cagri.davetliIds.length + 1;
    final aktif = cagri.durum == 'acik' || cagri.durum == 'onaylandi';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SalonSayfasi(cagriId: cagri.id, uid: uid),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111A2B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: aktif
                    ? d.renk.withValues(alpha: 0.5)
                    : const Color(0xFF1E293B),
                width: aktif ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: d.renk.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(d.ikon, color: d.renk, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            d.etiket,
                            style: TextStyle(
                              color: d.renk,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _benAcan
                                  ? 'sen açtın'
                                  : '${cagri.acanAd} çağırdı',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (cagri.saat != null && cagri.saat!.isNotEmpty) ...[
                            const Icon(
                              Icons.schedule,
                              color: Color(0xFFFCD34D),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cagri.saat!,
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (cagri.yer != null && cagri.yer!.isNotEmpty) ...[
                            const Icon(
                              Icons.place,
                              color: Color(0xFF38BDF8),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cagri.yer!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text(
                      '$onay/$toplam',
                      style: TextStyle(
                        color: d.renk,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'onay',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOŞ DURUM — son 24 saatte hiçbir çağrı yoksa
// ─────────────────────────────────────────────────────────────
class _BosDurumEkrani extends StatelessWidget {
  final String? uid;
  const _BosDurumEkrani({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_restaurant_rounded,
              size: 64,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'MASA BOŞ',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Son 24 saatte çağrı yok.\nYeni bir masa kur veya arkadaşını bekle.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF475569), fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => cagriAcDialogu(context, uid!),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('ÇAĞRI AÇ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0A0F1C),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
