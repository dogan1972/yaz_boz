class Sehir {
  final int? sehirId;
  final String sehirAd;

  // 🚀 BÜYÜK ÇÖZÜM: Veritabanından gelen canlı istatistik değişkenleri modele eklendi
  final int toplamOyuncu;
  final int toplamSampiyonluk;

  Sehir({
    this.sehirId,
    required this.sehirAd,
    this.toplamOyuncu = 0,
    this.toplamSampiyonluk = 0,
  });

  // Veritabanından gelen ham Map verisini Dart nesnesine dönüştüren fabrika motoru
  factory Sehir.fromMap(Map<String, dynamic> map) {
    return Sehir(
      sehirId: map['sehirId'],
      sehirAd: map['sehirAd'] ?? '',
      // 🎯 Sorgu esnasında 'as toplamOyuncu' adıyla hesapladığımız takma adları buraya kilitliyoruz
      toplamOyuncu: map['toplamOyuncu'] ?? 0,
      toplamSampiyonluk: map['toplamSampiyonluk'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (sehirId != null) 'sehirId': sehirId,
      'sehirAd': sehirAd,
      // İhtiyaç halinde harita çıktılarına da istatistikler dahil edildi
      'toplamOyuncu': toplamOyuncu,
      'toplamSampiyonluk': toplamSampiyonluk,
    };
  }
}
