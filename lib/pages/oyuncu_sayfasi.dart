import 'package:flutter/material.dart';
import 'package:yaz_boz/models/oyuncu_model.dart';
import 'package:yaz_boz/models/sehirler_model.dart';

class OyuncuSayfasi extends StatefulWidget {
  const OyuncuSayfasi({super.key});

  @override
  State<OyuncuSayfasi> createState() => _OyuncuSayfasiState();
}

class _OyuncuSayfasiState extends State<OyuncuSayfasi> {
  final TextEditingController _adSoyadController = TextEditingController();
  late Future<List<Oyuncu>> _oyuncularFuture;
  List<Sehir> _sehirler = [];
  String? _seciliSehir;

  @override
  void initState() {
    super.initState();
    _verileriYenile();
    _sehirleriYukle();
  }

  // Oyuncu listesini yeniler
  void _verileriYenile() {
    setState(() {
      _oyuncularFuture = Oyuncu.getAll();
    });
  }

  // Şehirleri Dropdown için veritabanından çeker
  Future<void> _sehirleriYukle() async {
    try {
      final sehirlerListesi = await Sehir.getAll();
      if (mounted) {
        setState(() {
          _sehirler = sehirlerListesi;
        });
      }
    } catch (e) {
      debugPrint("Şehirler yüklenirken hata oluştu: $e");
    }
  }

  // Oyuncu Ekleme/Düzenleme Form Dialog Penceresi
  void _oyuncuFormuGoster({Oyuncu? oyuncu}) {
    if (oyuncu != null) {
      _adSoyadController.text = oyuncu.oyuncuAdSoyad;
      // Eğer oyuncunun şehri mevcut şehir listesinde varsa seç, yoksa null bırak
      final sehirMevcutMu = _sehirler.any(
        (s) => s.sehirAd == oyuncu.oyuncuSehir,
      );
      _seciliSehir = sehirMevcutMu ? oyuncu.oyuncuSehir : null;
    } else {
      _adSoyadController.clear();
      _seciliSehir = _sehirler.isNotEmpty ? _sehirler.first.sehirAd : null;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(oyuncu == null ? 'Yeni Oyuncu Ekle' : 'Oyuncuyu Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _adSoyadController,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _seciliSehir,
                  decoration: const InputDecoration(
                    labelText: 'Şehir',
                    border: OutlineInputBorder(),
                  ),
                  items: _sehirler.map((sehir) {
                    return DropdownMenuItem<String>(
                      value: sehir.sehirAd,
                      child: Text(sehir.sehirAd),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      _seciliSehir = val;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_adSoyadController.text.trim().isEmpty ||
                    _seciliSehir == null) {
                  return;
                }

                final navigator = Navigator.of(dialogContext);

                if (oyuncu == null) {
                  Oyuncu yeniOyuncu = Oyuncu(
                    oyuncuAdSoyad: _adSoyadController.text.trim(),
                    oyuncuSehir: _seciliSehir!,
                  );
                  await yeniOyuncu.save();
                } else {
                  Oyuncu guncelOyuncu = Oyuncu(
                    oyuncuId: oyuncu.oyuncuId,
                    oyuncuAdSoyad: _adSoyadController.text.trim(),
                    oyuncuSehir: _seciliSehir!,
                  );
                  await guncelOyuncu.update();
                }

                if (!dialogContext.mounted) return;
                navigator.pop();
                _verileriYenile();
              },
              child: Text(oyuncu == null ? 'Kaydet' : 'Güncelle'),
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
        title: const Text('Oyuncular Yönetimi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Oyuncu>>(
        future: _oyuncularFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Henüz hiç oyuncu eklenmemiş.\nSağ alttaki butondan ekleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final oyuncular = snapshot.data!;

          return ListView.builder(
            itemCount: oyuncular.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (itemContext, index) {
              final oyuncu = oyuncular[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    oyuncu.oyuncuAdSoyad,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('📍 Şehir: ${oyuncu.oyuncuSehir}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _oyuncuFormuGoster(oyuncu: oyuncu),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          bool? onay = await showDialog<bool>(
                            context: itemContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Oyuncuyu Sil'),
                              content: Text(
                                '${oyuncu.oyuncuAdSoyad} isimli oyuncuyu silmek istediğinize emin misiniz?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('İptal'),
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
                            await Oyuncu.delete(oyuncu.oyuncuId!);
                            if (!mounted) return;
                            _verileriYenile();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_sehirler.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Oyuncu ekleyebilmek için önce 'Şehirler' sayfasından en az bir şehir eklemelisiniz!",
                ),
              ),
            );
            return;
          }
          _oyuncuFormuGoster();
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _adSoyadController.dispose();
    super.dispose();
  }
}
