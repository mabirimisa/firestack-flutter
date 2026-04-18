import 'package:http/http.dart' as http;
import 'firestack_client.dart';
import 'firestack_auth.dart';
import 'firestack_firestore.dart';
import 'firestack_storage.dart';
import 'firestack_notifications.dart';
import 'firestack_remote_config.dart';
import 'firestack_analytics.dart';
import 'firestack_realtime.dart';
import 'firestack_messaging.dart';

/// Default base URL for the Firestack API server.
const String firestackDefaultBaseUrl = 'https://firestack.co.za';

/// Main entry point for the Firestack SDK.
///
/// ```dart
/// final app = Firestack.initialize(
///   apiKey: 'fsk_your_api_key',
/// );
/// ```
///
/// You can override the base URL if your Firestack server runs elsewhere:
///
/// ```dart
/// final app = Firestack.initialize(
///   apiKey: 'fsk_your_api_key',
///   baseUrl: 'https://your-server.com',
/// );
/// ```
class Firestack {
  final FirestackClient _client;
  final String name;

  late final FirestackAuth auth;
  late final FirestackFirestore firestore;
  late final FirestackStorage storage;
  late final FirestackNotifications notifications;
  late final FirestackRemoteConfig remoteConfig;
  late final FirestackAnalytics analytics;
  late final FirestackRealtime realtime;
  late final FirestackMessaging messaging;

  /// Registry of named app instances.
  static final Map<String, Firestack> _apps = {};

  /// The default app name.
  static const String defaultAppName = '[DEFAULT]';

  Firestack._({required FirestackClient client, this.name = defaultAppName})
      : _client = client {
    auth = FirestackAuth(client: _client);
    firestore = FirestackFirestore(client: _client);
    storage = FirestackStorage(client: _client);
    notifications = FirestackNotifications(client: _client);
    remoteConfig = FirestackRemoteConfig(client: _client);
    analytics = FirestackAnalytics(client: _client);
    realtime = FirestackRealtime(client: _client);
    messaging = FirestackMessaging(client: _client);

    // Wire realtime into firestore for snapshot streams
    firestore.attachRealtime(realtime);
  }

  /// Initialize a Firestack app instance.
  ///
  /// [apiKey] - Your Firestack API key (starts with `fsk_`).
  /// [baseUrl] - The base URL of your Firestack server.
  ///   Defaults to [firestackDefaultBaseUrl].
  /// [name] - Optional name for the app instance. Allows multiple instances.
  /// [httpClient] - Optional custom HTTP client for testing.
  /// [timeout] - Request timeout. Defaults to 30 seconds.
  /// [maxRetries] - Max retry attempts for retryable errors. Defaults to 3.
  /// [logLevel] - Debug log level. Defaults to none.
  ///
  /// ```dart
  /// // Default instance
  /// final app = Firestack.initialize(apiKey: 'fsk_main_key');
  ///
  /// // Named instance (e.g. for a second project)
  /// final secondary = Firestack.initialize(
  ///   apiKey: 'fsk_secondary_key',
  ///   name: 'secondary',
  /// );
  ///
  /// // Retrieve later
  /// final app = Firestack.instance;
  /// final secondary = Firestack.instanceFor(name: 'secondary');
  /// ```
  static Firestack initialize({
    required String apiKey,
    String baseUrl = firestackDefaultBaseUrl,
    String name = defaultAppName,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    FirestackLogLevel logLevel = FirestackLogLevel.none,
    void Function(String)? logger,
  }) {
    if (_apps.containsKey(name)) {
      throw StateError(
        'Firestack app "$name" already initialized. '
        'Call Firestack.instanceFor(name: "$name") to retrieve it, '
        'or dispose it first.',
      );
    }

    final client = FirestackClient(
      baseUrl: '$baseUrl/api/v1',
      apiKey: apiKey,
      httpClient: httpClient,
      timeout: timeout,
      maxRetries: maxRetries,
      logLevel: logLevel,
      logger: logger,
    );
    final app = Firestack._(client: client, name: name);
    _apps[name] = app;
    return app;
  }

  /// Get the default app instance.
  static Firestack get instance {
    if (!_apps.containsKey(defaultAppName)) {
      throw StateError(
        'No default Firestack app. Call Firestack.initialize() first.',
      );
    }
    return _apps[defaultAppName]!;
  }

  /// Get a named app instance.
  static Firestack instanceFor({required String name}) {
    if (!_apps.containsKey(name)) {
      throw StateError(
        'Firestack app "$name" not found. Call Firestack.initialize(name: "$name") first.',
      );
    }
    return _apps[name]!;
  }

  /// Get the underlying HTTP client (for advanced use).
  FirestackClient get client => _client;

  /// Dispose all resources and remove from the app registry.
  void dispose() {
    auth.dispose();
    notifications.dispose();
    realtime.dispose();
    _client.dispose();
    _apps.remove(name);
  }
}
