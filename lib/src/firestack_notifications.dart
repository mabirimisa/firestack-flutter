import 'dart:async';
import 'firestack_client.dart';
import 'firestack_firestore.dart';
import 'models/notification.dart';

/// The authorization status for notifications.
enum NotificationAuthorizationStatus {
  /// Permission has not been requested yet.
  notDetermined,

  /// The user granted permission.
  authorized,

  /// The user denied permission.
  denied,

  /// Permission is granted but only delivered silently (no banners/sound).
  provisional,
}

/// Settings returned after requesting notification permissions.
class NotificationSettings {
  final NotificationAuthorizationStatus authorizationStatus;

  const NotificationSettings({
    required this.authorizationStatus,
  });

  /// Whether notifications are allowed.
  bool get isAuthorized =>
      authorizationStatus == NotificationAuthorizationStatus.authorized ||
      authorizationStatus == NotificationAuthorizationStatus.provisional;
}

/// Callback the SDK consumer provides to request native notification permission.
///
/// This is called by the SDK when [requestPermission] is invoked.
/// The consumer should use their platform-specific code (e.g.
/// `firebase_messaging`, `permission_handler`, `flutter_local_notifications`)
/// to request the actual OS permission and return the result.
///
/// ```dart
/// notifications.setPermissionRequestHandler(() async {
///   // Using permission_handler:
///   final status = await Permission.notification.request();
///   return NotificationSettings(
///     authorizationStatus: status.isGranted
///         ? NotificationAuthorizationStatus.authorized
///         : NotificationAuthorizationStatus.denied,
///   );
/// });
/// ```
typedef PermissionRequestHandler = Future<NotificationSettings> Function();

/// Callback the SDK consumer provides to retrieve the device push token.
///
/// The consumer should use their push notification plugin (e.g.
/// `firebase_messaging`, `onesignal`, or platform channels) to get the token
/// and return it here.
///
/// ```dart
/// notifications.setTokenProvider(() async {
///   return await FirebaseMessaging.instance.getToken();
/// });
/// ```
typedef DeviceTokenProvider = Future<String?> Function();

/// Callback invoked when a push notification is received while the app is
/// in the foreground.
typedef ForegroundMessageHandler = void Function(FirestackNotification message);

/// Notification service for Firestack.
///
/// Handles both **server-side notifications** (list, read, delete) and
/// **push notification lifecycle** (permissions, device tokens, topics).
///
/// ## Quick Start
///
/// ```dart
/// final notifications = app.notifications;
///
/// // 1. Set up native permission handler (required once)
/// notifications.setPermissionRequestHandler(() async {
///   final status = await Permission.notification.request();
///   return NotificationSettings(
///     authorizationStatus: status.isGranted
///         ? NotificationAuthorizationStatus.authorized
///         : NotificationAuthorizationStatus.denied,
///   );
/// });
///
/// // 2. Set up device token provider
/// notifications.setTokenProvider(() async {
///   return await FirebaseMessaging.instance.getToken();
/// });
///
/// // 3. Request permission + auto-register device
/// final settings = await notifications.requestPermission();
/// if (settings.isAuthorized) {
///   print('Push notifications enabled!');
/// }
///
/// // 4. Listen to foreground messages
/// notifications.onMessage((notification) {
///   print('Received: ${notification.title}');
/// });
///
/// // 5. List server notifications
/// final result = await notifications.list();
/// ```
class FirestackNotifications {
  final FirestackClient _client;

  PermissionRequestHandler? _permissionHandler;
  DeviceTokenProvider? _tokenProvider;

  /// Whether a foreground message handler is registered.
  bool get hasForegroundHandler => _foregroundHandler != null;

  ForegroundMessageHandler? _foregroundHandler;
  NotificationSettings? _lastSettings;
  String? _deviceToken;
  String? _platform;
  String? _appId;

  final StreamController<FirestackNotification> _messageController =
      StreamController<FirestackNotification>.broadcast();

  FirestackNotifications({required FirestackClient client}) : _client = client;

  // ─── Permission & Token Setup ────────────────────────────

  /// Register a handler that performs the native permission request.
  ///
  /// This is required before calling [requestPermission]. The handler should
  /// use platform-specific code to show the OS permission dialog.
  void setPermissionRequestHandler(PermissionRequestHandler handler) {
    _permissionHandler = handler;
  }

  /// Register a provider that returns the push token (FCM, APNs, etc.).
  ///
  /// This is required for [registerDevice] / [requestPermission] to
  /// auto-register the device with the Firestack server.
  void setTokenProvider(DeviceTokenProvider provider) {
    _tokenProvider = provider;
  }

  /// Set the platform and app ID for device registration.
  ///
  /// Call this once during app startup.
  /// ```dart
  /// notifications.configure(platform: 'android', appId: 'com.example.app');
  /// ```
  void configure({required String platform, required String appId}) {
    _platform = platform;
    _appId = appId;
  }

  /// The last known permission settings, or `null` if not yet requested.
  NotificationSettings? get settings => _lastSettings;

  /// Whether push notifications are currently authorized.
  bool get isAuthorized => _lastSettings?.isAuthorized ?? false;

  /// The current device push token, or `null` if not yet retrieved.
  String? get deviceToken => _deviceToken;

  // ─── Permission Request ──────────────────────────────────

