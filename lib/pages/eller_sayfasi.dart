import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz_boz/models/eller_model.dart';
import 'package:yaz_boz/models/oyunlar_model.dart';
import 'package:yaz_boz/helper/database_helper.dart';
import 'package:yaz_boz/pages/oyunlar_sayfasi.dart';

class EllerSayfasi extends StatefulWidget {
  final int oyunId;
  final bool isHighestWins; 

  const EllerSayfasi({
    super.key,
    required this.oyunId,
    required this.isHighestWins,
  });

  @override
  State<EllerSayfasi> createState() => _EllerSayfasiState();
}

class _EllerSayfasiState extends State<EllerSayfasi> {
  final TextEditingController _tarihController = TextEditingController();

  List<TextEditingController> _karControllers = [];
  List<TextEditingController> _zararControllers = [];
  List<TextEditingController> _gostergeControllers = [];
  List<String> _aktifOyuncular = [];

  late Future<List<El>> _ellerFuture;
  List<Oyun> _oyunlar = [];
  int? _seciliOyunId;
  late bool _isHighestWins;
  @override
  void initState() {
    super.initState();
    _isHighestWins = widget.isHighestWins; 
    _verileriYenile();
    _oyunlariYukle();
  }

  void _verileriYenile() {
    setState(() {
      _ellerFuture = El.oyunaGoreGetir(widget.oyunId);
    });
  }

