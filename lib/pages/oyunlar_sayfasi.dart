import 'package:flutter/material.dart';
import 'package:yaz_boz/models/oyunlar_model.dart';
import 'package:yaz_boz/models/turnuva_model.dart';
import 'package:yaz_boz/models/oyuncu_model.dart';
import 'eller_sayfasi.dart';

class OyunlarSayfasi extends StatefulWidget {
  const OyunlarSayfasi({super.key});

  @override
  State<OyunlarSayfasi> createState() => _OyunlarSayfasiState();
}

class _OyunlarSayfasiState extends State<OyunlarSayfasi> {
  final TextEditingController _tarihController = TextEditingController();
  final TextEditingController _elSayisiController = TextEditingController();
  final TextEditingController _oyuncuSayisiController = TextEditingController();
  final TextEditingController _oyuncuListesiController =
      TextEditingController();
  final TextEditingController _kazananController = TextEditingController();
  final TextEditingController _kaybedenController = TextEditingController();

  late Future<List<Oyun>> _oyunlarFuture;
  List<Turnuva> _turnuvalar = [];
  List<Oyuncu> _tumOyuncular = [];
  List<String> _formdaSeciliOyuncular = [];

  int? _seciliTurId;
  bool _isHighestWins = false;
  bool _gosterArsiv = false;

  @override
  void initState() {
    super.initState();
    _verileriYenile();
    _turnuvalariYukle();
  }

  void _verileriYenile() {
    setState(() {
      _oyunlarFuture = Oyun.getAll();
    });
  }

  Future<void> _turnuvalariYukle() async {
    try {
      final turnuvaListesi = await Turnuva.getAll();
      final oyuncuListesi = await Oyuncu.getAll();
      if (mounted) {
        setState(() {
          _turnuvalar = turnuvaListesi;
          _tumOyuncular = oyuncuListesi;
        });
      }
    } catch (e) {
      debugPrint("Veriler yuklenirken hata olustu: $e");
    }
  }

