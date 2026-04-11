import 'firestack_client.dart';
import 'models/user.dart';

/// Authentication service for Firestack.
///
/// ```dart
/// final auth = app.auth;
///
/// // Register
/// final user = await auth.signUp(
///   name: 'John',
///   email: 'john@example.com',
///   password: 'password123',
/// );
///
/// // Sign in
/// final user = await auth.signIn(
///   email: 'john@example.com',
///   password: 'password123',
/// );
///
/// // Get current user
/// final me = await auth.currentUser();
///
/// // Sign out
/// await auth.signOut();
/// ```
class FirestackAuth {
  final FirestackClient _client;

  FirestackUser? _cachedUser;
  String? _token;

  FirestackAuth({required FirestackClient client}) : _client = client;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _token != null;

  /// The current cached user (null if not authenticated).
  FirestackUser? get user => _cachedUser;

  /// The current auth token.
  String? get token => _token;

  /// Register a new user.
  Future<FirestackUser> signUp({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });

    final data = response['data'] as Map<String, dynamic>;
    _token = data['token'] as String;
    _client.setToken(_token);
    _cachedUser = FirestackUser.fromJson(data['user'] as Map<String, dynamic>);
    return _cachedUser!;
  }

  /// Sign in with email and password.
  Future<FirestackUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    final data = response['data'] as Map<String, dynamic>;
    _token = data['token'] as String;
    _client.setToken(_token);
    _cachedUser = FirestackUser.fromJson(data['user'] as Map<String, dynamic>);
    return _cachedUser!;
  }

  /// Sign in with an existing token (restore session).
  void signInWithToken(String token) {
    _token = token;
    _client.setToken(token);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.post('/auth/logout');
    _token = null;
    _cachedUser = null;
    _client.setToken(null);
  }

  /// Get the current authenticated user profile.
  Future<FirestackUser> currentUser() async {
    final response = await _client.get('/auth/user');
    _cachedUser =
        FirestackUser.fromJson(response['data'] as Map<String, dynamic>);
    return _cachedUser!;
  }

  /// Update the current user's profile.
  Future<FirestackUser> updateProfile({
    String? name,
    String? phone,
    String? avatar,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (avatar != null) body['avatar'] = avatar;

    final response = await _client.put('/auth/user', body: body);
    _cachedUser =
        FirestackUser.fromJson(response['data'] as Map<String, dynamic>);
    return _cachedUser!;
  }

  /// Register a device for push notifications.
  Future<void> registerDevice({
    required String token,
    required String platform,
    required String appId,
    String? deviceName,
  }) async {
    await _client.post('/auth/devices', body: {
      'token': token,
      'platform': platform,
      'app_id': appId,
      if (deviceName != null) 'device_name': deviceName,
    });
  }
}