  Future<void> _oyunlariYukle() async {
    try {
      final oyunlarListesi = await Oyun.getAll();
      if (mounted) {
        setState(() {
          _oyunlar = oyunlarListesi;
          if (_oyunlar.isNotEmpty) {
            _seciliOyunId = widget.oyunId;
            _oyuncuAlanlariniHazirla(_seciliOyunId);
          }
        });
      }
    } catch (e) {
      debugPrint("Oyunlar yuklenirken hata: $e");
    }
  }
  Future<void> _oyunKapatVeHesapla() async {
    if (_seciliOyunId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final oyunSonucu = await Oyun.oyunSonucunuHesapla(
      oyunId: _seciliOyunId!,
      isHighestWins: _isHighestWins,
      kaliciKapat: true,
    );

    if (!mounted) return;

    if (oyunSonucu['kazanan'] == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("⚠️ Bu oyuna ait henüz hiç el skoru girilmemiş!")),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Oyun Sonuçlandı!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🎮 Oyun ID: #$_seciliOyunId", style: const TextStyle(color: Colors.grey)),
            const Divider(),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                children: [
                  const TextSpan(text: "🏆 OYUN KAZANANI (Lider): \n"),
                  TextSpan(
                    text: "${oyunSonucu['kazanan']}\n\n",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                  ),
                  const TextSpan(text: "📉 OYUN KAYBEDENI (Sonuncu): \n"),
                  TextSpan(
                    text: "${oyunSonucu['kaybeden']}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _verileriYenile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _oyuncuAlanlariniHazirla(int? oyunId, {List<El>? mevcutEller}) {
    if (oyunId == null || _oyunlar.isEmpty) return;
    final seciliOyun = _oyunlar.firstWhere((o) => o.oyunId == oyunId);

    for (var c in _karControllers) { c.dispose(); }
    for (var c in _zararControllers) { c.dispose(); }
    for (var c in _gostergeControllers) { c.dispose(); }

    setState(() {
      _aktifOyuncular = seciliOyun.oyuncu.split(', ').where((o) => o.isNotEmpty).toList();

      _karControllers = List.generate(_aktifOyuncular.length, (index) => TextEditingController());
      _zararControllers = List.generate(_aktifOyuncular.length, (index) => TextEditingController());
      _gostergeControllers = List.generate(_aktifOyuncular.length, (index) => TextEditingController());

      if (mevcutEller != null) {
        for (int i = 0; i < _aktifOyuncular.length; i++) {
          final oyuncuAdi = _aktifOyuncular[i];
          final elKayit = mevcutEller.firstWhere(
            (e) => e.oyuncu1 == oyuncuAdi,
            orElse: () => El(oyunId: oyunId, elTarih: '', oyuncu1: '', oyuncu2: '', elSkor: 0),
          );
          if (elKayit.elTarih.isNotEmpty) {
            if (elKayit.elSkor < 0) {
              _karControllers[i].text = (elKayit.elSkor * -1).toString();
              _zararControllers[i].text = '0';
            } else {
              _karControllers[i].text = '0';
              _zararControllers[i].text = elKayit.elSkor.toString();
            }
            if (elKayit.gosterge != null) {
              _gostergeControllers[i].text = (elKayit.gosterge! * -1).toString();
            } else {
              _gostergeControllers[i].text = '0';
            }
          }
        }
      }
    });
  }
  void _elFormuGoster({String? guncellenecekTarih, List<El>? elGrubuElemanlari}) {
    final duzenlemeModu = guncellenecekTarih != null && elGrubuElemanlari != null;

    if (duzenlemeModu) {
      _tarihController.text = guncellenecekTarih;
      _seciliOyunId = widget.oyunId;
      _oyuncuAlanlariniHazirla(_seciliOyunId, mevcutEller: elGrubuElemanlari);
    } else {
      _tarihController.text = DateTime.now().toString().substring(0, 19);
      _seciliOyunId = widget.oyunId;
      _oyuncuAlanlariniHazirla(_seciliOyunId);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double ekranGenisligi = MediaQuery.of(context).size.width;
          final bool isYatay = MediaQuery.of(context).orientation == Orientation.landscape;

          List<Widget> dikeyUstElemanlar = [
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.blue, width: 1)),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.sports_esports, color: Colors.blue, size: 24),
                title: Text("Aktif Oyun: #${widget.oyunId}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tarihController,
              enabled: false,
              decoration: const InputDecoration(labelText: 'El Zaman Damgası', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text("Kar, Zarar ve Gösterge Dağılımı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            ),
            const Divider(),
          ];

          Widget yataySagPanelOlustur(VoidCallback onKaydet) {
            return SingleChildScrollView(
              key: const ValueKey('yatay_sag_panel_scroll'),
              child: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports_esports, color: Colors.blue, size: 18),
                          const SizedBox(height: 2),
                          Text(
                            "Oyun: #${widget.oyunId}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12),
                          ),
                          Text(
                            duzenlemeModu ? 'Düzenleme' : 'Yeni Kayıt',
                            style: TextStyle(color: Colors.blue.shade700, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Kar, Zarar ve\nGösterge Dağılımı",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey),
                    ),
                    const Divider(height: 12),
                    ElevatedButton.icon(
                      onPressed: onKaydet,
                      icon: const Icon(Icons.save, color: Colors.white, size: 16),
                      label: const Text("KAYDET", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          Widget oyuncuGirisKutusuOlustur(int index) {
            if (index >= _aktifOyuncular.length) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.all(3.0),
              child: Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _aktifOyuncular[index],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _karControllers[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Kar', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(8)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _zararControllers[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Zarar', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(8)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _gostergeControllers[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Gost.', hintText: '0', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          Future<void> kaydetmeIslemi() async {
            if (_seciliOyunId == null) return;

            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(dialogContext);

            final seciliOyun = _oyunlar.firstWhere((o) => o.oyunId == _seciliOyunId);
            final hedefElSayisi = seciliOyun.elSayisi;
            final oyundakiOyuncuSayisi = _aktifOyuncular.length;

            final db = await DatabaseHelper().database;
            final List<Map<String, dynamic>> satirSayisiRes = await db.rawQuery(
              'SELECT COUNT(*) as toplam FROM eller WHERE oyunId = ?', [_seciliOyunId],
            );
            
            final toplamSatirSayisi = satirSayisiRes.first['toplam'] as int;
            final mevcutElSayisi = toplamSatirSayisi ~/ oyundakiOyuncuSayisi;

            if (!duzenlemeModu && mevcutElSayisi >= hedefElSayisi) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text("⚠️ Maksimum el sayısına ($hedefElSayisi El) ulaştı!"), backgroundColor: Colors.redAccent)
              );
              return; 
            }

            if (duzenlemeModu) {
              Map<String, int> yeniSkorlar = {};
              for (int i = 0; i < _aktifOyuncular.length; i++) {
                final pKar = int.tryParse(_karControllers[i].text.trim()) ?? 0;
                final pZarar = int.tryParse(_zararControllers[i].text.trim()) ?? 0;
                yeniSkorlar[_aktifOyuncular[i]] = (pKar * -1) + pZarar;

                final hamGosterge = int.tryParse(_gostergeControllers[i].text.trim()) ?? 0;
                await db.update(
                  'eller', 
                  {'gosterge': hamGosterge * -1}, 
                  where: 'elTarih = ? AND Oyuncu1 = ?', 
                  whereArgs: [guncellenecekTarih, _aktifOyuncular[i]]
                );
              }
              await El.topluGuncelle(guncellenecekTarih, yeniSkorlar);
            } else {
              final ortakTarih = _tarihController.text.trim();
              for (int i = 0; i < _aktifOyuncular.length; i++) {
                final pKar = int.tryParse(_karControllers[i].text.trim()) ?? 0;
                final pZarar = int.tryParse(_zararControllers[i].text.trim()) ?? 0;
                final netSkor = (pKar * -1) + pZarar; 

                final hamGosterge = int.tryParse(_gostergeControllers[i].text.trim()) ?? 0;

                El yeniEl = El(
                  oyunId: _seciliOyunId!,
                  elTarih: ortakTarih,
                  oyuncu1: _aktifOyuncular[i],
                  oyuncu2: _aktifOyuncular[(i + 1) % _aktifOyuncular.length],
                  oyuncu3: _aktifOyuncular.length > 2 ? _aktifOyuncular[(i + 2) % _aktifOyuncular.length] : null,
                  oyuncu4: _aktifOyuncular.length > 3 ? _aktifOyuncular[(i + 3) % _aktifOyuncular.length] : null,
                  elSkor: netSkor,
                  gosterge: hamGosterge * -1,
                );
                await yeniEl.save();
              }
            }

            final sonElKontrol = (mevcutElSayisi + 1) >= hedefElSayisi && !duzenlemeModu;
            final oyunSonucu = await Oyun.oyunSonucunuHesapla(oyunId: _seciliOyunId!, isHighestWins: _isHighestWins, kaliciKapat: sonElKontrol);

            if (!mounted) return;
            if (sonElKontrol) {
              messenger.showSnackBar(SnackBar(content: Text("🎉 Oyun Sonu!\n🏆 Lider: ${oyunSonucu['kazanan']}\n📉 Sonuncu: ${oyunSonucu['kaybeden']}"), backgroundColor: Colors.indigo.shade800));
            } else {
              messenger.showSnackBar(SnackBar(content: Text("🏆 Lider: ${oyunSonucu['kazanan']} | 📉 Sonuncu: ${oyunSonucu['kaybeden']}"), backgroundColor: Colors.teal.shade700));
            }

            if (!dialogContext.mounted) return;
            navigator.pop();
            _verileriYenile();
          }

          Widget formGovdesiOlustur() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                isYatay ? const SizedBox() : Column(mainAxisSize: MainAxisSize.min, children: dikeyUstElemanlar),
                isYatay
                    ? Table(
                        children: List.generate((_aktifOyuncular.length / 2).ceil(), (rowIdx) {
                          int solIdx = rowIdx * 2;
                          int sagIdx = solIdx + 1;
                          return TableRow(
                            children: [
                              oyuncuGirisKutusuOlustur(solIdx),
                              oyuncuGirisKutusuOlustur(sagIdx),
                            ],
                          );
                        }),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_aktifOyuncular.length, (index) => oyuncuGirisKutusuOlustur(index)),
                      ),
              ],
            );
          }

          if (isYatay) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(duzenlemeModu ? 'El Skorlarını Düzenle' : 'Yeni El Skoru Girişi', style: const TextStyle(fontSize: 14)),
                  leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                  actions: [
                    IconButton(icon: const Icon(Icons.check, color: Colors.white), tooltip: 'Kaydet', onPressed: kaydetmeIslemi),
                  ],
                ),
                body: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: SingleChildScrollView(child: formGovdesiOlustur())),
                      const VerticalDivider(width: 12, thickness: 1),
                      Expanded(flex: 1, child: yataySagPanelOlustur(kaydetmeIslemi)),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0, bottom: 20.0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(duzenlemeModu ? 'El Skorlarını Düzenle' : 'Yeni El Skoru Girişi'),
            content: SizedBox(
              width: ekranGenisligi - 20.0,
              child: SingleChildScrollView(child: formGovdesiOlustur()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
              ElevatedButton(onPressed: kaydetmeIslemi, child: const Text('Kaydet')),
            ],
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yaz Boz Tahtası'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_oyunlar.isNotEmpty)
            TextButton.icon(
              onPressed: _oyunKapatVeHesapla,
              icon: const Icon(Icons.stop_circle, color: Colors.white),
              label: const Text("Oyunu Bitir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: FutureBuilder<List<El>>(
        future: _ellerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(child: Center(child: Text('Henüz hiç el skoru girilmemiş.', style: TextStyle(color: Colors.grey)))),
                _altPanelButonlariniOlustur(context, {}, [])
              ],
            );
          }

          final hamList = snapshot.data!;
          Map<String, List<El>> gruplanmisEller = {};
          for (var el in hamList) {
            gruplanmisEller.putIfAbsent(el.elTarih, () => []).add(el);
          }

          List<String> tarihlerSirali = gruplanmisEller.keys.toList()..sort();
          Map<String, int> toplamSonuclar = {};
          Map<String, List<int>> oyuncuGostergeleri = {};

          for (var oyuncu in _aktifOyuncular) {
            toplamSonuclar[oyuncu] = 0;
            oyuncuGostergeleri[oyuncu] = [];
          }

          for (var tarih in tarihlerSirali) {
            final elList = gruplanmisEller[tarih]!;
            for (var el in elList) {
              if (toplamSonuclar.containsKey(el.oyuncu1)) {
                toplamSonuclar[el.oyuncu1] = (toplamSonuclar[el.oyuncu1]! + el.elSkor + (el.gosterge ?? 0));
                if (el.gosterge != null && el.gosterge != 0) {
                  oyuncuGostergeleri[el.oyuncu1]!.add(el.gosterge!);
                }
              }
            }
          }

          int maxGostergeSatiri = 1;
          for (var list in oyuncuGostergeleri.values) {
            if (list.length > maxGostergeSatiri) maxGostergeSatiri = list.length;
          }

          final Map<int, TableColumnWidth> dinamikSutunGenislikleri = {0: const FixedColumnWidth(65.0)};
          for (int i = 0; i < _aktifOyuncular.length; i++) {
            dinamikSutunGenislikleri[i + 1] = const FlexColumnWidth();
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0, bottom: 0.0),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
                      child: Table(
                        columnWidths: dinamikSutunGenislikleri,
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        border: const TableBorder(horizontalInside: BorderSide(color: Colors.black, width: 1), verticalInside: BorderSide(color: Colors.black, width: 1)),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade100),
                            children: [
                              const Padding(padding: EdgeInsets.all(8.0), child: Text('', textAlign: TextAlign.center)),
                              ..._aktifOyuncular.map((oyuncu) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                                child: Text(oyuncu, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              )),
                            ],
                          ),
                          ...List.generate(maxGostergeSatiri, (rowIndex) {
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(rowIndex == 0 ? 'Gösterge' : '', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey, fontSize: 12), textAlign: TextAlign.center)),
                                ..._aktifOyuncular.map((oyuncu) {
                                  final gostergeler = oyuncuGostergeleri[oyuncu]!;
                                  final deger = gostergeler.length > rowIndex ? gostergeler[rowIndex].toString() : '';
                                  return Text(deger, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500));
                                }),
                              ],
                            );
                          }),
                          ...List.generate(tarihlerSirali.length, (index) {
                            final tarihKey = tarihlerSirali[index];
                            final oElinKayitlari = gruplanmisEller[tarihKey]!;
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8.0), child: Text('${index + 1}. El', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                ..._aktifOyuncular.map((oyuncuAdi) {
                                  final elKaydi = oElinKayitlari.firstWhere((e) => e.oyuncu1 == oyuncuAdi, orElse: () => El(oyunId: widget.oyunId, elTarih: '', oyuncu1: '', oyuncu2: '', elSkor: 0));
                                  return GestureDetector(
                                    onTap: () => _elFormuGoster(guncellenecekTarih: tarihKey, elGrubuElemanlari: oElinKayitlari),
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      color: Colors.transparent,
                                      child: Text(elKaydi.elTarih.isEmpty ? '' : elKaydi.elSkor.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                          TableRow(
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15)),
                            children: [
                              const Padding(padding: EdgeInsets.all(8.0), child: Text('Sonuç', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue))),
                              ..._aktifOyuncular.map((oyuncu) {
                                final puan = toplamSonuclar[oyuncu] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(puan.toString(), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: puan >= 0 ? Colors.blue.shade900 : Colors.red.shade900)),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _altPanelButonlariniOlustur(context, toplamSonuclar, tarihlerSirali),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_oyunlar.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Skor girebilmek için aktif bir oyun kurmalısınız!")));
            return;
          }
          _elFormuGoster();
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 🚀 HARİCİ UYGULAMA TETİKLEMELİ (ANDROID 11+) 3'LÜ OVAL ALT PANEL MOTORU
  Widget _altPanelButonlariniOlustur(BuildContext ctx, Map<String, int> sonuclar, List<String> eller) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 90.0, top: 12.0, bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (c) => const OyunlarSayfasi())),
              icon: const Icon(Icons.history, color: Colors.black87, size: 15),
              label: const Text("Arşiv", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.black, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: _oyunKapatVeHesapla,
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.black87, size: 15),
              label: const Text("Bitir", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.black, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: () async {
                if (sonuclar.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("⚠️ Paylaşılacak skor verisi henüz yok!")));
                  return;
                }
                String skorTablosu = "📊 YAZ BOZ CANLI SKOR TABLOSU 📊\n"
                    "🆔 Oyun ID: #${widget.oyunId}\n"
                    "-----------------------------------\n";
                sonuclar.forEach((oyuncu, puan) {
                  skorTablosu += "👤 $oyuncu: $puan Puan\n";
                });
                skorTablosu += "-----------------------------------\n"
                    "⏱️ Toplam oynanan el: ${eller.length} el\n"
                    "Yaz Boz uygulamasi ile canli skor takibi yapiliyor! ✍️";

                final Uri whatsappUrl = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(skorTablosu)}");
                
                // 🎯 KESİN ÇÖZÜM: LaunchMode.externalApplication ile Android işletim sisteminin güvenlik katmanı aşılır
                if (await canLaunchUrl(whatsappUrl)) {
                  await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                } else {
                  final Uri webUrl = Uri.parse("https://whatsapp.com{Uri.encodeComponent(skorTablosu)}");
                  await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.share, color: Colors.black87, size: 15),
              label: const Text("Paylaş", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.black, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tarihController.dispose();
    for (var c in _karControllers) { c.dispose(); }
    for (var c in _zararControllers) { c.dispose(); }
    for (var c in _gostergeControllers) { c.dispose(); }
    super.dispose();
  }
}
