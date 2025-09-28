class Review {
  final String id;
  final String userName;
  final double rating;
  final String comment;

  Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
  });

  factory Review.fromRecord(Map<String, dynamic> r) {
    return Review(
      id: r['id'],
      userName: r['userName'] ?? 'Anonymous',
      rating: (r['rating'] ?? 0).toDouble(),
      comment: r['comment'] ?? '',
    );
  }
}
