import 'firestack_client.dart';
import 'models/remote_config_entry.dart';

/// Remote config service for Firestack.
///
/// ```dart
/// final config = app.remoteConfig;
///
/// // Fetch all config values
/// final all = await config.getAll();
///
/// // Fetch a specific config value
/// final entry = await config.getValue('feature_x_enabled');
/// print(entry.asBool); // true
/// ```
class FirestackRemoteConfig {
  final FirestackClient _client;
  final Map<String, RemoteConfigEntry> _cache = {};

  FirestackRemoteConfig({required FirestackClient client}) : _client = client;

  /// Fetch all remote config values for an environment.
  Future<Map<String, RemoteConfigEntry>> getAll({
    String environment = 'production',
  }) async {
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

    return Map.unmodifiable(_cache);
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
  RemoteConfigEntry? getCached(String key) => _cache[key];

  /// Get a cached string value with a default fallback.
  String getString(String key, {String defaultValue = ''}) =>
      _cache[key]?.asString ?? defaultValue;

  /// Get a cached int value with a default fallback.
  int getInt(String key, {int defaultValue = 0}) =>
      _cache[key]?.asInt ?? defaultValue;

  /// Get a cached double value with a default fallback.
  double getDouble(String key, {double defaultValue = 0.0}) =>
      _cache[key]?.asDouble ?? defaultValue;

  /// Get a cached bool value with a default fallback.
  bool getBool(String key, {bool defaultValue = false}) =>
      _cache[key]?.asBool ?? defaultValue;

  /// Check if a feature flag is enabled.
  bool isFeatureEnabled(String key) => getBool(key);
}
