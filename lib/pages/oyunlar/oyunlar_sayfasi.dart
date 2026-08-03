import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/services/firestore_service.dart';
import 'package:yaz_boz/pages/eller/eller_sayfasi.dart';

// ✅ OYUNCU MODELİ
class Oyuncu {
  final String id;
  final String oyuncuAdSoyad;
  final String oyuncuSehir;

  Oyuncu({
    required this.id,
    required this.oyuncuAdSoyad,
    required this.oyuncuSehir,
  });

  factory Oyuncu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Oyuncu(
      id: doc.id,
      oyuncuAdSoyad: data['oyuncuAdSoyad'] ?? '',
      oyuncuSehir: data['oyuncuSehir'] ?? '',
    );
  }
}

// ✅ TURNUVA MODELİ (dropdown için)
class Turnuva {
  final String id;
  final String turTarih;
  final String? turKazanan;

  Turnuva({required this.id, required this.turTarih, this.turKazanan});

  factory Turnuva.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Turnuva(
      id: doc.id,
      turTarih: data['turTarih'] ?? '',
      turKazanan: data['turKazanan'],
    );
  }
}

// ✅ OYUN MODELİ  (+ numara)
class Oyun {
  final String id;
  final int? numara;
  final String turId;
  final String oyunTarih;
  final int elSayisi;
  final int oyuncuSayisi;
  final String oyuncu;
  final String? oyunKazanan;
  final String? oyunKaybeden;
  final bool esliMi;

  Oyun({
    required this.id,
    this.numara,
    required this.turId,
    required this.oyunTarih,
    required this.elSayisi,
    required this.oyuncuSayisi,
    required this.oyuncu,
    this.oyunKazanan,
    this.oyunKaybeden,
    required this.esliMi,
  });

  factory Oyun.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Oyun(
      id: doc.id,
      numara: (data['numara'] as num?)?.toInt(),
      turId: data['turId'] ?? '',
      oyunTarih: data['oyunTarih'] ?? '',
      elSayisi: data['elSayisi'] ?? 8,
      oyuncuSayisi: data['oyuncuSayisi'] ?? 4,
      oyuncu: data['oyuncu'] ?? '',
      oyunKazanan: data['oyunKazanan'],
      oyunKaybeden: data['oyunKaybeden'],
      esliMi: data['esliMi'] == true || data['esliMi'] == 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'numara': numara,
    'turId': turId,
    'oyunTarih': oyunTarih,
    'elSayisi': elSayisi,
    'oyuncuSayisi': oyuncuSayisi,
    'oyuncu': oyuncu,
    'oyunKazanan': oyunKazanan,
    'oyunKaybeden': oyunKaybeden,
    'esliMi': esliMi ? 1 : 0,
  };
}

class OyunlarSayfasi extends StatefulWidget {
  const OyunlarSayfasi({super.key});

  @override
  State<OyunlarSayfasi> createState() => _OyunlarSayfasiState();
}

