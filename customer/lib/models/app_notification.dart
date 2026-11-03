class AppNotification {
  final int id;
  final String title;
  final String message;
  final String link;
  final bool isRead;
  final String createdAt;

  AppNotification({required this.id, required this.title, required this.message, required this.link, required this.isRead, required this.createdAt});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    title: j['title'] ?? '',
    message: j['message'] ?? '',
    link: j['link'] ?? '',
    isRead: (j['is_read'] ?? 0) == 1 || (j['is_read'] ?? '0') == '1',
    createdAt: j['created_at'] ?? '',
  );
}