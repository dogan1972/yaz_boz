import 'package:flutter/material.dart';
import 'package:yaz_boz/models/sehirler_model.dart';


class SehirlerSayfasi extends StatefulWidget {
  const SehirlerSayfasi({super.key});

  @override
  State<SehirlerSayfasi> createState() => _SehirlerSayfasiState();
}

class _SehirlerSayfasiState extends State<SehirlerSayfasi> {
  final TextEditingController _sehirController = TextEditingController();
  late Future<List<Sehir>> _sehirlerFuture;

  @override
  void initState() {
    super.initState();
    _verileriYenile();
  }

  void _verileriYenile() {
    setState(() {
      _sehirlerFuture = Sehir.getAll();
    });
  }

  void _sehirFormuGoster({Sehir? sehir}) {
    if (sehir != null) {
      _sehirController.text = sehir.sehirAd;
    } else {
      _sehirController.clear();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(sehir == null ? 'Yeni Şehir Ekle' : 'Şehri Güncelle'),
        content: TextField(
          controller: _sehirController,
          decoration: const InputDecoration(
            labelText: 'Şehir Adı',
            hintText: 'Örn: İstanbul',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_sehirController.text.trim().isEmpty) return;

              // Asenkron işlem başlamadan önce Navigator referansını yakalıyoruz
              final navigator = Navigator.of(dialogContext);

              if (sehir == null) {
                Sehir yeniSehir = Sehir(sehirAd: _sehirController.text.trim());
                await yeniSehir.save();
              } else {
                Sehir guncelSehir = Sehir(
                  sehirId: sehir.sehirId,
                  sehirAd: _sehirController.text.trim(),
                );
                await guncelSehir.update();
              }

              // Dialog penceresini kapatmadan önce context'in hala geçerli olduğunu kontrol ediyoruz
              if (!dialogContext.mounted) return;
              navigator.pop();
              
              _verileriYenile();
            },
            child: Text(sehir == null ? 'Kaydet' : 'Güncelle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şehirler Yönetimi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Sehir>>(
        future: _sehirlerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata oluştu: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Henüz hiç şehir eklenmemiş.\nSağ alttaki butondan ekleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final sehirler = snapshot.data!;

          return ListView.builder(
            itemCount: sehirler.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (itemContext, index) {
              final sehir = sehirler[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.location_city, color: Colors.blue),
                  title: Text(
                    sehir.sehirAd,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _sehirFormuGoster(sehir: sehir),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          bool? onay = await showDialog<bool>(
                            context: itemContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Şehri Sil'),
                              content: Text('${sehir.sehirAd} şehrini silmek istediğinize emin misiniz?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Sil', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (onay == true) {
                            await Sehir.delete(sehir.sehirId!);
                            if (!mounted) return; // State'in hala hayatta olup olmadığını kontrol ediyoruz
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
        onPressed: () => _sehirFormuGoster(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _sehirController.dispose();
    super.dispose();
  }
}