  /// Request notification permission from the user.
  ///
  /// Calls the native permission handler you registered via
  /// [setPermissionRequestHandler]. If permission is granted **and** a
  /// [DeviceTokenProvider] is configured, the device is automatically
  /// registered with the Firestack server.
  ///
  /// ```dart
  /// final settings = await notifications.requestPermission();
  /// if (settings.isAuthorized) {
  ///   print('Notifications enabled!');
  /// }
  /// ```
  ///
  /// Throws [StateError] if no permission handler has been set.
  Future<NotificationSettings> requestPermission() async {
    if (_permissionHandler == null) {
      throw StateError(
        'No permission handler configured. '
        'Call setPermissionRequestHandler() first.',
      );
    }

    _lastSettings = await _permissionHandler!();

    // Auto-register device if permission granted
    if (_lastSettings!.isAuthorized) {
      await _tryRegisterDevice();
    }

    return _lastSettings!;
  }

  /// Manually get the device token and register it with the server.
  ///
  /// This is useful if you handle permissions yourself and just want the
  /// SDK to register the token.
  Future<String?> getToken() async {
    if (_tokenProvider == null) return null;
    _deviceToken = await _tokenProvider!();
    return _deviceToken;
  }

  /// Register the device for push notifications with the Firestack server.
  ///
  /// Requires [configure] to be called first with platform and appId.
  /// If no token is provided, the [DeviceTokenProvider] is called.
  Future<void> registerDevice({String? token}) async {
    final pushToken = token ?? _deviceToken ?? await getToken();
    if (pushToken == null) {
      throw StateError(
        'No device token available. '
        'Provide a token or set a DeviceTokenProvider.',
      );
    }
    if (_platform == null || _appId == null) {
      throw StateError(
        'Platform and appId not configured. '
        'Call notifications.configure(platform:, appId:) first.',
      );
    }

    await _client.post('/auth/devices', body: {
      'token': pushToken,
      'platform': _platform!,
      'app_id': _appId!,
    });
    _deviceToken = pushToken;
  }

  /// Unregister this device from push notifications.
  Future<void> unregisterDevice() async {
    final token = _deviceToken;
    if (token == null) return;
    await _client.post('/auth/devices/remove', body: {
      'token': token,
    });
    _deviceToken = null;
  }

  Future<void> _tryRegisterDevice() async {
    try {
      final token = await getToken();
      if (token != null && _platform != null && _appId != null) {
        await registerDevice(token: token);
      }
    } catch (_) {
      // Silently fail — device registration is best-effort
    }
  }

  // ─── Foreground Message Handling ─────────────────────────

  /// Register a handler for push notifications received while the app
  /// is in the foreground.
  ///
  /// ```dart
  /// notifications.onMessage((notification) {
  ///   showSnackbar(notification.title);
  /// });
  /// ```
  void onMessage(ForegroundMessageHandler handler) {
    _foregroundHandler = handler;
    _messageController.stream.listen((msg) {
      handler(msg);
    });
  }

  /// Stream of foreground notifications.
  Stream<FirestackNotification> get onMessageStream =>
      _messageController.stream;

  /// Call this from your native push handler to route messages through the SDK.
  ///
  /// ```dart
  /// // In your Firebase Messaging onMessage callback:
  /// FirebaseMessaging.onMessage.listen((remoteMessage) {
  ///   notifications.handleMessage({
  ///     'id': remoteMessage.messageId ?? '',
  ///     'type': remoteMessage.data['type'] ?? 'push',
  ///     'title': remoteMessage.notification?.title ?? '',
  ///     'body': remoteMessage.notification?.body ?? '',
  ///     'data': remoteMessage.data,
  ///     'status': 'delivered',
  ///     'created_at': DateTime.now().toIso8601String(),
  ///   });
  /// });
  /// ```
  void handleMessage(Map<String, dynamic> messageData) {
    final notification = FirestackNotification.fromJson(messageData);
    _messageController.add(notification);
  }

  // ─── Topic Subscriptions ─────────────────────────────────

  /// Subscribe to a notification topic.
  ///
  /// ```dart
  /// await notifications.subscribeToTopic('promotions');
  /// await notifications.subscribeToTopic('order-updates');
  /// ```
  Future<void> subscribeToTopic(String topic) async {
    await _client.post('/notifications/topics/$topic/subscribe');
  }

  /// Unsubscribe from a notification topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _client.post('/notifications/topics/$topic/unsubscribe');
  }

  // ─── Server Notification CRUD ────────────────────────────

  /// List notifications for the current user.
  Future<PaginatedResult<FirestackNotification>> list({
    int perPage = 15,
    int page = 1,
    String? type,
    bool? unreadOnly,
  }) async {
    final params = <String, dynamic>{
      'per_page': perPage.toString(),
      'page': page.toString(),
    };
    if (type != null) params['type'] = type;
    if (unreadOnly == true) params['unread'] = '1';

    final response = await _client.get('/notifications', queryParams: params);

    final data = (response['data'] as List)
        .map((e) => FirestackNotification.fromJson(e as Map<String, dynamic>))
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

  /// Get unread notification count.
  Future<int> unreadCount() async {
    final response = await _client.get('/notifications/unread-count');
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['count'] as int? ?? 0;
  }

  /// Delete a notification.
  Future<void> delete(String notificationId) async {
    await _client.delete('/notifications/$notificationId');
  }

  /// Delete all notifications.
  Future<void> deleteAll() async {
    await _client.delete('/notifications');
  }

  /// Dispose resources.
  void dispose() {
    _messageController.close();
  }
}
