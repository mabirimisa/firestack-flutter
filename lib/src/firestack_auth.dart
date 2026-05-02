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
  final String appId;  // Changed from int to String (UUID)

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
  ///
  /// Pass an optional [device] map (`token`, `platform`, `device_id`,
  /// `device_name`, `os_version`, `app_version`, `model`) and the backend
  /// will record this device for push notifications as part of registration.
  Future<FirestackUser> signUp({
    required String email,
    required String password,
    String? name,
    Map<String, dynamic>? device,
  }) async {
    final response = await _client.post('/register', body: {
      'app_uuid': appId,  // Send UUID
      'email': email,
      'password': password,
      if (name != null) 'name': name,
      if (device != null) 'device': device,
    });

    final user = FirestackUser.fromJson(response['user'] as Map<String, dynamic>);
    await _setAuth(response['token'] as String, user);
    return user;
  }

  /// Sign in with email and password.
  ///
  /// Pass an optional [device] map to register/refresh the device's push
  /// token in the same call.
  Future<FirestackUser> signIn({
    required String email,
    required String password,
    Map<String, dynamic>? device,
  }) async {
    final response = await _client.post('/login', body: {
      'app_uuid': appId,  // Send UUID
      'email': email,
      'password': password,
      if (device != null) 'device': device,
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
    _cachedUser = FirestackUser.fromJson(response);
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
    _cachedUser = FirestackUser.fromJson(response);
    _authStateController.add(_cachedUser);
    return _cachedUser!;
  }

  /// Send a password reset code to the user's email (6-digit code).
  ///
  /// Pair with [verifyAndResetPassword] to complete the flow.
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.post('/auth/send-password-reset-code', body: {
      'email': email,
      'app_uuid': appId,
    });
  }

  /// Alias of [sendPasswordResetEmail] using the new naming.
  Future<void> sendPasswordResetCode({required String email}) =>
      sendPasswordResetEmail(email: email);

  /// Verify the password-reset code and set a new password.
  Future<void> verifyAndResetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post('/auth/verify-and-reset-password', body: {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'app_uuid': appId,
    });
  }

  /// Legacy token-based password reset. Kept for backward compatibility but
  /// the server now uses 6-digit codes — prefer [verifyAndResetPassword].
  @Deprecated('Use verifyAndResetPassword(code:) instead')
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

  // ─── Email verification (code-based) ────────────────────────────

  /// Request a registration code to be emailed to the user.
  ///
  /// This is the first step of the two-step registration flow:
  /// 1. [sendRegistrationCode] → user receives a 6-digit code
  /// 2. [verifyAndRegister]    → code + password creates the account
  Future<void> sendRegistrationCode({
    required String email,
    required String name,
  }) async {
    await _client.post('/auth/send-verification-code', body: {
      'email': email,
      'name': name,
      'app_uuid': appId,
    });
  }

  /// Complete registration by verifying the code received via email.
  /// On success the user is created and the session token is stored.
  Future<FirestackUser> verifyAndRegister({
    required String email,
    required String code,
    required String name,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post('/auth/verify-and-register', body: {
      'email': email,
      'code': code,
      'name': name,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'app_uuid': appId,
    });
    final user = FirestackUser.fromJson(response['user'] as Map<String, dynamic>);
    await _setAuth(response['token'] as String, user);
    return user;
  }

  /// Send an email-verification code to the currently signed-in user.
  Future<void> sendEmailVerificationCode() async {
    await _client.post('/auth/send-email-verification', body: {
      'app_uuid': appId,
    });
  }

  /// Submit the 6-digit code to mark the current user's email verified.
  Future<void> verifyEmail({required String code}) async {
    await _client.post('/auth/verify-email', body: {
      'code': code,
      'app_uuid': appId,
    });
  }

  /// Resend a verification code of the given type. [type] is one of
  /// `registration`, `email_verification`, or `password_reset`.
  Future<void> resendCode({
    required String email,
    required String type,
  }) async {
    await _client.post('/auth/resend-code', body: {
      'email': email,
      'type': type,
      'app_uuid': appId,
    });
  }

  /// Change the current user's password.
  ///
  /// **Not yet implemented on the server.** Tracked for a future release.
  @Deprecated('Endpoint not yet implemented on the backend')
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
  ///
  /// Replaced by the code-based flow — use [sendEmailVerificationCode].
  @Deprecated('Use sendEmailVerificationCode() + verifyEmail(code:)')
  Future<void> sendEmailVerification() async {
    await sendEmailVerificationCode();
  }

  /// Delete the currently authenticated account.
  ///
  /// **Not yet implemented on the server.** Tracked for a future release.
  @Deprecated('Endpoint not yet implemented on the backend')
  Future<void> deleteAccount({required String password}) async {
    await _client.post('/auth/delete', body: {
      'password': password,
    });
    await _clearAuth();
  }

  /// Refresh the auth token.
  ///
  /// **Not yet implemented on the server.** Sanctum tokens are long-lived.
  @Deprecated('Endpoint not yet implemented on the backend')
  Future<String> refreshToken() async {
    final response = await _client.post('/auth/refresh');
    final data = response['data'] as Map<String, dynamic>;
    final newToken = data['token'] as String;
    _token = newToken;
    _client.setToken(newToken);
    await _onTokenChanged?.call(newToken);
    return newToken;
  }

  /// Register or refresh a device for push notifications.
  ///
  /// The device is associated with the currently signed-in app user. Calling
  /// this again with the same `deviceId` will refresh the token and metadata
  /// rather than create a duplicate row.
  ///
  /// ```dart
  /// await auth.registerDevice(
  ///   token: fcmToken,
  ///   platform: 'android', // android | ios | web
  ///   deviceId: 'unique-installation-id',
  ///   deviceName: 'Pixel 8 Pro',
  ///   osVersion: '15',
  ///   appVersion: '1.4.2',
  ///   model: 'Pixel 8 Pro',
  /// );
  /// ```
  Future<Map<String, dynamic>> registerDevice({
    required String token,
    required String platform,
    String? deviceId,
    String? deviceName,
    String? osVersion,
    String? appVersion,
    String? model,
  }) async {
    final response = await _client.post('/devices', body: {
      'token': token,
      'platform': platform,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (osVersion != null) 'os_version': osVersion,
      if (appVersion != null) 'app_version': appVersion,
      if (model != null) 'model': model,
    });
    return Map<String, dynamic>.from(response);
  }

  /// List the authenticated user's registered devices.
  Future<List<Map<String, dynamic>>> listDevices() async {
    final response = await _client.get('/devices');
    final list = response['devices'] as List? ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Mark a registered device inactive (it will stop receiving pushes).
  ///
  /// Provide either [token] or [deviceId] (or both).
  Future<void> unregisterDevice({String? token, String? deviceId}) async {
    if (token == null && deviceId == null) {
      throw ArgumentError('Provide either token or deviceId.');
    }
    await _client.post('/devices/unregister', body: {
      if (token != null) 'token': token,
      if (deviceId != null) 'device_id': deviceId,
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
