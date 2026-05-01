import 'dart:async';
import 'firestack_client.dart';
import 'models/user.dart';

/// Callback for persisting or clearing the auth token.
///
/// Implement this to store the token in secure storage (e.g. flutter_secure_storage).
typedef TokenPersistenceCallback = Future<void> Function(String? token);

/// Authentication service for Firestack.
///
/// ```dart
/// final auth = app.auth;
///
/// // Listen to auth state changes
/// auth.authStateChanges.listen((user) {
///   if (user != null) {
///     print('Signed in as ${user.name}');
///   } else {
///     print('Signed out');
///   }
/// });
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
/// // Password reset
/// await auth.sendPasswordResetEmail(email: 'john@example.com');
///
/// // Get current user
/// final me = await auth.currentUser();
///
/// // Sign out
/// await auth.signOut();
/// ```
class FirestackAuth {
  final FirestackClient _client;
  final int appId;

  FirestackUser? _cachedUser;
  String? _token;
  TokenPersistenceCallback? _onTokenChanged;

  final StreamController<FirestackUser?> _authStateController =
      StreamController<FirestackUser?>.broadcast();

  FirestackAuth({
    required FirestackClient client,
    required this.appId,
  }) : _client = client;

  /// Stream of auth state changes. Emits the user on sign-in and null on sign-out.
  Stream<FirestackUser?> get authStateChanges => _authStateController.stream;

  /// Set a callback to persist or clear the auth token (e.g. to secure storage).
  void setTokenPersistence(TokenPersistenceCallback callback) {
    _onTokenChanged = callback;
  }

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _token != null;

  /// The current cached user (null if not authenticated).
  FirestackUser? get user => _cachedUser;

  /// The current auth token.
  String? get token => _token;

  Future<void> _setAuth(String token, FirestackUser user) async {
    _token = token;
    _client.setToken(token);
    _cachedUser = user;
    _authStateController.add(user);
    await _onTokenChanged?.call(token);
  }

  Future<void> _clearAuth() async {
    _token = null;
    _cachedUser = null;
    _client.setToken(null);
    _authStateController.add(null);
    await _onTokenChanged?.call(null);
  }

  /// Register a new user.
  Future<FirestackUser> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _client.post('/register', body: {
      'app_id': appId,
      'email': email,
      'password': password,
      if (name != null) 'name': name,
    });

    final user = FirestackUser.fromJson(response['user'] as Map<String, dynamic>);
    await _setAuth(response['token'] as String, user);
    return user;
  }

  /// Sign in with email and password.
  Future<FirestackUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.post('/login', body: {
      'app_id': appId,
      'email': email,
      'password': password,
    });

    final user = FirestackUser.fromJson(response['user'] as Map<String, dynamic>);
    await _setAuth(response['token'] as String, user);
    return user;
  }

  /// Sign in with an existing token (restore session).
  ///
  /// Call [currentUser] after this to fetch and cache the user profile.
  void signInWithToken(String token) {
    _token = token;
    _client.setToken(token);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await _client.post('/logout');
    } finally {
      await _clearAuth();
    }
  }

  /// Get the current authenticated user profile.
  Future<FirestackUser> currentUser() async {
    final response = await _client.get('/me');
    _cachedUser = FirestackUser.fromJson(response as Map<String, dynamic>);
    _authStateController.add(_cachedUser);
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

    final response = await _client.put('/me', body: body);
    _cachedUser = FirestackUser.fromJson(response as Map<String, dynamic>);
    _authStateController.add(_cachedUser);
    return _cachedUser!;
  }

  /// Send a password reset email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.post('/auth/forgot-password', body: {
      'email': email,
    });
  }

  /// Reset password with a token (from the reset email).
  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post('/auth/reset-password', body: {
      'token': token,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  /// Change the current user's password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _client.put('/auth/password', body: {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': newPasswordConfirmation,
    });
  }

  /// Send an email verification link.
  Future<void> sendEmailVerification() async {
    await _client.post('/auth/email/verify');
  }

  /// Delete the currently authenticated account.
  ///
  /// Requires the current password for confirmation.
  Future<void> deleteAccount({required String password}) async {
    await _client.post('/auth/delete', body: {
      'password': password,
    });
    await _clearAuth();
  }

  /// Refresh the auth token.
  Future<String> refreshToken() async {
    final response = await _client.post('/auth/refresh');
    final data = response['data'] as Map<String, dynamic>;
    final newToken = data['token'] as String;
    _token = newToken;
    _client.setToken(newToken);
    await _onTokenChanged?.call(newToken);
    return newToken;
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

  /// Remove a registered device.
  Future<void> unregisterDevice({required String token}) async {
    await _client.post('/auth/devices/remove', body: {
      'token': token,
    });
  }

  // ─── OAuth / Social Login ──────────────────────────────────

  /// Sign in with an OAuth provider (Google, Apple, GitHub, etc.).
  ///
  /// The [token] is the OAuth access token or ID token obtained from the
  /// provider's sign-in flow (e.g. google_sign_in, sign_in_with_apple).
  ///
  /// ```dart
  /// // After Google Sign-In:
  /// final googleAuth = await googleUser.authentication;
  /// final user = await auth.signInWithOAuth(
  ///   provider: 'google',
  ///   token: googleAuth.idToken!,
  /// );
  ///
  /// // After Apple Sign-In:
  /// final user = await auth.signInWithOAuth(
  ///   provider: 'apple',
  ///   token: appleCredential.identityToken!,
  /// );
  /// ```
  Future<FirestackUser> signInWithOAuth({
    required String provider,
    required String token,
    String? name,
    String? email,
    String? avatar,
  }) async {
    final response = await _client.post('/auth/oauth/$provider', body: {
      'token': token,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (avatar != null) 'avatar': avatar,
    });

    final data = response['data'] as Map<String, dynamic>;
    final user = FirestackUser.fromJson(data['user'] as Map<String, dynamic>);
    await _setAuth(data['token'] as String, user);
    return user;
  }

  /// Link an OAuth provider to the current account.
  Future<void> linkOAuthProvider({
    required String provider,
    required String token,
  }) async {
    await _client.post('/auth/oauth/$provider/link', body: {
      'token': token,
    });
  }

  /// Unlink an OAuth provider from the current account.
  Future<void> unlinkOAuthProvider({required String provider}) async {
    await _client.delete('/auth/oauth/$provider/unlink');
  }

  /// Dispose the auth state stream.
  void dispose() {
    _authStateController.close();
  }
}
