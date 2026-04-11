import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'firestack_client.dart';

/// Connection state of the realtime engine.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Realtime engine for Firestack using WebSockets (Pusher protocol).
///
/// Features:
/// - Auto-reconnect with exponential backoff
/// - Heartbeat / ping-pong keep-alive
/// - Connection state stream
/// - Offline event queue (buffered sends while disconnected)
/// - Presence-aware channel subscriptions
/// - Typing indicator support (client whisper events)
/// - Snapshot-style stream listeners
///
/// ```dart
/// final realtime = app.realtime;
///
/// realtime.configure(
///   host: 'localhost',
///   port: 8080,
///   scheme: 'ws',
///   appKey: 'your-reverb-key',
///   appSecret: 'your-reverb-secret',
/// );
///
/// await realtime.connect();
///
/// // Stream-based snapshot listener
/// realtime
///   .snapshotStream(projectId: 1, event: 'document.created')
///   .listen((data) => print(data));
///
/// // Messaging channel listener
/// realtime.onMessageReceived(channelId, (data) {
///   print('New message: ${data['body']}');
/// });
///
/// // Typing indicator
/// realtime.sendTyping(channelId, isTyping: true);
/// ```
class FirestackRealtime {
  String? _host;
  int? _port;
  String _scheme = 'ws';
  String? _appKey;
  String? _appSecret;

  WebSocketChannel? _channel;
  String? _socketId;
  ConnectionState _state = ConnectionState.disconnected;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 15;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  bool _intentionalDisconnect = false;

  final Map<String, List<void Function(Map<String, dynamic>)>> _listeners = {};
  final Set<String> _subscribedChannels = {};
  final List<Map<String, dynamic>> _offlineQueue = [];

  // Connection state stream
  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();

  FirestackRealtime({required FirestackClient client});

  /// Stream of connection state changes.
  Stream<ConnectionState> get stateStream => _stateController.stream;

  /// Current connection state.
  ConnectionState get state => _state;

  /// Whether the WebSocket is connected.
  bool get isConnected => _state == ConnectionState.connected;

  /// The socket ID assigned by the server.
  String? get socketId => _socketId;

  /// Number of events queued while offline.
  int get offlineQueueLength => _offlineQueue.length;

  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Configure the WebSocket connection parameters.
  void configure({
    required String host,
    required int port,
    String scheme = 'ws',
    required String appKey,
    String? appSecret,
  }) {
    _host = host;
    _port = port;
    _scheme = scheme;
    _appKey = appKey;
    _appSecret = appSecret;
  }

  /// Connect to the Reverb WebSocket server.
  Future<void> connect() async {
    if (_host == null || _appKey == null) {
      throw StateError(
          'Call configure() before connect(). Host and appKey are required.');
    }

    _intentionalDisconnect = false;
    _setState(ConnectionState.connecting);

    final wsScheme = _scheme == 'https' || _scheme == 'wss' ? 'wss' : 'ws';
    final uri = Uri.parse(
        '$wsScheme://$_host:$_port/app/$_appKey?protocol=7&client=dart&version=2.0');

    try {
      _channel = WebSocketChannel.connect(uri);
      final completer = Completer<void>();

      _subscription = _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          _handleMessage(data);
          if (!completer.isCompleted &&
              data['event'] == 'pusher:connection_established') {
            completer.complete();
          }
        },
        onError: (error) {
          _setState(ConnectionState.disconnected);
          _stopHeartbeat();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
          _scheduleReconnect();
        },
        onDone: () {
          _setState(ConnectionState.disconnected);
          _stopHeartbeat();
          if (!_intentionalDisconnect) {
            _scheduleReconnect();
          }
        },
      );

