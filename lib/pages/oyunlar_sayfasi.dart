import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/models/oyunlar_model.dart';
import 'package:yaz_boz/models/turnuva_model.dart';
import 'package:yaz_boz/models/oyuncu_model.dart';
import 'package:yaz_boz/helper/database_helper.dart';
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
      final tumTurnuvalar = await Turnuva.getAll();
      final aktifTurnuvalar = tumTurnuvalar
          .where((t) => t.turKazanan == null)
          .toList();
      final oyuncuListesi = await Oyuncu.getAll();
      if (mounted) {
        setState(() {
          _turnuvalar = aktifTurnuvalar;
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
        builder: (context, setDialogState) {
          Widget formIcerigiOlustur() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _seciliTurId,
                  decoration: const InputDecoration(
                    labelText: 'Bağlı Olduğu Turnuva',
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
                          labelText: 'Hedef El Sayısı',
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
                          labelText: 'Oyuncu Sayısı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Oyuncu Seçimi:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 6),
                _tumOyuncular.isEmpty
                    ? const Text(
                        "Oyuncular tablonuz boş! Önce oyuncu eklemelisiniz.",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
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
                                        "En fazla $maksimumOyuncuSiniri oyuncu seçebilirsiniz!",
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
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (idx > 0)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final temp = _formdaSeciliOyuncular[idx];
                                      _formdaSeciliOyuncular[idx] =
                                          _formdaSeciliOyuncular[idx - 1];
                                      _formdaSeciliOyuncular[idx - 1] = temp;
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
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final temp = _formdaSeciliOyuncular[idx];
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
                    labelText: 'Veritabanına Kaydedilecek Sıra',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    "En Yüksek Alan Kazanır",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
            if (oyun == null) {
              Oyun yeniOyun = Oyun(
                turId: _seciliTurId!,
                oyunTarih: _tarihController.text.trim(),
                elSayisi: elSayisi,
                oyuncuSayisi: oyuncuSayisi,
                oyuncu: _oyuncuListesiController.text.trim(),
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
          }

          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  oyun == null ? 'Yeni Oyun Başlat' : 'Oyunu Düzenle',
                ),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
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
                        color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _gosterArsiv ? 'Sonuçlanan Oyunlar (Arşiv)' : 'Aktif Oyunlar',
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
                      'Henüz hiç oyun başlatılmamış.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final tumOyunlar = snapshot.data!;
                final oyunlarListesi = tumOyunlar.where((o) {
                  return _gosterArsiv
                      ? o.oyunKazanan != null
                      : o.oyunKazanan == null;
                }).toList();

                if (oyunlarListesi.isEmpty) {
                  return Center(
                    child: Text(
                      _gosterArsiv
                          ? 'Arşivde hiç oyun bulunmuyor.'
                          : 'Aktif (devam eden) oyun bulunmuyor.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // 📊 1. GÖRÜNÜM: ESKİ OYUNLAR (ARŞİV) MODUNDA LİSTE HALİNDE GÖSTERİLİR
                if (_gosterArsiv) {
                  return ListView.builder(
                    itemCount: oyunlarListesi.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (itemContext, index) {
                      final oyun = oyunlarListesi[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(
                            Icons.sports_esports,
                            color: Colors.blueGrey,
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
                                  "Oyuncular: ${oyun.oyuncu}",
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "🏆 Kazanan: ${oyun.oyunKazanan} | 📉 Kaybeden: ${oyun.oyunKaybeden}",
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
                                  Icons.share,
                                  color: Colors.purple,
                                ),
                                onPressed: () async {
                                  String paylasimMetni =
                                      "🎮 YAZ BOZ MAÇ SONUCU 🎮\n"
                                      "📅 Tarih: ${oyun.oyunTarih}\n"
                                      "🆔 Oyun No: #${oyun.oyunId}\n"
                                      "👥 Oyuncular: ${oyun.oyuncu}\n"
                                      "-----------------------------------\n"
                                      "🏆 KAZANAN LİDER: ${oyun.oyunKazanan}\n"
                                      "📉 CEZA GÜZELİ: ${oyun.oyunKaybeden}\n\n"
                                      "Güzel maçtı, elinize sağlık! 🃏";

                                  final Uri whatsappUrl = Uri.parse(
                                    "whatsapp://send?text=${Uri.encodeComponent(paylasimMetni)}",
                                  );
                                  if (await canLaunchUrl(whatsappUrl)) {
                                    await launchUrl(
                                      whatsappUrl,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else {
                                    final Uri webUrl = Uri.parse(
                                      "https://wa.me/?text=${Uri.encodeComponent(paylasimMetni)}",
                                    );
                                    await launchUrl(
                                      webUrl,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
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
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: const Text('İptal'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
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
                }

                // 🚀 2. GÖRÜNÜM: AKTİF OYUN MODUNDA EKRANIN DEVASAL 2/3 ALANINI KAPLAYAN HERO KART TASARIMI
                final oyun =
                    oyunlarListesi.first; // Eş zamanlı tek aktif oyun gelebilir
                final double ekranYuksekligi = MediaQuery.of(
                  context,
                ).size.height;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
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
                        child: Container(
                          height: ekranYuksekligi * 0.55,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade600,
                                Colors.pink.shade900,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Üst Başlık ve İkon Alanı
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Oyun #${oyun.oyunId}",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Masa: ${oyun.oyunTarih}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.white24,
                                      child: Icon(
                                        Icons.style,
                                        color: Colors.white,
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
                                      color: Colors.greenAccent,
                                      size: 54,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "YAZ BOZ DEFTERİ AÇIK",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
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
                                        color: Colors.white70,
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
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _heroAksiyonButonu(
                                        icon: Icons.share,
                                        renk: Colors.cyanAccent,
                                        etiket: "Paylaş",
                                        onTap: () async {
                                          String paylasimMetni =
                                              "🎮 YAZ BOZ MAÇI DEVAM EDİYOR 🎮\n"
                                              "📅 Tarih: ${oyun.oyunTarih}\n"
                                              "🆔 Oyun No: #${oyun.oyunId}\n"
                                              "👥 Masadakiler: ${oyun.oyuncu}\n"
                                              "📊 Format: ${oyun.elSayisi} El / ${oyun.oyuncuSayisi} Oyuncu\n"
                                              "-----------------------------------\n"
                                              "Maç henüz sonlanmadı, defterde heyecan dorukta! 🚀";

                                          final Uri whatsappUrl = Uri.parse(
                                            "https://wa.me/?text=${Uri.encodeComponent(paylasimMetni)}",
                                          );

                                          try {
                                            if (await canLaunchUrl(
                                              whatsappUrl,
                                            )) {
                                              await launchUrl(
                                                whatsappUrl,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            } else {
                                              await launchUrl(
                                                whatsappUrl,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "⚠️ WhatsApp açılırken bir sorun oluştu veya cihazda yüklü değil: $e",
                                                ),
                                                backgroundColor:
                                                    Colors.orange.shade800,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      _heroAksiyonButonu(
                                        icon: Icons.edit,
                                        renk: Colors.white,
                                        etiket: "Düzenle",
                                        onTap: () async {
                                          final guncelOyuncular =
                                              await Oyuncu.getAll();
                                          _oyunFormuGoster(
                                            oyun: oyun,
                                            guncelOyuncuListesi:
                                                guncelOyuncular,
                                          );
                                        },
                                      ),
                                      _heroAksiyonButonu(
                                        icon: Icons.delete,
                                        renk: Colors.redAccent,
                                        etiket: "Sil",
                                        onTap: () async {
                                          bool? onay = await showDialog(
                                            context: context,
                                            builder: (dialogContext) => AlertDialog(
                                              title: const Text('Oyunu Sil'),
                                              content: const Text(
                                                'Bu oyunu sildiğinizde girilmiş tüm skor tablosu yok olacaktır. Onaylıyor musunuz?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                  child: const Text('İptal'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Sil',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 👇 DEĞİŞİKLİK 1: Alt butonun boşluğu 80.0 yapıldı
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 90.0,
              top: 12.0,
              bottom:
                  80.0, // Butonları yukarı almak için 16.0'dan 80.0'a çıkarıldı
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

      // 👇 DEĞİŞİKLİK 2: FloatingActionButton bir Padding içine alındı
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 80.0,
        ), // FAB'ı yukarı iten boşluk
        child: FloatingActionButton(
          onPressed: () async {
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

            final db = await DatabaseHelper().database;
            final List<Map<String, dynamic>> aktifOyunlar = await db.query(
              'oyunlar',
              where: 'oyunKazanan IS NULL',
            );

            if (!context.mounted) return;

            if (aktifOyunlar.isNotEmpty) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    "⚠️ Masada şu an devam eden AKTİF BİR OYUN (Yaz Boz Defteri) bulunuyor! Yeni bir oyun açabilmek için mevcut oyunu tablodan bitirmelisiniz.",
                  ),
                  backgroundColor: Colors.orangeAccent,
                  duration: Duration(seconds: 4),
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
