import 'firestack_client.dart';
import 'models/remote_config_entry.dart';

/// The status of the last remote config fetch.
enum RemoteConfigFetchStatus {
  /// No fetch has been performed yet.
  noFetchYet,

  /// The last fetch completed successfully.
  success,

  /// The last fetch failed.
  failure,

  /// The cached values are within the minimum fetch interval (throttled).
  throttled,
}

/// Remote config service for Firestack.
///
/// Supports fetch-interval throttling and stale-while-revalidate caching,
/// like Firebase Remote Config.
///
/// ```dart
/// final config = app.remoteConfig;
///
/// // Set minimum fetch interval (prevents excessive network calls)
/// config.minimumFetchInterval = Duration(minutes: 5);
///
/// // Fetch and activate in one call
/// final updated = await config.fetchAndActivate();
///
/// // Use cached values
/// final darkMode = config.getBool('dark_mode_enabled');
/// final limit = config.getInt('api_rate_limit', defaultValue: 100);
/// ```
class FirestackRemoteConfig {
  final FirestackClient _client;
  final Map<String, RemoteConfigEntry> _cache = {};
  final Map<String, RemoteConfigEntry> _defaults = {};
  DateTime? _lastFetchTime;
  RemoteConfigFetchStatus _lastFetchStatus = RemoteConfigFetchStatus.noFetchYet;

  /// Minimum interval between fetches. Fetches within this window
  /// return cached data without hitting the server.
  Duration minimumFetchInterval;

  FirestackRemoteConfig({
    required FirestackClient client,
    this.minimumFetchInterval = const Duration(minutes: 12),
  }) : _client = client;

  /// The status of the last fetch attempt.
  RemoteConfigFetchStatus get lastFetchStatus => _lastFetchStatus;

  /// The time of the last successful fetch.
  DateTime? get lastFetchTime => _lastFetchTime;

  /// Whether the cache has any values (fetched or defaults).
  bool get hasValues => _cache.isNotEmpty || _defaults.isNotEmpty;

  /// Set default values to use before the first fetch or on failure.
  ///
  /// ```dart
  /// config.setDefaults({
  ///   'dark_mode_enabled': false,
  ///   'api_rate_limit': 100,
  ///   'welcome_message': 'Hello!',
  /// });
  /// ```
  void setDefaults(Map<String, dynamic> defaults) {
    for (final entry in defaults.entries) {
      _defaults[entry.key] = RemoteConfigEntry(
        key: entry.key,
        value: entry.value,
        type: entry.value.runtimeType.toString().toLowerCase(),
        isFeatureFlag: entry.value is bool,
        environment: 'default',
      );
    }
  }

  /// Fetch all remote config values for an environment.
  ///
  /// Respects [minimumFetchInterval] — returns cached data if within the
  /// throttle window. Use [force] to bypass the interval.
  Future<Map<String, RemoteConfigEntry>> getAll({
    String environment = 'production',
    bool force = false,
  }) async {
    // Throttle check
    if (!force && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < minimumFetchInterval) {
        _lastFetchStatus = RemoteConfigFetchStatus.throttled;
        return Map.unmodifiable(_cache);
      }
    }

    try {
      final response = await _client.get('/config', queryParams: {
        'environment': environment,
      });

      final data = response['data'];
      _cache.clear();

      if (data is Map) {
        for (final entry in data.entries) {
          final key = entry.key as String;
          if (entry.value is Map<String, dynamic>) {
            _cache[key] =
                RemoteConfigEntry.fromJson(entry.value as Map<String, dynamic>);
          } else {
            _cache[key] = RemoteConfigEntry(
              key: key,
              value: entry.value,
              type: 'string',
              isFeatureFlag: false,
              environment: environment,
            );
          }
        }
      }

      _lastFetchTime = DateTime.now();
      _lastFetchStatus = RemoteConfigFetchStatus.success;
      return Map.unmodifiable(_cache);
    } catch (_) {
      _lastFetchStatus = RemoteConfigFetchStatus.failure;
      rethrow;
    }
  }

  /// Fetch and activate config in one call (like Firebase fetchAndActivate).
  ///
  /// Returns `true` if new values were fetched, `false` if throttled.
  Future<bool> fetchAndActivate({
    String environment = 'production',
  }) async {
    final before = _lastFetchTime;
    await getAll(environment: environment);
    return _lastFetchTime != before;
  }

  /// Fetch a single config value by key.
  Future<RemoteConfigEntry> getValue(
    String key, {
    String environment = 'production',
  }) async {
    final response = await _client.get('/config/$key', queryParams: {
      'environment': environment,
    });

    final data = response['data'] as Map<String, dynamic>;
    final entry = RemoteConfigEntry.fromJson(data);
    _cache[key] = entry;
    return entry;
  }

  /// Get a cached value (returns null if not fetched yet).
  RemoteConfigEntry? getCached(String key) => _cache[key] ?? _defaults[key];

  /// Get a cached string value with a default fallback.
  String getString(String key, {String defaultValue = ''}) =>
      _cache[key]?.asString ?? _defaults[key]?.asString ?? defaultValue;

  /// Get a cached int value with a default fallback.
  int getInt(String key, {int defaultValue = 0}) =>
      _cache[key]?.asInt ?? _defaults[key]?.asInt ?? defaultValue;

  /// Get a cached double value with a default fallback.
  double getDouble(String key, {double defaultValue = 0.0}) =>
      _cache[key]?.asDouble ?? _defaults[key]?.asDouble ?? defaultValue;

  /// Get a cached bool value with a default fallback.
  bool getBool(String key, {bool defaultValue = false}) =>
      _cache[key]?.asBool ?? _defaults[key]?.asBool ?? defaultValue;

  /// Check if a feature flag is enabled.
  bool isFeatureEnabled(String key) => getBool(key);

  /// Get all currently active config values (fetched + defaults).
  Map<String, RemoteConfigEntry> getActivated() {
    return Map.unmodifiable({..._defaults, ..._cache});
  }

  /// Reset the fetch throttle timer (allows immediate next fetch).
  void resetThrottle() => _lastFetchTime = null;
}
