class ReviewDeletion {
  final int id;
  final int productId;
  final String productName;
  final int rating;
  final String comment;
  final String date;

  ReviewDeletion({
    required this.id,
    required this.productId,
    required this.productName,
    required this.rating,
    this.comment = '',
    this.date = '',
  });

  factory ReviewDeletion.fromJson(Map<String, dynamic> j) => ReviewDeletion(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    productId: j['product_id'] is int ? j['product_id'] : int.tryParse('${j['product_id']}') ?? 0,
    productName: j['product_name'] ?? 'Product',
    rating: j['rating'] is int ? j['rating'] : int.tryParse('${j['rating']}') ?? 5,
    comment: j['comment'] ?? '',
    date: j['created_at'] ?? '',
  );
}