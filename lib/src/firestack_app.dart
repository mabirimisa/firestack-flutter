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

/// Main entry point for the Firestack SDK.
///
/// ```dart
/// final app = Firestack.initialize(
///   apiKey: 'fsk_your_api_key',
///   baseUrl: 'https://your-server.com',
/// );
/// ```
class Firestack {
  final FirestackClient _client;

  late final FirestackAuth auth;
  late final FirestackFirestore firestore;
  late final FirestackStorage storage;
  late final FirestackNotifications notifications;
  late final FirestackRemoteConfig remoteConfig;
  late final FirestackAnalytics analytics;
  late final FirestackRealtime realtime;
  late final FirestackMessaging messaging;

  Firestack._({required FirestackClient client}) : _client = client {
    auth = FirestackAuth(client: _client);
    firestore = FirestackFirestore(client: _client);
    storage = FirestackStorage(client: _client);
    notifications = FirestackNotifications(client: _client);
    remoteConfig = FirestackRemoteConfig(client: _client);
    analytics = FirestackAnalytics(client: _client);
    realtime = FirestackRealtime(client: _client);
    messaging = FirestackMessaging(client: _client);
  }

  /// Initialize a Firestack app instance.
  ///
  /// [apiKey] - Your Firestack API key (starts with `fsk_`).
  /// [baseUrl] - The base URL of your Firestack server.
  /// [httpClient] - Optional custom HTTP client for testing.
  static Firestack initialize({
    required String apiKey,
    required String baseUrl,
    http.Client? httpClient,
  }) {
    final client = FirestackClient(
      baseUrl: '$baseUrl/api/v1',
      apiKey: apiKey,
      httpClient: httpClient,
    );
    return Firestack._(client: client);
  }

  /// Get the underlying HTTP client (for advanced use).
  FirestackClient get client => _client;

  /// Dispose all resources.
  void dispose() {
    realtime.dispose();
    _client.dispose();
  }
}