class _OyunlarSayfasiState extends State<OyunlarSayfasi> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _tarihController = TextEditingController();
  final TextEditingController _elSayisiController = TextEditingController();
  final TextEditingController _oyuncuSayisiController = TextEditingController();
  final TextEditingController _oyuncuListesiController =
      TextEditingController();
  final TextEditingController _kazananController = TextEditingController();
  final TextEditingController _kaybedenController = TextEditingController();

  List<Oyun> _tumOyunlar = [];
  List<Turnuva> _turnuvalar = [];
  List<Oyuncu> _tumOyuncular = [];
  List<String> _formdaSeciliOyuncular = [];

  String? _seciliTurId;
  bool _isHighestWins = false;
  bool _gosterArsiv = false;
  bool _esliMi = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
    _yardimciVerileriYukle();
  }

  void _verileriDinle() {
    _firestoreService.getCollectionStream('oyunlar').listen((snapshot) {
      if (!mounted) return;
      final yeniOyunlar = snapshot.docs
          .map((doc) => Oyun.fromFirestore(doc))
          .toList();
      if (yeniOyunlar.length != _tumOyunlar.length ||
          !_listelerEsitMi(yeniOyunlar, _tumOyunlar)) {
        setState(() {
          _tumOyunlar = yeniOyunlar;
          _isLoading = false;
        });
      } else if (_isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  bool _listelerEsitMi(List<Oyun> a, List<Oyun> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].oyunKazanan != b[i].oyunKazanan ||
          a[i].oyunTarih != b[i].oyunTarih) {
        return false;
      }
    }
    return true;
  }

  Future<void> _yardimciVerileriYukle() async {
    try {
      final turnuvaSnap = await _firestoreService.getCollection('turnuva');
      final oyuncuSnap = await _firestoreService.getCollection('oyuncular');
      if (!mounted) return;
      setState(() {
        _turnuvalar = turnuvaSnap.docs
            .where(
              (d) => (d.data() as Map<String, dynamic>)['turKazanan'] == null,
            )
            .map((d) => Turnuva.fromFirestore(d))
            .toList();
        _tumOyuncular = oyuncuSnap.docs
            .map((d) => Oyuncu.fromFirestore(d))
            .toList();
      });
    } catch (e) {
      debugPrint("❌ Yardımcı veri hatası: $e");
    }
  }

  Widget _numaraRozeti(int? n, {Color renk = Colors.pink, double? font}) {
    if (n == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: renk.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: renk.withValues(alpha: 0.25),
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

  // ✅ form inputları için ortak gece decoration
  InputDecoration _formDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFF0B1220),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
      ),
    );
  }

  void _oyunFormuGoster({Oyun? oyun, List<Oyuncu>? guncelOyuncuListesi}) {
    if (guncelOyuncuListesi != null) _tumOyuncular = guncelOyuncuListesi;

    if (oyun != null) {
      _tarihController.text = oyun.oyunTarih;
      _elSayisiController.text = oyun.elSayisi.toString();
      _oyuncuSayisiController.text = oyun.oyuncuSayisi.toString();
      _oyuncuListesiController.text = oyun.oyuncu;
      _kazananController.text = oyun.oyunKazanan ?? '';
      _kaybedenController.text = oyun.oyunKaybeden ?? '';
      _seciliTurId = oyun.turId;
      _esliMi = oyun.esliMi;
      _formdaSeciliOyuncular = oyun.oyuncu
          .split(', ')
          .where((o) => o.isNotEmpty)
          .toList();
    } else {
      _tarihController.text = DateTime.now().toString().substring(0, 10);
      _elSayisiController.text = "8";
      _oyuncuSayisiController.text = "4";
      _oyuncuListesiController.clear();
      _kazananController.clear();
      _kaybedenController.clear();
      _seciliTurId = _turnuvalar.isNotEmpty ? _turnuvalar.first.id : null;
      _formdaSeciliOyuncular = [];
      _isHighestWins = false;
      _esliMi = false;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget formIcerigiOlustur() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _seciliTurId,
                  hint: const Text(
                    'Turnuva seçin',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  dropdownColor: const Color(0xFF111A2B),
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 14,
                  ),
                  decoration: _formDeco('Bağlı Olduğu Turnuva'),
                  items: _turnuvalar
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t.id,
                          child: Text(t.turTarih),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      _seciliTurId = val;
                      if (oyun == null) {
                        _oyuncuListesiController.clear();
                        _formdaSeciliOyuncular = [];
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tarihController,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  decoration: _formDeco('Oyun Tarihi'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _elSayisiController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFE2E8F0)),
                        decoration: _formDeco('Hedef El Sayısı'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _oyuncuSayisiController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFE2E8F0)),
                        decoration: _formDeco('Oyuncu Sayısı'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    "Eşli Oyun",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  subtitle: const Text(
                    "Karşı karşıya oturanlar eş kabul edilir",
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  value: _esliMi,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFFF59E0B),
                  activeTrackColor: const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: 0.35),
                  onChanged: (bool value) {
                    setDialogState(() {
                      _esliMi = value;
                      if (_formdaSeciliOyuncular.length == 4) {
                        _formdaSeciliOyuncular = _esliMi
                            ? [
                                _formdaSeciliOyuncular[0],
                                _formdaSeciliOyuncular[2],
                                _formdaSeciliOyuncular[1],
                                _formdaSeciliOyuncular[3],
                              ]
                            : List.from(_formdaSeciliOyuncular);
                        _oyuncuListesiController.text = _formdaSeciliOyuncular
                            .join(', ');
                      }
                    });
                  },
                ),
                const Text(
                  "Oyuncu Seçimi:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                _tumOyuncular.isEmpty
                    ? const Text(
                        "Oyuncular tablonuz boş! Önce oyuncu eklemelisiniz.",
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 12,
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1E293B)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 6.0,
                          runSpacing: 4.0,
                          children: _tumOyuncular.map((oyuncu) {
                            final seciliMi = _formdaSeciliOyuncular.contains(
                              oyuncu.oyuncuAdSoyad,
                            );
                            return FilterChip(
                              label: Text(
                                oyuncu.oyuncuAdSoyad,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: seciliMi
                                      ? const Color(0xFF1A1206)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              selected: seciliMi,
                              selectedColor: const Color(0xFFF59E0B),
                              backgroundColor: const Color(0xFF0B1220),
                              checkmarkColor: const Color(0xFF1A1206),
                              side: const BorderSide(color: Color(0xFF1E293B)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (bool selected) {
                                final sinir =
                                    int.tryParse(
                                      _oyuncuSayisiController.text.trim(),
                                    ) ??
                                    4;
                                if (selected &&
                                    _formdaSeciliOyuncular.length >= sinir) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "En fazla $sinir oyuncu seçebilirsiniz!",
                                      ),
                                      backgroundColor: Colors.orange.shade800,
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  if (selected) {
                                    _formdaSeciliOyuncular.add(
                                      oyuncu.oyuncuAdSoyad,
                                    );
                                  } else {
                                    _formdaSeciliOyuncular.remove(
                                      oyuncu.oyuncuAdSoyad,
                                    );
                                  }
                                  _oyuncuListesiController.text =
                                      _formdaSeciliOyuncular.join(', ');
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                if (_formdaSeciliOyuncular.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "Masadaki Oturma Düzeni (Sıralama):",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFFCD34D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      border: Border.all(color: const Color(0xFF1E293B)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: List.generate(_formdaSeciliOyuncular.length, (
                        idx,
                      ) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            "${idx + 1}. Sıra: ${_formdaSeciliOyuncular[idx]}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (idx > 0)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    size: 18,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final t = _formdaSeciliOyuncular[idx];
                                      _formdaSeciliOyuncular[idx] =
                                          _formdaSeciliOyuncular[idx - 1];
                                      _formdaSeciliOyuncular[idx - 1] = t;
                                      _oyuncuListesiController.text =
                                          _formdaSeciliOyuncular.join(', ');
                                    });
                                  },
                                ),
                              if (idx < _formdaSeciliOyuncular.length - 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_downward,
                                    size: 18,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final t = _formdaSeciliOyuncular[idx];
                                      _formdaSeciliOyuncular[idx] =
                                          _formdaSeciliOyuncular[idx + 1];
                                      _formdaSeciliOyuncular[idx + 1] = t;
                                      _oyuncuListesiController.text =
                                          _formdaSeciliOyuncular.join(', ');
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _oyuncuListesiController,
                  readOnly: true,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                  decoration: _formDeco('Veritabanına Kaydedilecek Sıra'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    "En Yüksek Alan Kazanır",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  subtitle: Text(
                    _isHighestWins
                        ? "En yüksek skor birinci olur"
                        : "En düşük skor birinci olur",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  value: _isHighestWins,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFFF59E0B),
                  activeTrackColor: const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: 0.35),
                  onChanged: (bool value) =>
                      setDialogState(() => _isHighestWins = value),
                ),
              ],
            );
          }

          Future<void> oyunKaydetmeMotoru() async {
            if (_seciliTurId == null ||
                _oyuncuListesiController.text.trim().isEmpty) {
              return;
            }

            final navigator = Navigator.of(dialogContext);
            final elSayisi = int.tryParse(_elSayisiController.text.trim()) ?? 8;
            final oyuncuSayisi = _formdaSeciliOyuncular.length;

            final data = <String, dynamic>{
              'turId': _seciliTurId!,
              'oyunTarih': _tarihController.text.trim(),
              'elSayisi': elSayisi,
              'oyuncuSayisi': oyuncuSayisi,
              'oyuncu': _oyuncuListesiController.text.trim(),
              'oyunKazanan': _kazananController.text.trim().isEmpty
                  ? null
                  : _kazananController.text.trim(),
              'oyunKaybeden': _kaybedenController.text.trim().isEmpty
                  ? null
                  : _kaybedenController.text.trim(),
              'esliMi': _esliMi ? 1 : 0,
            };

            if (oyun == null) {
              data['numara'] = await _firestoreService.nextNumber('oyunlar');
              await _firestoreService.setDocument(
                'oyunlar',
                FirebaseFirestore.instance.collection('oyunlar').doc().id,
                data,
              );
            } else {
              await _firestoreService.updateDocument('oyunlar', oyun.id, data);
            }

            if (!dialogContext.mounted) return;
            navigator.pop();
          }

          return Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: const Color(0xFF0A0F1C),
              appBar: AppBar(
                title: Text(
                  oyun == null ? 'Yeni Oyun Başlat' : 'Oyunu Düzenle',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: const Color(0xFF0B1220),
                foregroundColor: const Color(0xFFF8FAFC),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                actions: [
                  TextButton(
                    onPressed: oyunKaydetmeMotoru,
                    child: const Text(
                      'BAŞLAT',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: formIcerigiOlustur(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _heroAksiyonButonu({
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
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _oyunuSonlandir(Oyun oyun) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );

      final ellerSnap = await _firestoreService.getCollection('eller');
      final oyunElleri = ellerSnap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['oyunId'] == oyun.id)
          .toList();

      final puan = <String, int>{};
      for (final o in oyun.oyuncu.split(', ')) {
        if (o.trim().isNotEmpty) puan[o.trim()] = 0;
      }

      for (final d in oyunElleri) {
        final data = d.data() as Map<String, dynamic>;
        final skorlar = data['skorlar'];
        final gmap = data['gostergeler'];
        final gtek = data['gosterge'];
        if (skorlar is Map) {
          skorlar.forEach((k, v) {
            final o = k.toString();
            final s = (v is num)
                ? v.toInt()
                : (int.tryParse(v.toString()) ?? 0);
            int g = 0;
            if (gmap is Map && gmap[k] != null) {
              final gv = gmap[k];
              g = (gv is num) ? gv.toInt() : (int.tryParse(gv.toString()) ?? 0);
            } else if (gtek is num) {
              g = gtek.toInt();
            }
            puan[o] = (puan[o] ?? 0) + s + g;
          });
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (oyunElleri.isEmpty || puan.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu oyunda henüz kayıtlı el yok — sonlandırılamaz.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final high = oyun.esliMi;
      final sirali = puan.entries.toList()
        ..sort(
          high
              ? (a, b) => b.value.compareTo(a.value)
              : (a, b) => a.value.compareTo(b.value),
        );
      final kazanan = sirali.first.key;
      final kaybeden = sirali.last.key;

      final onay = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: const Color(0xFF111A2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: Color(0xFFFCD34D), size: 26),
              SizedBox(width: 8),
              Text(
                'Oyunu Sonlandır',
                style: TextStyle(color: Color(0xFFF8FAFC)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  high ? '(En yüksek skor kazanır)' : '(En düşük skor kazanır)',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                ...sirali.take(4).map((p) {
                  final isK = p.key == kazanan;
                  final isS = p.key == kaybeden;
                  final emoji = isK ? '🏆' : (isS ? '📉' : '·');
                  final renk = isK
                      ? const Color(0xFF4ADE80)
                      : (isS
                            ? const Color(0xFFF87171)
                            : const Color(0xFFE2E8F0));
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            p.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFFE2E8F0),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${p.value}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: renk,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text(
                'İptal',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(d, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF1A1206),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Sonlandır',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

      if (onay != true || !mounted) return;

      await _firestoreService.updateDocument('oyunlar', oyun.id, {
        'oyunKazanan': kazanan,
        'oyunKaybeden': kaybeden,
        'oyunIkinci': sirali.length > 1 ? sirali[1].key : null,
        'oyunUcuncu': sirali.length > 2 ? sirali[2].key : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏆 Oyun sonlandı — Şampiyon: $kazanan'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, st) {
      debugPrint('❌ oyun sonlandırma hatası: $e\n$st');
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sonlandırma hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    final oyunlarListesi = _tumOyunlar
        .where(
          (o) => _gosterArsiv ? o.oyunKazanan != null : o.oyunKazanan == null,
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuçlanan Oyunlar (Arşiv)' : 'Aktif Oyunlar',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: const Color(0xFFF8FAFC),
      ),
      body: Column(
        children: [
          Expanded(
            child: oyunlarListesi.isEmpty
                ? Center(
                    child: Text(
                      _gosterArsiv
                          ? 'Arşivde hiç oyun bulunmuyor.'
                          : 'Aktif (devam eden) oyun bulunmuyor.',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : _gosterArsiv
                ? _arsivListeGorunumu(oyunlarListesi)
                : _aktifHeroGorunumu(oyunlarListesi.first),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 90.0,
              top: 12.0,
              bottom: 80.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _gosterArsiv = !_gosterArsiv),
                icon: Icon(
                  _gosterArsiv ? Icons.play_circle_outline : Icons.history,
                  color: const Color(0xFFE2E8F0),
                ),
                label: Text(
                  _gosterArsiv ? "Aktif Oyunlara Dön" : "Eski Oyunlar (Arşiv)",
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF334155), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () async {
            if (!mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            if (_turnuvalar.isEmpty) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    "Oyun başlatabilmek için önce aktif bir turnuva oluşturmalısınız!",
                  ),
                ),
              );
              return;
            }
            final aktifOyunVar = _tumOyunlar.any((o) => o.oyunKazanan == null);
            if (!mounted) return;
            if (aktifOyunVar) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    "⚠️ Masada şu an devam eden AKTİF BİR OYUN bulunuyor!",
                  ),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }
            final guncelOyuncular = (await _firestoreService.getCollection(
              'oyuncular',
            )).docs.map((d) => Oyuncu.fromFirestore(d)).toList();
            if (!mounted) return;
            _oyunFormuGoster(guncelOyuncuListesi: guncelOyuncular);
          },
          backgroundColor: const Color(0xFFF59E0B),
          child: const Icon(Icons.add, color: Color(0xFF1A1206)),
        ),
      ),
    );
  }

  Widget _arsivListeGorunumu(List<Oyun> oyunlar) {
    return ListView.builder(
      itemCount: oyunlar.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (itemContext, index) {
        final oyun = oyunlar[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFF111A2B),
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EllerSayfasi(oyunId: oyun.id, isHighestWins: oyun.esliMi),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF334155),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  _numaraRozeti(
                                    oyun.numara,
                                    renk: const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      oyun.oyunTarih,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFFF8FAFC),
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Transform.rotate(
                                    angle: -0.12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(
                                            0xFF64748B,
                                          ).withValues(alpha: 0.55),
                                          width: 1.4,
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        'ARŞİV',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "👥 ${oyun.oyuncu}",
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    '🏆 ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  Expanded(
                                    child: Text(
                                      oyun.oyunKazanan ?? '—',
                                      style: const TextStyle(
                                        color: Color(0xFFFCD34D),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Text(
                                    '📉 ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  Flexible(
                                    child: Text(
                                      oyun.oyunKaybeden ?? '—',
                                      style: const TextStyle(
                                        color: Color(0xFFF87171),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              if (!context.mounted) return;
                              String paylasimMetni =
                                  "✍️ YAZ BOZ MAÇ SONUCU \n📅 Tarih: ${oyun.oyunTarih}\n👥 Oyuncular: ${oyun.oyuncu}\n-----------------------------------\n🏆 KAZANAN LİDER: ${oyun.oyunKazanan}\n📉 CEZA GÜZELİ: ${oyun.oyunKaybeden}\n\nGüzel maçtı, elinize sağlık! 🎉";
                              final Uri whatsappUrl = Uri.parse(
                                "whatsapp://send?text=${Uri.encodeComponent(paylasimMetni)}",
                              );
                              if (await canLaunchUrl(whatsappUrl)) {
                                await launchUrl(
                                  whatsappUrl,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                await launchUrl(
                                  Uri.parse(
                                    "https://wa.me/?text=${Uri.encodeComponent(paylasimMetni)}",
                                  ),
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFA78BFA,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFFA78BFA,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.share_outlined,
                                color: Color(0xFFA78BFA),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _silDugmesi(
                        onTap: () async {
                          final onay = await showDialog<bool>(
                            context: itemContext,
                            builder: (d) => AlertDialog(
                              backgroundColor: const Color(0xFF111A2B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: const Text(
                                'Oyunu Sil',
                                style: TextStyle(color: Color(0xFFF8FAFC)),
                              ),
                              content: const Text(
                                'Bu oyunu sildiğinizde oyuna ait girilmiş TÜM eller de silinecektir. Onaylıyor musunuz?',
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
                                    'Sil',
                                    style: TextStyle(color: Color(0xFFFCD34D)),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (onay == true && mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            );
                            try {
                              final tumEller = await _firestoreService
                                  .getCollection('eller');
                              final silinecekEller = tumEller.docs
                                  .where(
                                    (d) =>
                                        (d.data()
                                            as Map<
                                              String,
                                              dynamic
                                            >)['oyunId'] ==
                                        oyun.id,
                                  )
                                  .map((d) => d.id)
                                  .toList();
                              for (var elId in silinecekEller) {
                                await _firestoreService.deleteDocument(
                                  'eller',
                                  elId,
                                );
                              }
                              await _firestoreService.deleteDocument(
                                'oyunlar',
                                oyun.id,
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Oyun ve altındaki el skorları silindi.",
                                  ),
                                ),
                              );
                            } catch (e) {
                              debugPrint("Silme hatası: $e");
                              if (!mounted) return;
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Silme sırasında hata oluştu: $e",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _silDugmesi({required VoidCallback onTap}) {
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
              color: Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.amber.shade800,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _aktifHeroGorunumu(Oyun oyun) {
    final double ekranYuksekligi = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EllerSayfasi(oyunId: oyun.id, isHighestWins: oyun.esliMi),
          ),
        ),
        child: Container(
          height: ekranYuksekligi * 0.55,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2740), Color(0xFF0E1626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _numaraRozeti(
                            oyun.numara,
                            renk: const Color(0xFFFCD34D),
                            font: 15,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Masa: ${oyun.oyunTarih}",
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.style,
                        color: Color(0xFFFCD34D),
                        size: 30,
                      ),
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_filled,
                      color: Color(0xFF4ADE80),
                      size: 54,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "YAZ BOZ DEFTERİ AÇIK",
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Kadro: ${oyun.oyuncu}\nFormat: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _heroAksiyonButonu(
                        icon: Icons.share,
                        renk: const Color(0xFF38BDF8),
                        etiket: "Paylaş",
                        onTap: () async {
                          if (!context.mounted) return;
                          String paylasimMetni =
                              "✍️ YAZ BOZ MAÇI DEVAM EDİYOR \n📅 Tarih: ${oyun.oyunTarih}\n👥 Masadakiler: ${oyun.oyuncu}\n🎮 Format: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu\n-----------------------------------\nMaç henüz sonlanmadı, defterde heyecan dorukta! 🚀";
                          final Uri whatsappUrl = Uri.parse(
                            "https://wa.me/?text=${Uri.encodeComponent(paylasimMetni)}",
                          );
                          try {
                            if (await canLaunchUrl(whatsappUrl)) {
                              await launchUrl(
                                whatsappUrl,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "WhatsApp açılırken bir sorun oluştu: $e",
                                  ),
                                  backgroundColor: Colors.orange.shade800,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      _heroAksiyonButonu(
                        icon: Icons.edit,
                        renk: const Color(0xFFE2E8F0),
                        etiket: "Düzenle",
                        onTap: () async {
                          if (!mounted) return;
                          final guncelOyuncular =
                              (await _firestoreService.getCollection(
                                    'oyuncular',
                                  )).docs
                                  .map((d) => Oyuncu.fromFirestore(d))
                                  .toList();
                          if (!mounted) return;
                          _oyunFormuGoster(
                            oyun: oyun,
                            guncelOyuncuListesi: guncelOyuncular,
                          );
                        },
                      ),
                      _heroAksiyonButonu(
                        icon: Icons.flag,
                        renk: const Color(0xFF4ADE80),
                        etiket: "Sonlandır",
                        onTap: () async => _oyunuSonlandir(oyun),
                      ),
                      _heroAksiyonButonu(
                        icon: Icons.delete,
                        renk: Colors.amber.shade700,
                        etiket: "Sil",
                        onTap: () async {
                          bool? onay = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              backgroundColor: const Color(0xFF111A2B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: const Text(
                                'Oyunu Sil',
                                style: TextStyle(color: Color(0xFFF8FAFC)),
                              ),
                              content: const Text(
                                'Bu oyunu sildiğinizde girilmiş TÜM skor tablosu yok olacaktır. Onaylıyor musunuz?',
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
                                    'Sil',
                                    style: TextStyle(color: Color(0xFFF87171)),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (onay == true && mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            );
                            try {
                              final tumEller = await _firestoreService
                                  .getCollection('eller');
                              final silinecekEller = tumEller.docs
                                  .where(
                                    (d) =>
                                        (d.data()
                                            as Map<
                                              String,
                                              dynamic
                                            >)['oyunId'] ==
                                        oyun.id,
                                  )
                                  .map((d) => d.id)
                                  .toList();
                              for (var elId in silinecekEller) {
                                await _firestoreService.deleteDocument(
                                  'eller',
                                  elId,
                                );
                              }
                              await _firestoreService.deleteDocument(
                                'oyunlar',
                                oyun.id,
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Oyun ve altındaki el skorları silindi.",
                                  ),
                                ),
                              );
                            } catch (e) {
                              debugPrint("Silme hatası: $e");
                              if (!mounted) return;
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Silme sırasında hata oluştu: $e",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tarihController.dispose();
    _elSayisiController.dispose();
    _oyuncuSayisiController.dispose();
    _oyuncuListesiController.dispose();
    _kazananController.dispose();
    _kaybedenController.dispose();
    super.dispose();
  }
}