  void _oyunFormuGoster({Oyun? oyun, List<Oyuncu>? guncelOyuncuListesi}) {
    if (guncelOyuncuListesi != null) {
      _tumOyuncular = guncelOyuncuListesi;
    }

    if (oyun != null) {
      _tarihController.text = oyun.oyunTarih;
      _elSayisiController.text = oyun.elSayisi.toString();
      _oyuncuSayisiController.text = oyun.oyuncuSayisi.toString();
      _oyuncuListesiController.text = oyun.oyuncu;
      _kazananController.text = oyun.oyunKazanan ?? '';
      _kaybedenController.text = oyun.oyunKaybeden ?? '';
      _seciliTurId = oyun.turId;
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
      _seciliTurId = _turnuvalar.isNotEmpty ? _turnuvalar.first.turId : null;
      _formdaSeciliOyuncular = [];
      _isHighestWins = false;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(oyun == null ? 'Yeni Oyun Başlat' : 'Oyunu Düzenle'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _seciliTurId,
                    decoration: const InputDecoration(
                      labelText: 'Bagli Oldugu Turnuva',
                      border: OutlineInputBorder(),
                    ),
                    items: _turnuvalar.map((t) {
                      return DropdownMenuItem<int>(
                        value: t.turId,
                        child: Text("Turnuva #${t.turId} (${t.turTarih})"),
                      );
                    }).toList(),
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
                    decoration: const InputDecoration(
                      labelText: 'Oyun Tarihi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _elSayisiController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Hedef El Sayisi',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _oyuncuSayisiController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Oyuncu Sayisi',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Oyuncu Secimi:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _tumOyuncular.isEmpty
                      ? const Text(
                          "Oyuncular tablonuz bos! Once oyuncu eklemelisiniz.",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        )
                      : Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Wrap(
                            spacing: 6.0,
                            runSpacing: 2.0,
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
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                selected: seciliMi,
                                selectedColor: Colors.blue.shade700,
                                checkmarkColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onSelected: (bool selected) {
                                  final maksimumOyuncuSiniri =
                                      int.tryParse(
                                        _oyuncuSayisiController.text.trim(),
                                      ) ??
                                      4;
                                  if (selected &&
                                      _formdaSeciliOyuncular.length >=
                                          maksimumOyuncuSiniri) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "En fazla $maksimumOyuncuSiniri oyuncu secebilirsiniz!",
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

                  // 🚀 YENİ MASADAKİ OTURMA DÜZENİ SIRALAMA ALANI
                  if (_formdaSeciliOyuncular.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Masadaki Oturma Düzeni (Sıralama):",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
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
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Yukari Tasi Butonu
                                if (idx > 0)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_upward,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        final temp =
                                            _formdaSeciliOyuncular[idx];
                                        _formdaSeciliOyuncular[idx] =
                                            _formdaSeciliOyuncular[idx - 1];
                                        _formdaSeciliOyuncular[idx - 1] = temp;
                                        _oyuncuListesiController.text =
                                            _formdaSeciliOyuncular.join(', ');
                                      });
                                    },
                                  ),
                                // Asagi Tasi Butonu
                                if (idx < _formdaSeciliOyuncular.length - 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_downward,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        final temp =
                                            _formdaSeciliOyuncular[idx];
                                        _formdaSeciliOyuncular[idx] =
                                            _formdaSeciliOyuncular[idx + 1];
                                        _formdaSeciliOyuncular[idx + 1] = temp;
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
                    decoration: const InputDecoration(
                      labelText: 'Veritabanina Kaydedilecek Sira',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text(
                      "En Yuksek Alan Kazanir",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _isHighestWins
                          ? "En yüksek skor birinci olur"
                          : "En düşük skor birinci olur",
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isHighestWins,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool value) {
                      setDialogState(() {
                        _isHighestWins = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_seciliTurId == null ||
                    _oyuncuListesiController.text.trim().isEmpty) {
                  return;
                }

                final navigator = Navigator.of(dialogContext);
                final elSayisi =
                    int.tryParse(_elSayisiController.text.trim()) ?? 8;
                final oyuncuSayisi = _formdaSeciliOyuncular.length;

                if (oyun == null) {
                  Oyun yeniOyun = Oyun(
                    turId: _seciliTurId!,
                    oyunTarih: _tarihController.text.trim(),
                    elSayisi: elSayisi,
                    oyuncuSayisi: oyuncuSayisi,
                    oyuncu: _oyuncuListesiController.text
                        .trim(), // 🚀 Düzenlenmiş masadaki oturma sırasıyla kaydeder
                    oyunKazanan: null,
                    oyunKaybeden: null,
                  );
                  await yeniOyun.save();
                } else {
                  Oyun guncelOyun = Oyun(
                    oyunId: oyun.oyunId,
                    turId: _seciliTurId!,
                    oyunTarih: _tarihController.text.trim(),
                    elSayisi: elSayisi,
                    oyuncuSayisi: oyuncuSayisi,
                    oyuncu: _oyuncuListesiController.text.trim(),
                    oyunKazanan: _kazananController.text.trim().isEmpty
                        ? null
                        : _kazananController.text.trim(),
                    oyunKaybeden: _kaybedenController.text.trim().isEmpty
                        ? null
                        : _kaybedenController.text.trim(),
                  );
                  await guncelOyun.update();
                }

                if (!dialogContext.mounted) return;
                navigator.pop();
                _verileriYenile();
              },
              child: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuclanan Oyunlar (Arsiv)' : 'Aktif Oyunlar',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Oyun>>(
              future: _oyunlarFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz oyun başlatılmamış.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final tumOyunlar = snapshot.data!;
                final oyunlar = tumOyunlar.where((o) {
                  return _gosterArsiv
                      ? o.oyunKazanan != null
                      : o.oyunKazanan == null;
                }).toList();

                if (oyunlar.isEmpty) {
                  return Center(
                    child: Text(
                      _gosterArsiv
                          ? 'Arşivde hiç oyun bulunmuyor.'
                          : 'Aktif (devam eden) oyun bulunmuyor.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: oyunlar.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (itemContext, index) {
                    final oyun = oyunlar[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          Icons.sports_esports,
                          color: _gosterArsiv ? Colors.blueGrey : Colors.purple,
                          size: 32,
                        ),
                        title: Text(
                          "Oyun #${oyun.oyunId} - Tar: ${oyun.oyunTarih}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Sıralı Oyuncular: ${oyun.oyuncu}",
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "Durum: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu",
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                              if (oyun.oyunKazanan != null)
                                Text(
                                  "Kazanan: ${oyun.oyunKazanan}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (oyun.oyunKaybeden != null)
                                Text(
                                  "Kaybeden: ${oyun.oyunKaybeden}",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () async {
                                final guncelOyuncular = await Oyuncu.getAll();
                                _oyunFormuGoster(
                                  oyun: oyun,
                                  guncelOyuncuListesi: guncelOyuncular,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                bool? onay = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Oyunu Sil'),
                                    content: const Text(
                                      'Bu oyunu sildiğinizde oyuna ait girilmiş tüm eller de silinecektir. Onaylıyor musunuz?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Iptal'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text(
                                          'Sil',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (onay == true) {
                                  await Oyun.delete(oyun.oyunId!);
                                  _verileriYenile();
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EllerSayfasi(
                                oyunId: oyun.oyunId!,
                                isHighestWins: _isHighestWins,
                              ),
                            ),
                          ).then((_) => _verileriYenile());
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 🚀 ALT KISMA GEÇMİŞ/ARŞİV BUTONU ENTEGRASYONU (Yeni oyun aç kaldırıldı)
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 90.0,
              top: 12.0,
              bottom: 16.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _gosterArsiv = !_gosterArsiv;
                  });
                },
                icon: Icon(
                  _gosterArsiv ? Icons.play_circle_outline : Icons.history,
                  color: Colors.black87,
                ),
                label: Text(
                  _gosterArsiv ? "Aktif Oyunlara Dön" : "Eski Oyunlar (Arşiv)",
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.black, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_turnuvalar.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Oyun başlatabilmek icin önce bir turnuva oluşturmalısınız!",
                ),
              ),
            );
            return;
          }
          final guncelOyuncular = await Oyuncu.getAll();
          _oyunFormuGoster(guncelOyuncuListesi: guncelOyuncular);
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
