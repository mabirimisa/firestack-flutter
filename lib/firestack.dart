/// Firestack Flutter SDK
///
/// A complete Flutter SDK for interacting with Firestack backend services.
///
/// ```dart
/// import 'package:firestack/firestack.dart';
///
/// final app = Firestack.initialize(
///   apiKey: 'fsk_your_api_key',
///   baseUrl: 'https://your-server.com',
/// );
///
/// // Auth
/// final auth = app.auth;
/// await auth.signIn(email: 'user@example.com', password: 'password');
///
/// // Firestore
/// final firestore = app.firestore;
/// final docs = await firestore.collection('users').get();
///
/// // Storage
/// final storage = app.storage;
/// final file = await storage.upload(File('photo.jpg'));
///
/// // Realtime
/// app.realtime.subscribe('collections', onDocumentCreated: (data) {
///   print('New document: $data');
/// });
/// ```
library firestack;

export 'src/firestack_app.dart';
export 'src/firestack_client.dart';
export 'src/firestack_auth.dart';
export 'src/firestack_firestore.dart';
export 'src/firestack_storage.dart';
export 'src/firestack_notifications.dart';
export 'src/firestack_remote_config.dart';
export 'src/firestack_analytics.dart';
export 'src/firestack_realtime.dart';
export 'src/firestack_messaging.dart';
export 'src/models/user.dart';
export 'src/models/collection.dart';
export 'src/models/document.dart';
export 'src/models/file_resource.dart';
export 'src/models/notification.dart';
export 'src/models/remote_config_entry.dart';
export 'src/models/query_builder.dart';
export 'src/models/channel.dart';
export 'src/models/message.dart';
export 'src/firestack_exception.dart';
