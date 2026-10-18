import '../core/formatters.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.refId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        refId: json['ref_id'] as String?,
        isRead: json['is_read'] as bool,
        createdAt: parseApiTime(json['created_at'] as String),
      );

  final int id;
  final String type;
  final String title;
  final String body;
  final String? refId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    refId: refId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
