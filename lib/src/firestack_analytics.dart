import 'firestack_client.dart';

/// Analytics service for tracking events.
///
/// ```dart
/// final analytics = app.analytics;
///
/// // Set user identity (like Firebase's setUserId)
/// analytics.setUserId('user-123');
///
/// // Set user properties
/// analytics.setUserProperty(name: 'subscription', value: 'premium');
///
/// // Log screen views
/// await analytics.logScreenView(screenName: 'HomeScreen');
///
/// // Log a single event
/// await analytics.logEvent(
///   name: 'purchase',
///   properties: {'item_id': '42', 'price': '9.99'},
/// );
///
/// // Log batch events
/// await analytics.logBatch([
///   AnalyticsEvent(name: 'button_click', properties: {'button': 'submit'}),
///   AnalyticsEvent(name: 'page_view', properties: {'page': '/dashboard'}),
/// ]);
/// ```
class FirestackAnalytics {
  final FirestackClient _client;
  String? _sessionId;
  String? _platform;
  String? _appVersion;
  String? _userId;
  Map<String, dynamic>? _deviceInfo;
  final Map<String, dynamic> _userProperties = {};

  FirestackAnalytics({required FirestackClient client}) : _client = client;

  /// Set the user ID for all subsequent events (like Firebase setUserId).
  ///
  /// Pass `null` to clear the user ID.
  void setUserId(String? userId) => _userId = userId;

  /// Set a user property (like Firebase setUserProperty).
  ///
  /// User properties are sent with every event automatically.
  void setUserProperty({required String name, required String? value}) {
    if (value == null) {
      _userProperties.remove(name);
    } else {
      _userProperties[name] = value;
    }
  }

  /// Get all current user properties.
  Map<String, dynamic> get userProperties => Map.unmodifiable(_userProperties);

  /// Set default properties for all subsequent events.
  void setDefaults({
    String? sessionId,
    String? platform,
    String? appVersion,
    Map<String, dynamic>? deviceInfo,
  }) {
    if (sessionId != null) _sessionId = sessionId;
    if (platform != null) _platform = platform;
    if (appVersion != null) _appVersion = appVersion;
    if (deviceInfo != null) _deviceInfo = deviceInfo;
  }

  /// Log a single analytics event.
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? properties,
    String? sessionId,
    String? platform,
    String? appVersion,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final mergedProps = <String, dynamic>{
      ..._userProperties,
      if (properties != null) ...properties,
    };
    await _client.post('/events', body: {
      'event_name': name,
      if (mergedProps.isNotEmpty) 'properties': mergedProps,
      if (_userId != null) 'user_id': _userId,
      if ((sessionId ?? _sessionId) != null)
        'session_id': sessionId ?? _sessionId,
      if ((platform ?? _platform) != null) 'platform': platform ?? _platform,
      if ((appVersion ?? _appVersion) != null)
        'app_version': appVersion ?? _appVersion,
      if ((deviceInfo ?? _deviceInfo) != null)
        'device_info': deviceInfo ?? _deviceInfo,
    });
  }

  /// Log a screen/page view event (like Firebase logScreenView).
  ///
  /// ```dart
  /// await analytics.logScreenView(
  ///   screenName: 'HomeScreen',
  ///   screenClass: 'HomePage',
  /// );
  /// ```
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await logEvent(
      name: 'screen_view',
      properties: {
        'screen_name': screenName,
        if (screenClass != null) 'screen_class': screenClass,
      },
    );
  }

  /// Log a sign-up event.
  Future<void> logSignUp({required String method}) async {
    await logEvent(name: 'sign_up', properties: {'method': method});
  }

  /// Log a login event.
  Future<void> logLogin({required String method}) async {
    await logEvent(name: 'login', properties: {'method': method});
  }

  /// Log multiple events in a single batch (max 100).
  Future<int> logBatch(List<AnalyticsEvent> events) async {
    final response = await _client.post('/events/batch', body: {
      'events': events
          .map((e) => {
                'event_name': e.name,
                if (e.properties != null || _userProperties.isNotEmpty)
                  'properties': {
                    ..._userProperties,
                    if (e.properties != null) ...e.properties!,
                  },
                if (_userId != null) 'user_id': _userId,
                if ((e.sessionId ?? _sessionId) != null)
                  'session_id': e.sessionId ?? _sessionId,
                if ((e.platform ?? _platform) != null)
                  'platform': e.platform ?? _platform,
                if ((e.appVersion ?? _appVersion) != null)
                  'app_version': e.appVersion ?? _appVersion,
                if ((e.deviceInfo ?? _deviceInfo) != null)
                  'device_info': e.deviceInfo ?? _deviceInfo,
              })
          .toList(),
    });

    return (response['data'] as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}

/// An analytics event for batch logging.
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic>? properties;
  final String? sessionId;
  final String? platform;
  final String? appVersion;
  final Map<String, dynamic>? deviceInfo;

  const AnalyticsEvent({
    required this.name,
    this.properties,
    this.sessionId,
    this.platform,
    this.appVersion,
    this.deviceInfo,
  });
}
