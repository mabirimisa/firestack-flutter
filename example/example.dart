import 'dart:io';
import 'dart:typed_data';
import 'package:firestack/firestack.dart';

/// Example usage of the Firestack Flutter SDK.
void main() async {
  // ─── Initialize ───────────────────────────────────────────
  final app = Firestack.initialize(
    apiKey: 'fsk_your_api_key_here',
    // baseUrl defaults to https://firestack.co.za
    // Enable debug logging during development:
    logLevel: FirestackLogLevel.info,
    // Custom timeout and retries:
    timeout: const Duration(seconds: 15),
    maxRetries: 2,
  );

  // Multiple app instances (like Firebase named apps):
  // final secondary = Firestack.initialize(
  //   apiKey: 'fsk_other_project_key',
  //   name: 'secondary',
  // );
  // final app2 = Firestack.instanceFor(name: 'secondary');

  // ─── Authentication ───────────────────────────────────────
  final auth = app.auth;

  // Listen to auth state changes (like Firebase's onAuthStateChanged)
  auth.authStateChanges.listen((user) {
    if (user != null) {
      print('Auth state: signed in as ${user.name}');
    } else {
      print('Auth state: signed out');
    }
  });

  // Persist tokens to secure storage
  auth.setTokenPersistence((token) async {
    // Save to flutter_secure_storage, shared_preferences, etc.
    print('Token changed: ${token != null ? 'saved' : 'cleared'}');
  });

  // Register a new user
  final user = await auth.signUp(
    name: 'Alice Johnson',
    email: 'alice@example.com',
    password: 'securePassword123',
    passwordConfirmation: 'securePassword123',
  );
  print('Registered: ${user.name} (${user.email})');

  // User model: copyWith, equality, DateTime parsing
  final updatedUser = user.copyWith(name: 'Alice J.');
  print('Updated name: ${updatedUser.name}');
  print('Same user? ${user == updatedUser}'); // true (same id)
  print('Created: ${user.createdAtDate}'); // DateTime object
  print('Has avatar: ${user.hasAvatar}');

  // Or sign in
  // final user = await auth.signIn(
  //   email: 'alice@example.com',
  //   password: 'securePassword123',
  // );

  // Get current user
  final me = await auth.currentUser();
  print('Current user: ${me.name}');

  // OAuth / Social Login
  // final googleUser = await auth.signInWithOAuth(
  //   provider: 'google',
  //   token: 'google-id-token',
  // );

  // ─── Firestore (Collections & Documents) ──────────────────
  final firestore = app.firestore;

  // ── Document Cache ──
  // Documents are cached in-memory automatically.
  // Disable cache per-instance: firestore.enableCache = false;
  // Manually manage the cache:
  print('Cache entries: ${firestore.cache.length}');
  firestore.cache.clear(); // Clear all cached documents

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
  });
  print('Created document: ${doc.id}');

  // Get a document (cached automatically)
  final fetched =
      await firestore.collection('users').doc('alice-profile').get();
  print('Fetched: ${fetched.data}');

  // Read from cache only (no network call)
  try {
    final cached = await firestore
        .collection('users')
        .doc('alice-profile')
        .get(source: CacheSource.cache);
    print('From cache: ${cached.data}');
  } catch (_) {
    print('Not in cache');
  }

  // Force server read (bypass cache)
  final fresh = await firestore
      .collection('users')
      .doc('alice-profile')
      .get(source: CacheSource.server);
  print('From server: ${fresh.data}');

  // ── Aggregate Queries ──
  final userCount = await firestore.collection('users').count();
  print('Total users: $userCount');

  final totalAge = await firestore.collection('orders').sum('amount');
  print('Total order amount: $totalAge');

  final avgAge = await firestore.collection('users').average('age');
  print('Average age: $avgAge');

  // Aggregate with filters
  final activeCount = await firestore.collection('users').count(
        query: QueryBuilder().where('status', isEqualTo: 'active'),
      );
  print('Active users: $activeCount');

  // ── Collection Group Queries ──
  // Query across ALL 'comments' subcollections (like Firebase collectionGroup)
  final allComments = await firestore.collectionGroup('comments').getDocs();
  print('All comments across collections: ${allComments.total}');

  // ── Batch writes & FieldValue ──
  final batch = firestore.batch();
  batch.set(
      firestore.collection('users').doc('user-1'), {'name': 'Bob', 'age': 25});
  batch.update(firestore.collection('users').doc('alice-profile'),
      {'role': 'super-admin'});
  batch.delete(firestore.collection('users').doc('old-user'));
  await batch.commit();

  await firestore.collection('users').doc('alice-profile').update({
    'login_count': FieldValue.increment(1),
    'tags': FieldValue.arrayUnion(['premium']),
    'temp_field': FieldValue.delete(),
    'last_seen': FieldValue.serverTimestamp(),
  });

  // ── Transactions ──
  await firestore.runTransaction((transaction) async {
    final alice = await transaction.get(
      firestore.collection('accounts').doc('alice'),
    );
    final balance = alice.get<int>('balance') ?? 0;
    transaction.update(
      firestore.collection('accounts').doc('alice'),
      {'balance': balance - 50},
    );
    transaction.update(
      firestore.collection('accounts').doc('bob'),
      {'balance': FieldValue.increment(50)},
    );
  });

  // ── PaginatedResult helpers ──
  final results = await firestore.collection('users').query((q) => q
      .where('age', isGreaterThan: 25)
      .orderBy('created_at', descending: true)
      .select(['name', 'email', 'age'])
      .limit(10)
      .page(1));
  print(
      'Found ${results.total} users (page ${results.currentPage}/${results.lastPage})');
  print('Has next page: ${results.hasNextPage}');
  print('Has prev page: ${results.hasPreviousPage}');
  print('Next page number: ${results.nextPage}');
  print('Is empty: ${results.isEmpty}');

  // Transform results
  final names = results.map((d) => d.get<String>('name') ?? 'Unknown');
  print('Names: ${names.data}');

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
    // Simple progress callback
    onProgress: (sent, total) {
      print('Upload progress: $sent / $total bytes');
    },
  );
  print('Uploaded: ${uploaded.originalName} (${uploaded.sizeHuman})');

  // Upload with stream-based progress tracking (like Firebase UploadTask)
  final videoBytes = Uint8List(1024 * 1024); // 1MB placeholder
  final uploadTask = storage.uploadWithProgress(
    filePath: 'video.mp4',
    fileBytes: videoBytes,
    visibility: 'private',
  );
  uploadTask.onProgress.listen((snapshot) {
    print('Upload: ${(snapshot.progress * 100).toStringAsFixed(1)}% '
        '(${snapshot.state})');
  });
  final videoFile = await uploadTask.future;
  print('Video uploaded: ${videoFile.id}');

  // Get download URL (with expiry checking)
  final urlInfo = await storage.getDownloadUrl(uploaded.id, minutes: 30);
  print('Download URL: ${urlInfo.url}');
  print('URL expired: ${urlInfo.isExpired}');
  print('Expires at: ${urlInfo.expiresAtDate}');

  // List files with pagination
  final files = await storage.list(category: 'avatars', page: 1, perPage: 10);
  print('Files: ${files.data.length}, has more: ${files.hasNextPage}');

  // Batch delete
  // await storage.deleteFiles(['uuid1', 'uuid2']);

  // Copy a file
  // final copy = await storage.copyFile(uploaded.id, visibility: 'private');

  // ─── Notifications ────────────────────────────────────────
  final notifications = app.notifications;

  final notifs = await notifications.list();
  for (final n in notifs.data) {
    print('${n.title}: ${n.body} (read: ${n.isRead})');
  }

  final unread = await notifications.unreadCount();
  print('Unread notifications: $unread');

  await notifications.markAllAsRead();

  // ─── Remote Config ────────────────────────────────────────
  final config = app.remoteConfig;

  // Set defaults (used before first fetch or on failure)
  config.setDefaults({
    'dark_mode_enabled': false,
    'api_rate_limit': 100,
    'welcome_message': 'Hello!',
  });

  // Set minimum fetch interval (like Firebase)
  config.minimumFetchInterval = const Duration(minutes: 5);

  // Fetch and activate in one call
  final configUpdated = await config.fetchAndActivate();
  print('Config updated: $configUpdated');
  print('Fetch status: ${config.lastFetchStatus}');

  // Use cached values (falls back to defaults)
  final darkMode = config.getBool('dark_mode_enabled', defaultValue: false);
  final apiLimit = config.getInt('api_rate_limit', defaultValue: 100);
  print('Dark mode: $darkMode, API limit: $apiLimit');

  // Get all activated values (fetched merged with defaults)
  final allConfig = config.getActivated();
  print('Active config keys: ${allConfig.keys}');

  // Reset throttle for testing
  config.resetThrottle();

  // ─── Analytics ────────────────────────────────────────────
  final analytics = app.analytics;

  // Set user identity (like Firebase setUserId)
  analytics.setUserId('user-${me.id}');

  // Set user properties (sent with every event automatically)
  analytics.setUserProperty(name: 'subscription', value: 'premium');
  analytics.setUserProperty(name: 'account_type', value: 'business');

  // Set default properties
  analytics.setDefaults(
    platform: 'android',
    appVersion: '1.2.0',
    sessionId: 'session-abc123',
  );

  // Log screen views (like Firebase logScreenView)
  await analytics.logScreenView(
    screenName: 'HomeScreen',
    screenClass: 'HomePage',
  );

  // Convenience event helpers
  await analytics.logLogin(method: 'email');
  await analytics.logSignUp(method: 'email');

  // Log custom events (user properties auto-included)
  await analytics.logEvent(
    name: 'purchase',
    properties: {'item_id': '42', 'price': '9.99'},
  );

  // Batch log
  final count = await analytics.logBatch([
    AnalyticsEvent(name: 'item_view', properties: {'item_id': '42'}),
    AnalyticsEvent(
        name: 'add_to_cart', properties: {'item_id': '42', 'qty': '1'}),
    AnalyticsEvent(name: 'checkout_start'),
  ]);
  print('Logged $count events');

  // ─── Realtime ─────────────────────────────────────────────
  final realtime = app.realtime;

  realtime.configure(
    host: 'localhost',
    port: 8080,
    scheme: 'http',
    appKey: 'your-reverb-app-key',
    appSecret: 'your-reverb-app-secret',
  );

  await realtime.connect();
  print('Connected to realtime! Socket ID: ${realtime.socketId}');

  await realtime.onDocumentCreated(1, (data) {
    print('Document created: $data');
  });

  // ─── Firestore Snapshots (like Firebase onSnapshot) ───────
  final usersStream = firestore.collection('users').snapshots(projectId: 1);
  usersStream.listen((docs) {
    print('Users updated: ${docs.length} documents');
  });

  firestore
      .collection('users')
      .doc('alice-profile')
      .snapshots(projectId: 1)
      .listen((doc) {
    if (doc != null) {
      print('Alice updated: ${doc.data}');
    } else {
      print('Alice was deleted');
    }
  });

  // Keep listening...
  print('Listening for realtime events. Press Ctrl+C to stop.');
  await ProcessSignal.sigint.watch().first;

  // Cleanup
  app.dispose();
}
