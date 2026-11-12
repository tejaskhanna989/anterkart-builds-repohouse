class Review {
  final String name;
  final int rating;
  final String comment;
  final String date;

  Review({required this.name, required this.rating, this.comment = '', this.date = ''});

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    name: j['name'] ?? 'Customer',
    rating: j['rating'] is int ? j['rating'] : int.tryParse('${j['rating']}') ?? 5,
    comment: j['comment'] ?? '',
    date: j['created_at'] ?? '',
  );
}