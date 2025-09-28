class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final double rating;
  final int reviewCount;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
  });

  factory Product.fromRecord(Map<String, dynamic> r) {
    return Product(
      id: r['id'],
      name: r['name'] ?? '',
      price: (r['price'] ?? 0).toDouble(),
      imageUrl: r['imageUrl'] ?? '',
      rating: (r['rating'] ?? 0).toDouble(),
      reviewCount: (r['reviewCount'] ?? 0) as int,
    );
  }
}
