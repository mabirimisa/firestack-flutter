import 'firestack_client.dart';
import 'firestack_firestore.dart';
import 'models/notification.dart';

/// Notification service for Firestack.
///
/// ```dart
/// final notifications = app.notifications;
///
/// // List notifications
/// final result = await notifications.list();
///
/// // Mark as read
/// await notifications.markAsRead('notification-uuid');
///
/// // Mark all as read
/// await notifications.markAllAsRead();
/// ```
class FirestackNotifications {
  final FirestackClient _client;

  FirestackNotifications({required FirestackClient client}) : _client = client;

  /// List notifications for the current user.
  Future<PaginatedResult<FirestackNotification>> list({
    int perPage = 15,
  }) async {
    final response = await _client.get('/notifications', queryParams: {
      'per_page': perPage.toString(),
    });

    final data = (response['data'] as List)
        .map((e) =>
            FirestackNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = response['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedResult(
      data: data,
      currentPage: meta['current_page'] as int? ?? 1,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? data.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _client.put('/notifications/$notificationId/read');
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    await _client.post('/notifications/read-all');
  }
}
