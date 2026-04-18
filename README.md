# Firestack Flutter SDK

[![pub package](https://img.shields.io/pub/v/firestack.svg)](https://pub.dev/packages/firestack)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A complete Flutter/Dart SDK for [Firestack](https://firestack.co.za) — an open-source Firebase alternative backend.

## Features

- **Authentication** — Register, sign in/out, OAuth/social login, password reset, email verification, token persistence, auth state stream
- **Firestore** — Collections, documents, queries, subcollections, batch writes, transactions, FieldValue operations, aggregate queries (count/sum/average), collection group queries, in-memory document cache
- **Storage** — File upload with progress tracking, download, signed URLs, batch delete, copy
- **Messaging** — Channels, messages, reactions, read receipts, typing indicators, search
- **Notifications** — Permission lifecycle, device token management, topic subscriptions, foreground message handling, list/read/delete
- **Remote Config** — Feature flags, config values with type casting, fetch throttling, defaults, stale-while-revalidate
- **Analytics** — Event logging, batch events, user identity, user properties, screen tracking
- **Realtime** — WebSocket-based realtime with auto-reconnect, heartbeat, Firestore snapshots, offline queue
- **Multiple Apps** — Named app instances for multi-project setups

## Installation

```yaml
dependencies:
  firestack: ^1.2.0
```

Then run:

```bash
dart pub get
```

## Quick Start

```dart
import 'package:firestack/firestack.dart';

void main() async {
  final app = Firestack.initialize(
    apiKey: 'fsk_your_api_key',
    // baseUrl defaults to https://firestack.co.za
  );

  // Auth
  final user = await app.auth.signIn(
    email: 'alice@example.com',
    password: 'password123',
  );

  // Firestore
  final docs = await app.firestore.collection('users').getDocs();

  // Storage
  final file = await app.storage.upload(
    filePath: 'photo.jpg',
    fileBytes: photoBytes,
  );

  // Realtime
  app.realtime.configure(
    host: 'your-server.com', port: 8080,
    scheme: 'ws', appKey: 'key', appSecret: 'secret',
  );
  await app.realtime.connect();

  app.dispose();
}
```

## Services

### Authentication

```dart
final auth = app.auth;

// Auth state stream (like Firebase onAuthStateChanged)
auth.authStateChanges.listen((user) {
  print(user != null ? 'Signed in: ${user.name}' : 'Signed out');
});

// Token persistence
auth.setTokenPersistence((token) async {
  // Save to flutter_secure_storage, shared_preferences, etc.
});

// Register
final user = await auth.signUp(
  name: 'Alice',
  email: 'alice@example.com',
  password: 'password',
  passwordConfirmation: 'password',
);

// Sign in
await auth.signIn(email: 'alice@example.com', password: 'password');

// OAuth / Social Login
final googleUser = await auth.signInWithOAuth(
  provider: 'google',
  token: 'google-id-token',
);
await auth.linkOAuthProvider(provider: 'github', token: 'github-token');

// Restore session
auth.signInWithToken('existing-token');
final me = await auth.currentUser();

// Password management
await auth.sendPasswordResetEmail(email: 'alice@example.com');
await auth.changePassword(
  currentPassword: 'old', newPassword: 'new', newPasswordConfirmation: 'new',
);

// Email verification
await auth.sendEmailVerification();

// Token refresh
final newToken = await auth.refreshToken();

// Delete account
await auth.deleteAccount(password: 'password');

// Sign out
await auth.signOut();
```

### Firestore (Collections & Documents)

```dart
final firestore = app.firestore;

// CRUD
final doc = await firestore.collection('users').add({'name': 'Alice', 'age': 30});
final fetched = await firestore.collection('users').doc('alice').get();
await firestore.collection('users').doc('alice').update({'age': 31});
await firestore.collection('users').doc('alice').delete();

// Check existence
final exists = await firestore.collection('users').doc('alice').exists();

// Query with filters
final results = await firestore.collection('users').query((q) => q
    .where('age', isGreaterThan: 25)
    .where('status', isEqualTo: 'active')
    .where('tags', arrayContains: 'premium')
    .where('role', whereIn: ['admin', 'editor'])
    .where('deleted_at', isNull: true)
    .orderBy('created_at', descending: true)
    .select(['name', 'email', 'age'])
    .search('alice')
    .limit(10)
    .page(1));

// Paginated results
print('Page ${results.currentPage}/${results.lastPage}');
print('Has next: ${results.hasNextPage}');
print('Has prev: ${results.hasPreviousPage}');
final names = results.map((doc) => doc.get<String>('name'));

// FieldValue operations (like Firebase)
await firestore.collection('users').doc('alice').update({
  'login_count': FieldValue.increment(1),
  'tags': FieldValue.arrayUnion(['vip']),
  'temp': FieldValue.delete(),
  'updated_at': FieldValue.serverTimestamp(),
});

// Batch writes
final batch = firestore.batch();
batch.set(firestore.collection('users').doc('bob'), {'name': 'Bob'});
batch.update(firestore.collection('users').doc('alice'), {'role': 'admin'});
batch.delete(firestore.collection('users').doc('charlie'));
await batch.commit();

// Transactions
await firestore.runTransaction((tx) async {
  final doc = await tx.get(firestore.collection('accounts').doc('alice'));
  final balance = doc.get<int>('balance') ?? 0;
  tx.update(firestore.collection('accounts').doc('alice'),
      {'balance': balance - 50});
  tx.update(firestore.collection('accounts').doc('bob'),
      {'balance': FieldValue.increment(50)});
});

// Aggregate queries
final count = await firestore.collection('users').count();
final totalRevenue = await firestore.collection('orders').sum('amount');
final avgAge = await firestore.collection('users').average('age');

// Collection group queries (across all subcollections)
final allComments = await firestore.collectionGroup('comments').getDocs();

// Document cache (offline-first reads)
final cached = await firestore.collection('users').doc('alice')
    .get(source: CacheSource.cache); // Cache-only read
firestore.cache.clear(); // Clear cache

// Realtime snapshots (like Firebase onSnapshot)
firestore.collection('users').snapshots(projectId: 1).listen((docs) {
  print('${docs.length} users');
});
firestore.collection('users').doc('alice').snapshots(projectId: 1).listen((doc) {
  print('Alice: ${doc?.data}');
});
```

### Storage

```dart
final storage = app.storage;

// Upload with progress callback
final file = await storage.upload(
  filePath: 'photo.jpg',
  fileBytes: bytes,
  visibility: 'public',
  category: 'images',
  onProgress: (sent, total) => print('$sent / $total'),
);

// Upload with stream-based progress (like Firebase UploadTask)
final task = storage.uploadWithProgress(
  filePath: 'video.mp4',
  fileBytes: videoBytes,
);
task.onProgress.listen((snap) {
  print('${(snap.progress * 100).toStringAsFixed(1)}%');
});
final result = await task.future;

// Download URL with expiry checking
final url = await storage.getDownloadUrl('file-uuid', minutes: 30);
print('Expired: ${url.isExpired}');

// List with pagination
final files = await storage.list(category: 'images', page: 1, perPage: 20);

// Batch delete
await storage.deleteFiles(['uuid1', 'uuid2']);

// Copy
final copy = await storage.copyFile('uuid', visibility: 'private');
```

### Notifications & Push

```dart
final notifications = app.notifications;

// 1. Configure platform & app
notifications.configure(platform: 'android', appId: 'com.example.app');

// 2. Set up native permission handler
notifications.setPermissionRequestHandler(() async {
  final status = await Permission.notification.request();
  return NotificationSettings(
    authorizationStatus: status.isGranted
        ? NotificationAuthorizationStatus.authorized
        : NotificationAuthorizationStatus.denied,
  );
});

// 3. Set up device token provider
notifications.setTokenProvider(() async {
  return await FirebaseMessaging.instance.getToken();
});

// 4. Request permission (auto-registers device)
final settings = await notifications.requestPermission();
if (settings.isAuthorized) {
  print('Push enabled!');
}

// Foreground message handling
notifications.onMessage((notification) {
  print('Received: ${notification.title}');
});

// Topic subscriptions
await notifications.subscribeToTopic('promotions');
await notifications.unsubscribeFromTopic('promotions');

// Server notifications CRUD
final notifs = await notifications.list(unreadOnly: true);
final unread = await notifications.unreadCount();
await notifications.markAsRead('id');
await notifications.markAllAsRead();
await notifications.delete('id');
await notifications.deleteAll();
```

### Remote Config

```dart
final config = app.remoteConfig;

// Set defaults (used before first fetch)
config.setDefaults({
  'dark_mode': false,
  'max_items': 50,
  'welcome_msg': 'Hello!',
});

// Set minimum fetch interval (throttling)
config.minimumFetchInterval = Duration(minutes: 5);

// Fetch and activate in one call
final updated = await config.fetchAndActivate();

// Type-safe cached getters (falls back to defaults)
final darkMode = config.getBool('dark_mode');
final limit = config.getInt('max_items', defaultValue: 50);
final ratio = config.getDouble('ratio', defaultValue: 1.0);
final name = config.getString('app_name', defaultValue: 'My App');

// Feature flags
if (config.isFeatureEnabled('new_ui')) { /* ... */ }

// Fetch status
print(config.lastFetchStatus); // success, failure, throttled
print(config.lastFetchTime);
```

### Analytics

```dart
final analytics = app.analytics;

// Set user identity (like Firebase setUserId)
analytics.setUserId('user-123');

// Set user properties (auto-merged into all events)
analytics.setUserProperty(name: 'subscription', value: 'premium');

// Set defaults
analytics.setDefaults(platform: 'android', appVersion: '2.0.0');

// Screen tracking
await analytics.logScreenView(screenName: 'Home', screenClass: 'HomePage');

// Convenience events
await analytics.logLogin(method: 'email');
await analytics.logSignUp(method: 'google');

// Custom events
await analytics.logEvent(
  name: 'purchase',
  properties: {'item_id': '42', 'price': '9.99'},
);

// Batch (max 100)
await analytics.logBatch([
  AnalyticsEvent(name: 'item_view', properties: {'item_id': '42'}),
  AnalyticsEvent(name: 'add_to_cart', properties: {'qty': '1'}),
]);
```

### Messaging (Instant Messaging)

```dart
final messaging = app.messaging;

// Channels
final channels = await messaging.channels(projectId: 1);
final channel = await messaging.createChannel(
  projectId: 1, name: 'general', memberIds: [2, 3],
);
final dm = await messaging.createDirectChannel(projectId: 1, userId: 2);

// Messages
final msg = await messaging.sendMessage(channelId: channel.id, body: 'Hello!');
await messaging.updateMessage(msg.id, body: 'Hello! (edited)');
await messaging.deleteMessage(msg.id);

// Reactions, read receipts, typing
await messaging.addReaction(messageId: msg.id, emoji: '👍');
await messaging.markAsRead(channel.id);
await messaging.sendTyping(channel.id);

// Search, mute, pin
final results = await messaging.searchMessages(channel.id, query: 'hello');
await messaging.toggleMute(channel.id);
await messaging.togglePin(channel.id);
```

### Realtime (WebSocket)

```dart
final realtime = app.realtime;

realtime.configure(
  host: 'your-server.com', port: 8080,
  scheme: 'ws', appKey: 'key', appSecret: 'secret',
);

await realtime.connect();

// Connection state
realtime.stateStream.listen((state) => print('$state'));

// Document events
await realtime.onDocumentCreated(projectId, (data) => print(data));
await realtime.onDocumentUpdated(projectId, (data) => print(data));

// Message events
await realtime.onMessageReceived(channelId, (data) => print(data));
await realtime.onTyping(channelId, (data) => print(data));

// Snapshot streams
realtime.snapshotStream(projectId: 1, event: 'document.created').listen(print);
realtime.messageStream(channelId).listen(print);
```

### Multiple App Instances

```dart
// Default app
final app = Firestack.initialize(apiKey: 'fsk_main');

// Named app (e.g. second project)
final secondary = Firestack.initialize(
  apiKey: 'fsk_other',
  name: 'secondary',
);

// Retrieve later
final main = Firestack.instance;
final other = Firestack.instanceFor(name: 'secondary');
```

## Error Handling

```dart
try {
  await app.auth.signIn(email: 'wrong@email.com', password: 'wrong');
} on FirestackException catch (e) {
  print('${e.statusCode}: ${e.message}');
  if (e.isUnauthorized) print('Bad credentials');
  if (e.isRateLimited) print('Too many requests');
  if (e.isValidationError) print('Errors: ${e.errors}');
}
```

## Configuration

```dart
final app = Firestack.initialize(
  apiKey: 'fsk_your_key',          // Required
  baseUrl: 'https://your-server.com', // Default: https://firestack.co.za
  timeout: Duration(seconds: 15),     // Default: 30s
  maxRetries: 2,                      // Default: 3 (retries 429/5xx/timeout)
  logLevel: FirestackLogLevel.info,   // none, error, info, verbose
);
```

## License

MIT