      return completer.future;
    } catch (e) {
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
      rethrow;
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    final channelName = message['channel'] as String?;

    if (event == 'pusher:connection_established') {
      final data =
          jsonDecode(message['data'] as String) as Map<String, dynamic>;
      _socketId = data['socket_id'] as String;
      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
      _resubscribeAll();
      _flushOfflineQueue();
      return;
    }

    if (event == 'pusher:pong') {
      return; // Keep-alive response received
    }

    if (event == 'pusher_internal:subscription_succeeded') {
      return;
    }

    if (event == 'pusher:error') {
      return;
    }

    // Handle custom events (including client whisper events)
    if (channelName != null && event != null) {
      final key = '$channelName::$event';
      final listeners = _listeners[key];
      if (listeners != null) {
        Map<String, dynamic> eventData;
        if (message['data'] is String) {
          eventData =
              jsonDecode(message['data'] as String) as Map<String, dynamic>;
        } else {
          eventData = message['data'] as Map<String, dynamic>? ?? {};
        }
        for (final listener in List.of(listeners)) {
          listener(eventData);
        }
      }
    }
  }

  // ─── Heartbeat / Ping-Pong ──────────────────────────────────

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (isConnected) {
        _send({'event': 'pusher:ping', 'data': {}});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ─── Auto-Reconnect ─────────────────────────────────────────

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    _setState(ConnectionState.reconnecting);
    _reconnectAttempts++;

    // Exponential backoff: 1s, 2s, 4s, 8s ... capped at 30s + jitter
    final baseDelay = min(pow(2, _reconnectAttempts - 1).toInt(), 30);
    final jitter = Random().nextInt(1000);
    final delay = Duration(seconds: baseDelay, milliseconds: jitter);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      try {
        await connect();
      } catch (_) {
        // connect() will schedule another reconnect via onError/onDone
      }
    });
  }

  /// Re-subscribe to all channels after reconnect.
  void _resubscribeAll() {
    final channels = Set<String>.from(_subscribedChannels);
    _subscribedChannels.clear();

    for (final channel in channels) {
      if (channel.startsWith('private-')) {
        _subscribePrivate(channel);
      } else {
        _send({
          'event': 'pusher:subscribe',
          'data': {'channel': channel},
        });
        _subscribedChannels.add(channel);
      }
    }
  }

  // ─── Offline Queue ──────────────────────────────────────────

  void _flushOfflineQueue() {
    if (_offlineQueue.isEmpty) return;
    final queue = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();
    for (final msg in queue) {
      _send(msg);
    }
  }

  // ─── Channel Subscriptions ──────────────────────────────────

  Future<void> _subscribePrivate(String channel) async {
    if (_subscribedChannels.contains(channel)) return;

    final auth = _generateAuth(channel);

    _send({
      'event': 'pusher:subscribe',
      'data': {
        'channel': channel,
        'auth': auth,
      },
    });

    _subscribedChannels.add(channel);
  }

  String _generateAuth(String channel) {
    if (_appSecret == null || _socketId == null) {
      throw StateError('Cannot auth: missing appSecret or socketId');
    }
    final stringToSign = '$_socketId:$channel';
    final hmacSha256 = Hmac(sha256, utf8.encode(_appSecret!));
    final digest = hmacSha256.convert(utf8.encode(stringToSign));
    return '$_appKey:$digest';
  }

  void _send(Map<String, dynamic> data) {
    if (isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    } else {
      // Buffer sends while disconnected
      _offlineQueue.add(data);
    }
  }

  /// Listen for an event on a channel.
  Future<void> _on(
    String channel,
    String event,
    void Function(Map<String, dynamic>) callback,
  ) async {
    if (channel.startsWith('private-')) {
      await _subscribePrivate(channel);
    } else {
      if (!_subscribedChannels.contains(channel)) {
        _send({
          'event': 'pusher:subscribe',
          'data': {'channel': channel},
        });
        _subscribedChannels.add(channel);
      }
    }

    final key = '$channel::$event';
    _listeners.putIfAbsent(key, () => []).add(callback);
  }

  /// Remove a specific listener.
  void off(String channel, String event,
      void Function(Map<String, dynamic>) callback) {
    final key = '$channel::$event';
    _listeners[key]?.remove(callback);
  }

  /// Remove all listeners for a channel and optionally unsubscribe.
  void removeAllListeners(String channel, {bool unsubscribe = true}) {
    _listeners.removeWhere((key, _) => key.startsWith('$channel::'));
    if (unsubscribe && _subscribedChannels.contains(channel)) {
      _send({
        'event': 'pusher:unsubscribe',
        'data': {'channel': channel},
      });
      _subscribedChannels.remove(channel);
    }
  }

  // ─── Snapshot Streams ───────────────────────────────────────

  /// Returns a broadcast stream of events, similar to Firestore's onSnapshot.
  ///
  /// ```dart
  /// realtime.snapshotStream(projectId: 1, event: 'document.created').listen((data) {
  ///   print(data);
  /// });
  /// ```
  Stream<Map<String, dynamic>> snapshotStream({
    required int projectId,
    required String event,
    String channelType = 'collections',
  }) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final channelName = 'private-project.$projectId.$channelType';

    void handler(Map<String, dynamic> data) {
      if (!controller.isClosed) {
        controller.add(data);
      }
    }

    _on(channelName, '.$event', handler);

    controller.onCancel = () {
      off(channelName, '.$event', handler);
    };

    return controller.stream;
  }

  /// Returns a stream of all messages on a messaging channel.
  Stream<Map<String, dynamic>> messageStream(int channelId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final channelName = 'private-channel.$channelId';

    void onSent(Map<String, dynamic> data) {
      if (!controller.isClosed) controller.add({...data, '_event': 'sent'});
    }

    void onUpdated(Map<String, dynamic> data) {
      if (!controller.isClosed) controller.add({...data, '_event': 'updated'});
    }

    void onDeleted(Map<String, dynamic> data) {
      if (!controller.isClosed) controller.add({...data, '_event': 'deleted'});
    }

    _on(channelName, '.message.sent', onSent);
    _on(channelName, '.message.updated', onUpdated);
    _on(channelName, '.message.deleted', onDeleted);

    controller.onCancel = () {
      off(channelName, '.message.sent', onSent);
      off(channelName, '.message.updated', onUpdated);
      off(channelName, '.message.deleted', onDeleted);
    };

    return controller.stream;
  }

  /// Returns a stream of typing indicator events on a messaging channel.
  Stream<Map<String, dynamic>> typingStream(int channelId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final channelName = 'private-channel.$channelId';

    void handler(Map<String, dynamic> data) {
      if (!controller.isClosed) controller.add(data);
    }

    _on(channelName, '.user.typing', handler);

    controller.onCancel = () {
      off(channelName, '.user.typing', handler);
    };

    return controller.stream;
  }

  /// Returns a stream of reaction events on a messaging channel.
  Stream<Map<String, dynamic>> reactionStream(int channelId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final channelName = 'private-channel.$channelId';

    void onAdded(Map<String, dynamic> data) {
      if (!controller.isClosed) controller.add({...data, '_event': 'added'});
    }

    void onRemoved(Map<String, dynamic> data) {
      if (!controller.isClosed) controller.add({...data, '_event': 'removed'});
    }

    _on(channelName, '.reaction.added', onAdded);
    _on(channelName, '.reaction.removed', onRemoved);

    controller.onCancel = () {
      off(channelName, '.reaction.added', onAdded);
      off(channelName, '.reaction.removed', onRemoved);
    };

    return controller.stream;
  }

  // ─── Client Whisper Events (Typing) ─────────────────────────

  /// Send a client typing whisper event to a messaging channel.
  ///
  /// Requires Reverb's `accept_client_events_from: members` to be enabled.
  void sendTyping(int channelId, {bool isTyping = true}) {
    final channelName = 'private-channel.$channelId';
    _send({
      'event': 'client-typing',
      'channel': channelName,
      'data': {'is_typing': isTyping},
    });
  }

  // ─── Convenience Listeners (Documents & Storage) ────────────

  /// Listen for document created events on a project.
  Future<void> onDocumentCreated(
    int projectId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on(
      'private-project.$projectId.collections',
      '.document.created',
      callback,
    );
  }

  /// Listen for document updated events on a project.
  Future<void> onDocumentUpdated(
    int projectId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on(
      'private-project.$projectId.collections',
      '.document.updated',
      callback,
    );
  }

  /// Listen for document deleted events on a project.
  Future<void> onDocumentDeleted(
    int projectId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on(
      'private-project.$projectId.collections',
      '.document.deleted',
      callback,
    );
  }

  /// Listen for file uploaded events on a project.
  Future<void> onFileUploaded(
    int projectId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on(
      'private-project.$projectId.storage',
      '.file.uploaded',
      callback,
    );
  }

  /// Listen for file deleted events on a project.
  Future<void> onFileDeleted(
    int projectId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on(
      'private-project.$projectId.storage',
      '.file.deleted',
      callback,
    );
  }

  // ─── Convenience Listeners (Messaging) ──────────────────────

  /// Listen for new messages on a messaging channel.
  Future<void> onMessageReceived(
    int channelId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on('private-channel.$channelId', '.message.sent', callback);
  }

  /// Listen for message edits on a messaging channel.
  Future<void> onMessageUpdated(
    int channelId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on('private-channel.$channelId', '.message.updated', callback);
  }

  /// Listen for message deletions on a messaging channel.
  Future<void> onMessageDeleted(
    int channelId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on('private-channel.$channelId', '.message.deleted', callback);
  }

  /// Listen for reaction events on a messaging channel.
  Future<void> onReactionAdded(
    int channelId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on('private-channel.$channelId', '.reaction.added', callback);
  }

  /// Listen for reaction removal events on a messaging channel.
  Future<void> onReactionRemoved(
    int channelId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on('private-channel.$channelId', '.reaction.removed', callback);
  }

  /// Listen for typing indicators on a messaging channel.
  Future<void> onTyping(
    int channelId,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on('private-channel.$channelId', '.user.typing', callback);
  }

  /// Listen for events on a user-specific channel.
  Future<void> onUserEvent(
    int userId,
    String event,
    void Function(Map<String, dynamic> data) callback,
  ) async {
    await _on('private-user.$userId', event, callback);
  }

  // ─── Lifecycle ──────────────────────────────────────────────

  /// Disconnect from the WebSocket server.
  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _socketId = null;
    _setState(ConnectionState.disconnected);
    _subscribedChannels.clear();
    _listeners.clear();
    _offlineQueue.clear();
  }

  /// Dispose all resources and close the state stream.
  void dispose() {
    disconnect();
    _stateController.close();
  }
}
