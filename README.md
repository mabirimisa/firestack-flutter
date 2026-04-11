# Firestack Flutter SDK

A complete Flutter/Dart SDK for [Firestack](https://github.com/firestack) — an open-source Firebase alternative backend.

## Features

- **Authentication** — Register, sign in, sign out, profile management
- **Firestore** — Collections, documents, queries, subcollections (Firebase Firestore-like API)
- **Storage** — File upload, download, signed URLs, metadata
- **Messaging** — Channels, messages, reactions, read receipts, typing indicators, search
- **Notifications** — List, mark as read
- **Remote Config** — Feature flags, config values with type casting
- **Analytics** — Event logging, batch events
- **Realtime** — WebSocket-based realtime with auto-reconnect, heartbeat, snapshot streams, offline queue

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  firestack:
    path: ./flutter_sdk/firestack  # or git URL
```

## Quick Start

```dart
import 'package:firestack/firestack.dart';

void main() async {
  // Initialize
  final app = Firestack.initialize(
    apiKey: 'fsk_your_api_key',
    baseUrl: 'https://your-server.com',
  );

  // Sign in
  final user = await app.auth.signIn(
    email: 'alice@example.com',
    password: 'password123',
  );

  // Firestore
  final docs = await app.firestore.collection('users').getDocs();
  for (final doc in docs.data) {
    print('${doc.id}: ${doc.data}');
  }

  // Upload a file
  final file = await app.storage.upload(
    filePath: 'photo.jpg',
    fileBytes: photoBytes,
  );

  // Realtime
  app.realtime.configure(
    host: 'localhost', port: 8080,
    scheme: 'http', appKey: 'reverb-key', appSecret: 'reverb-secret',
  );
  await app.realtime.connect();
  await app.realtime.onDocumentCreated(projectId, (data) {
    print('New doc: $data');
  });

  // Cleanup
  app.dispose();
}
```

## Services

### Authentication

```dart
final auth = app.auth;

// Register
final user = await auth.signUp(
  name: 'Alice',
  email: 'alice@example.com',
  password: 'password',
  passwordConfirmation: 'password',
);

// Sign in
await auth.signIn(email: 'alice@example.com', password: 'password');

// Restore session
auth.signInWithToken('existing-token');

// Profile
final me = await auth.currentUser();
await auth.updateProfile(name: 'New Name');

// Register device for push
await auth.registerDevice(
  token: 'fcm-token', platform: 'android', appId: 'com.example.app',
);

// Sign out
await auth.signOut();
```

### Firestore (Collections & Documents)

```dart
final firestore = app.firestore;

// Collections
final collections = await firestore.collections();
final newCol = await firestore.createCollection(name: 'posts');

// Collection reference
final users = firestore.collection('users');
final details = await users.get(); // Collection details
await users.update(description: 'Updated');
await users.delete();

// Documents - CRUD
final doc = await users.add({'name': 'Alice', 'age': 30});
final namedDoc = await users.addWithId('alice', {'name': 'Alice'});
final fetched = await users.doc('alice').get();
await users.setDoc('alice', {'name': 'Alice', 'age': 31});

// Document by UUID
final byUuid = await firestore.getDocumentByUuid('550e8400-...');
await firestore.updateDocumentByUuid('550e8400-...', {'age': 32});
await firestore.deleteDocumentByUuid('550e8400-...');

// Query with filters
final results = await users.query((q) => q
    .where('age', isGreaterThan: 25)
    .where('status', isEqualTo: 'active')
    .orderBy('created_at', descending: true)
    .limit(10));

// Available operators:
//   isEqualTo, isNotEqualTo, isLessThan, isLessThanOrEqualTo,
//   isGreaterThan, isGreaterThanOrEqualTo, like, whereIn,
//   whereNotIn, arrayContains

// Subcollections
final subcols = await firestore.getSubcollections('doc-uuid');
await firestore.createSubcollection('doc-uuid', 'comments');

// Paginated results
print('Page ${results.currentPage}/${results.lastPage}');
print('Total: ${results.total}');
print('Has more: ${results.hasMore}');
```

### Storage

```dart
final storage = app.storage;

// Upload
final file = await storage.upload(
  filePath: 'photo.jpg',
  fileBytes: bytes,
  visibility: 'public',  // or 'private'
  category: 'images',
  metadata: {'description': 'Profile photo'},
);

// List files
final files = await storage.list(
  category: 'images',
  visibility: 'public',
);

// Get metadata
final info = await storage.getFile('file-uuid');

// Download URL (signed, temporary)
final url = await storage.getDownloadUrl('file-uuid', minutes: 30);
print(url.url);
print(url.expiresAt);

// Download bytes
final bytes = await storage.download('file-uuid');

// Delete
await storage.deleteFile('file-uuid');
```

### Remote Config

```dart
final config = app.remoteConfig;

// Fetch all values
await config.getAll(environment: 'production');

// Use cached values with type-safe getters
final darkMode = config.getBool('dark_mode', defaultValue: false);
final limit = config.getInt('max_items', defaultValue: 50);
final ratio = config.getDouble('ratio', defaultValue: 1.0);
final name = config.getString('app_name', defaultValue: 'My App');

// Feature flags
if (config.isFeatureEnabled('new_ui')) {
  // show new UI
}

// Fetch individual value
final entry = await config.getValue('feature_x');
print(entry.value);     // raw value
print(entry.asBool);    // cast to bool
print(entry.type);      // 'boolean'
print(entry.asMap);     // for JSON type
```

### Analytics

```dart
final analytics = app.analytics;

// Set defaults for all events
analytics.setDefaults(
  platform: 'android',
  appVersion: '2.0.0',
  sessionId: 'sess-123',
);

// Log single event
await analytics.logEvent(
  name: 'screen_view',
  properties: {'screen': 'home'},
);

// Batch log (max 100 events)
await analytics.logBatch([
  AnalyticsEvent(name: 'click', properties: {'button': 'buy'}),
  AnalyticsEvent(name: 'purchase', properties: {'amount': '9.99'}),
]);
```

### Notifications

```dart
final notifications = app.notifications;

final result = await notifications.list(perPage: 20);
for (final n in result.data) {
  print('${n.title}: read=${n.isRead}');
}

await notifications.markAsRead('notification-id');
await notifications.markAllAsRead();
```

### Messaging (Instant Messaging)

```dart
final messaging = app.messaging;

// List channels
final channels = await messaging.channels(projectId: 1);

// Create a group channel
final channel = await messaging.createChannel(
  projectId: 1,
  name: 'general',
  description: 'Team chat',
  memberIds: [2, 3, 4],
);

// Direct messages
final dm = await messaging.createDirectChannel(projectId: 1, userId: 2);

// Send messages
final msg = await messaging.sendMessage(
  channelId: channel.id,
  body: 'Hello team!',
);

// Reply to a message
await messaging.sendMessage(
  channelId: channel.id,
  body: 'Great idea!',
  type: 'reply',
  replyToId: 42,
);

// Edit / delete
await messaging.updateMessage(msg.id, body: 'Hello team! (edited)');
await messaging.deleteMessage(msg.id);

// Reactions
await messaging.addReaction(messageId: msg.id, emoji: '👍');
await messaging.removeReaction(messageId: msg.id, emoji: '👍');

// Read receipts
await messaging.markAsRead(channel.id);

// Typing indicator (via API)
await messaging.sendTyping(channel.id);

// Search messages
final results = await messaging.searchMessages(channel.id, query: 'hello');

// Mute / pin
await messaging.toggleMute(channel.id);
await messaging.togglePin(channel.id);

// Member management
await messaging.addMember(channel.id, userId: 5, role: 'admin');
await messaging.updateMemberRole(channel.id, userId: 5, role: 'member');
await messaging.removeMember(channel.id, userId: 5);
```

### Realtime (WebSocket)

```dart
final realtime = app.realtime;

// Configure
realtime.configure(
  host: 'your-server.com',
  port: 8080,
  scheme: 'ws',
  appKey: 'your-reverb-app-key',
  appSecret: 'your-reverb-app-secret',
);

// Connect (auto-reconnects on disconnect)
await realtime.connect();
print('Socket ID: ${realtime.socketId}');

// Connection state stream
realtime.stateStream.listen((state) {
  print('Connection: $state'); // connected, reconnecting, disconnected
});

// Listen for project events
final projectId = 1;

await realtime.onDocumentCreated(projectId, (data) {
  print('Created: ${data['name']}');
});

await realtime.onDocumentUpdated(projectId, (data) {
  print('Updated: ${data['name']}');
});

await realtime.onDocumentDeleted(projectId, (data) {
  print('Deleted: ${data['id']}');
});

await realtime.onFileUploaded(projectId, (data) {
  print('Uploaded: ${data['name']}');
});

await realtime.onFileDeleted(projectId, (data) {
  print('Deleted: ${data['id']}');
});

// -- Messaging Realtime --

// Listen for messages on a channel
await realtime.onMessageReceived(channelId, (data) {
  print('New message: ${data['body']}');
});

await realtime.onMessageUpdated(channelId, (data) {
  print('Edited: ${data['body']}');
});

await realtime.onMessageDeleted(channelId, (data) {
  print('Deleted: ${data['uuid']}');
});

// Typing indicators
await realtime.onTyping(channelId, (data) {
  print('${data['user_name']} is typing...');
});

// Client-side typing whisper (no server roundtrip)
realtime.sendTyping(channelId, isTyping: true);

// Reactions
await realtime.onReactionAdded(channelId, (data) {
  print('${data['user_name']} reacted: ${data['emoji']}');
});

// -- Snapshot Streams (Firestore onSnapshot-like) --

// Stream-based document listener
realtime.snapshotStream(projectId: 1, event: 'document.created').listen((data) {
  print('Snapshot: $data');
});

// Message stream (all events: sent, updated, deleted)
realtime.messageStream(channelId).listen((data) {
  final event = data['_event']; // 'sent', 'updated', 'deleted'
  print('[$event] ${data['body']}');
});

// Typing stream
realtime.typingStream(channelId).listen((data) {
  print('${data['user_name']} typing: ${data['is_typing']}');
});

// Reaction stream
realtime.reactionStream(channelId).listen((data) {
  final event = data['_event']; // 'added', 'removed'
  print('[$event] ${data['emoji']}');
});

// Custom channel listener
await realtime.onUserEvent(userId, '.notification', (data) {
  print('Notification: $data');
});

// Disconnect
realtime.disconnect();
```

## Error Handling

All operations throw `FirestackException` on failure:

```dart
try {
  await app.auth.signIn(email: 'wrong@email.com', password: 'wrong');
} on FirestackException catch (e) {
  print('Error: ${e.message}');
  print('Status: ${e.statusCode}');
  print('Code: ${e.errorCode}');

  if (e.isUnauthorized) print('Bad credentials');
  if (e.isRateLimited) print('Too many requests');
  if (e.isValidationError) print('Validation: ${e.errors}');
}
```

## API Key Authentication

All requests require an API key with prefix `fsk_`. Set it during initialization:

```dart
final app = Firestack.initialize(
  apiKey: 'fsk_a1b2c3d4e5...',
  baseUrl: 'https://your-server.com',
);
```

The key is sent as `X-API-Key` header on every request. Bearer tokens (from sign in) are sent as `Authorization: Bearer {token}`.

---

## Firestack CLI

A separate CLI tool is available at `firestack_cli/` for managing your backend from the terminal:

```bash
# Initialize project
firestack init

# Authenticate
firestack auth login
firestack auth profile

# Manage collections
firestack collections list
firestack collections create --name users
firestack collections show --slug users
firestack collections delete --slug users

# Manage documents
firestack docs list --collection users
firestack docs add --collection users --data '{"name":"Alice","age":30}'
firestack docs set --collection users --id alice --data '{"name":"Alice"}'
firestack docs get --collection users --id alice
firestack docs delete --uuid 550e8400-...

# File storage
firestack storage list
firestack storage upload --file ./photo.jpg --visibility public
firestack storage info --id file-uuid
firestack storage url --id file-uuid --minutes 30
firestack storage delete --id file-uuid

# Remote config
firestack config list --env production
firestack config get --key feature_x

# Status check
firestack status
```

## License

MIT
