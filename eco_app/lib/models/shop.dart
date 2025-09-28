class Shop {
  final String id;
  final String name;
  final String logoUrl;
  final double rating;
  final String city;

  Shop({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.rating,
    required this.city,
  });

  factory Shop.fromRecord(Map<String, dynamic> r) {
    return Shop(
      id: r['id'],
      name: r['name'] ?? '',
      logoUrl: r['logoUrl'] ?? '',
      rating: (r['rating'] ?? 0).toDouble(),
      city: r['city'] ?? '',
    );
  }
}
