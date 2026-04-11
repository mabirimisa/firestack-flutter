import 'firestack_client.dart';

/// Analytics service for tracking events.
///
/// ```dart
/// final analytics = app.analytics;
///
/// // Log a single event
/// await analytics.logEvent(
///   name: 'screen_view',
///   properties: {'screen': 'home'},
///   platform: 'android',
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
  Map<String, dynamic>? _deviceInfo;

  FirestackAnalytics({required FirestackClient client}) : _client = client;

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
    await _client.post('/events', body: {
      'event_name': name,
      if (properties != null) 'properties': properties,
      if ((sessionId ?? _sessionId) != null)
        'session_id': sessionId ?? _sessionId,
      if ((platform ?? _platform) != null) 'platform': platform ?? _platform,
      if ((appVersion ?? _appVersion) != null)
        'app_version': appVersion ?? _appVersion,
      if ((deviceInfo ?? _deviceInfo) != null)
        'device_info': deviceInfo ?? _deviceInfo,
    });
  }

  /// Log multiple events in a single batch (max 100).
  Future<int> logBatch(List<AnalyticsEvent> events) async {
    final response = await _client.post('/events/batch', body: {
      'events': events.map((e) => {
            'event_name': e.name,
            if (e.properties != null) 'properties': e.properties,
            if ((e.sessionId ?? _sessionId) != null)
              'session_id': e.sessionId ?? _sessionId,
            if ((e.platform ?? _platform) != null)
              'platform': e.platform ?? _platform,
            if ((e.appVersion ?? _appVersion) != null)
              'app_version': e.appVersion ?? _appVersion,
            if ((e.deviceInfo ?? _deviceInfo) != null)
              'device_info': e.deviceInfo ?? _deviceInfo,
          }).toList(),
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
