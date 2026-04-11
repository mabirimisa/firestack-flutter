import 'dart:io';
import 'dart:typed_data';
import 'package:firestack/firestack.dart';

/// Example usage of the Firestack Flutter SDK.
void main() async {
  // ─── Initialize ───────────────────────────────────────────
  final app = Firestack.initialize(
    apiKey: 'fsk_your_api_key_here',
    baseUrl: 'http://localhost:8000',
  );

  // ─── Authentication ───────────────────────────────────────
  final auth = app.auth;

  // Register a new user
  final user = await auth.signUp(
    name: 'Alice Johnson',
    email: 'alice@example.com',
    password: 'securePassword123',
    passwordConfirmation: 'securePassword123',
  );
  print('Registered: ${user.name} (${user.email})');

  // Or sign in
  // final user = await auth.signIn(
  //   email: 'alice@example.com',
  //   password: 'securePassword123',
  // );
  // print('Signed in: ${user.name}');

  // Get current user
  final me = await auth.currentUser();
  print('Current user: ${me.name}');

  // ─── Firestore (Collections & Documents) ──────────────────
  final firestore = app.firestore;

  // Create a collection
  final collection = await firestore.createCollection(
    name: 'users',
    description: 'User profiles',
  );
  print('Created collection: ${collection.name}');

  // Add a document (auto-generated ID)
  final doc = await firestore.collection('users').add({
    'name': 'Bob Smith',
    'age': 28,
    'email': 'bob@example.com',
    'address': {
      'city': 'New York',
      'zip': '10001',
    },
  });
  print('Created document: ${doc.id}');

  // Add a document with a specific ID
  final namedDoc = await firestore.collection('users').addWithId(
    'alice-profile',
    {'name': 'Alice Johnson', 'age': 30, 'role': 'admin'},
  );
  print('Created named document: ${namedDoc.id}');

  // Get a document
  final fetched = await firestore.collection('users').doc('alice-profile').get();
  print('Fetched: ${fetched.data}');

  // Set (upsert) a document
  await firestore.collection('users').setDoc('alice-profile', {
    'name': 'Alice Johnson',
    'age': 31,
    'role': 'admin',
    'verified': true,
  });

  // Query documents
  final results = await firestore.collection('users').query((q) => q
      .where('age', isGreaterThan: 25)
      .orderBy('created_at', descending: true)
      .limit(10));
  print('Found ${results.total} users over 25');
  for (final d in results.data) {
    print('  - ${d.get<String>('name')}: age ${d.get<int>('age')}');
  }

  // List all collections
  final collections = await firestore.collections();
  print('Collections: ${collections.data.map((c) => c.name).join(', ')}');

  // ─── Storage ──────────────────────────────────────────────
  final storage = app.storage;

  // Upload a file
  final fileBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
  final uploaded = await storage.upload(
    filePath: 'avatar.png',
    fileBytes: fileBytes,
    visibility: 'public',
    category: 'avatars',
    metadata: {'user_id': '123'},
  );
  print('Uploaded: ${uploaded.originalName} (${uploaded.sizeHuman})');

  // Get download URL
  final urlInfo = await storage.getDownloadUrl(uploaded.id, minutes: 30);
  print('Download URL: ${urlInfo.url}');

  // List files
  final files = await storage.list(category: 'avatars');
  print('Files: ${files.data.length}');

  // Delete a file
  await storage.deleteFile(uploaded.id);

  // ─── Notifications ────────────────────────────────────────
  final notifications = app.notifications;

  final notifs = await notifications.list();
  for (final n in notifs.data) {
    print('${n.title}: ${n.body} (read: ${n.isRead})');
  }

  // Mark all as read
  await notifications.markAllAsRead();

  // ─── Remote Config ────────────────────────────────────────
  final config = app.remoteConfig;

  // Fetch all config
  await config.getAll(environment: 'production');

  // Use cached values
  final darkMode = config.getBool('dark_mode_enabled', defaultValue: false);
  final apiLimit = config.getInt('api_rate_limit', defaultValue: 100);
  print('Dark mode: $darkMode, API limit: $apiLimit');

  // Fetch a specific value
  final feature = await config.getValue('new_feature_enabled');
  print('New feature: ${feature.asBool} (flag: ${feature.isFeatureFlag})');

  // ─── Analytics ────────────────────────────────────────────
  final analytics = app.analytics;

  // Set default properties
  analytics.setDefaults(
    platform: 'android',
    appVersion: '1.2.0',
    sessionId: 'session-abc123',
  );

  // Log events
  await analytics.logEvent(
    name: 'screen_view',
    properties: {'screen': 'home'},
  );

  await analytics.logEvent(
    name: 'button_click',
    properties: {'button': 'submit', 'page': 'settings'},
  );

  // Batch log
  final count = await analytics.logBatch([
    AnalyticsEvent(name: 'item_view', properties: {'item_id': '42'}),
    AnalyticsEvent(name: 'add_to_cart', properties: {'item_id': '42', 'qty': '1'}),
    AnalyticsEvent(name: 'checkout_start'),
  ]);
  print('Logged $count events');

  // ─── Realtime ─────────────────────────────────────────────
  final realtime = app.realtime;

  // Configure WebSocket
  realtime.configure(
    host: 'localhost',
    port: 8080,
    scheme: 'http',
    appKey: 'your-reverb-app-key',
    appSecret: 'your-reverb-app-secret',
  );

  // Connect
  await realtime.connect();
  print('Connected to realtime! Socket ID: ${realtime.socketId}');

  // Listen for changes
  await realtime.onDocumentCreated(1, (data) {
    print('Document created: $data');
  });

  await realtime.onDocumentUpdated(1, (data) {
    print('Document updated: $data');
  });

  await realtime.onDocumentDeleted(1, (data) {
    print('Document deleted: $data');
  });

  await realtime.onFileUploaded(1, (data) {
    print('File uploaded: $data');
  });

  await realtime.onFileDeleted(1, (data) {
    print('File deleted: $data');
  });

  // Keep listening...
  print('Listening for realtime events. Press Ctrl+C to stop.');
  await ProcessSignal.sigint.watch().first;

  // Cleanup
  app.dispose();
}
