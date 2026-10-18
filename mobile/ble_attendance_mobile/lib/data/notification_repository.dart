import '../models/app_notification.dart';
import 'api_client.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> list({bool unreadOnly = false});
  Future<int> unreadCount();
  Future<void> markRead(int id);
  Future<void> markAllRead();
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final json =
        await _api.get('/notifications', query: {'unread_only': unreadOnly})
            as List<dynamic>;
    return [
      for (final item in json)
        AppNotification.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<int> unreadCount() async {
    final json =
        await _api.get('/notifications/unread-count') as Map<String, dynamic>;
    return json['count'] as int;
  }

  @override
  Future<void> markRead(int id) async {
    await _api.post('/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all');
  }
}
