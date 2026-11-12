class BannerModel {
  final int id;
  final String title;
  final String image;
  final String? link;
  final int sortOrder;

  BannerModel({required this.id, required this.title, required this.image, this.link, this.sortOrder = 0});

  factory BannerModel.fromJson(Map<String, dynamic> j) => BannerModel(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    title: j['title'] ?? '',
    image: j['image'] ?? '',
    link: j['link'],
    sortOrder: j['sort_order'] is int ? j['sort_order'] : int.tryParse('${j['sort_order']}') ?? 0,
  );
}
