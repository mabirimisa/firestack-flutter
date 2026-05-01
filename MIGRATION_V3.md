# Migration Guide: v2.x → v3.0

## Overview

Firestack v3.0 introduces UUID-based app identification for enhanced security and privacy. This guide will help you migrate from v2.x to v3.0.

## Why UUIDs?

**Security & Privacy Benefits:**
- 🔒 **Prevents Enumeration**: Can't guess other app IDs (e.g., if you have app_id=1, attackers could try 2, 3, 4...)
- 🔐 **Privacy**: Doesn't expose how many apps exist in your system
- ✅ **Industry Standard**: Public APIs should use UUIDs, not internal database primary keys
- 🌐 **Future-Proof**: UUIDs work across distributed systems

## Breaking Changes

### 1. SDK Initialization

**Before (v2.x):**
```dart
final app = Firestack.initialize(
  apiKey: 'fsk_live_xxxxxxxxxxxx',
  appId: 1,  // ❌ Integer
);
```

**After (v3.0):**
```dart
final app = Firestack.initialize(
  apiKey: 'fsk_live_xxxxxxxxxxxx',
  appId: '550e8400-e29b-41d4-a716-446655440000',  // ✅ UUID string
);
```

### 2. User Model

**Before (v2.x):**
```dart
final user = await auth.currentUser();
print(user.appId);  // int (e.g., 1)
```

**After (v3.0):**
```dart
final user = await auth.currentUser();
print(user.appId);  // String (UUID, e.g., '550e8400-e29b-41d4-a716-446655440000')
```

### 3. API Requests (if using raw HTTP)

If you're making direct API calls, update the request body:

**Before (v2.x):**
```json
{
  "app_id": 1,
  "email": "user@example.com",
  "password": "password123"
}
```

**After (v3.0):**
```json
{
  "app_uuid": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "password": "password123"
}
```

## Migration Steps

### Step 1: Get Your App UUID

1. Log in to your Firestack dashboard
2. Navigate to **Projects** → Your Project → **Apps**
3. Click on your app
4. Copy the **App UUID** from the settings page

**Example UUID format:** `550e8400-e29b-41d4-a716-446655440000`

### Step 2: Update Your Code

Find all occurrences of `Firestack.initialize()` in your codebase and update the `appId` parameter:

```dart
// ❌ Old code
final app = Firestack.initialize(
  apiKey: 'fsk_live_xxxxxxxxxxxx',
  appId: 1,
);

// ✅ New code
final app = Firestack.initialize(
  apiKey: 'fsk_live_xxxxxxxxxxxx',
  appId: '550e8400-e29b-41d4-a716-446655440000',  // Your UUID from dashboard
);
```

### Step 3: Update pubspec.yaml

```yaml
dependencies:
  firestack: ^3.0.0  # Update to v3.0
```

### Step 4: Get Dependencies

```bash
flutter pub get
```

### Step 5: Handle Type Changes

If you have code that explicitly uses `user.appId` as an `int`, update it to `String`:

```dart
// ❌ Old code
void saveUserAppId(int appId) {
  prefs.setInt('app_id', appId);
}
saveUserAppId(user.appId);  // Type error in v3.0

// ✅ New code
void saveUserAppId(String appId) {
  prefs.setString('app_uuid', appId);
}
saveUserAppId(user.appId);  // ✅ Works in v3.0
```

### Step 6: Test

1. **Authentication**: Test sign up and sign in flows
2. **User Data**: Verify user profile loads correctly
3. **Integration**: Test all features that depend on authentication

```dart
// Test authentication
final user = await app.auth.signUp(
  email: 'test@example.com',
  password: 'password123',
  name: 'Test User',
);
print('User app UUID: ${user.appId}');  // Should print UUID

// Test sign in
await app.auth.signIn(
  email: 'test@example.com',
  password: 'password123',
);

// Test current user
final me = await app.auth.currentUser();
print('Logged in as: ${me.email}');
```

## Common Issues

### Issue: Compile Error "The argument type 'int' can't be assigned to the parameter type 'String'"

**Cause:** You're still passing an integer `appId` to `Firestack.initialize()`.

**Solution:** Replace the integer with your app's UUID string:
```dart
// ❌ Wrong
appId: 1

// ✅ Correct
appId: '550e8400-e29b-41d4-a716-446655440000'
```

### Issue: "Invalid UUID format" error

**Cause:** The `appId` string is not a valid UUID.

**Solution:** Copy the exact UUID from your Firestack dashboard. Valid format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Issue: Authentication fails with 404

**Cause:** Your Firestack server backend hasn't been updated to v3.0.

**Solution:** 
1. Update your Firestack server to v3.0
2. Run database migrations: `php artisan migrate`
3. Verify the `app_uuid` column exists in the `app_users` table

## Rollback Plan

If you need to rollback to v2.x:

```yaml
dependencies:
  firestack: ^2.0.0  # Rollback to v2.0
```

Then restore integer `appId`:
```dart
final app = Firestack.initialize(
  apiKey: 'fsk_live_xxxxxxxxxxxx',
  appId: 1,  // Integer again
);
```

## Support

If you encounter issues during migration:

1. Check the [CHANGELOG.md](CHANGELOG.md) for complete list of changes
2. Review your Firestack dashboard for the correct UUID
3. Ensure your backend server is updated to v3.0
4. Open an issue on GitHub with migration details

## Summary Checklist

- [ ] Obtained app UUID from Firestack dashboard
- [ ] Updated all `Firestack.initialize()` calls to use UUID string
- [ ] Updated `pubspec.yaml` to `firestack: ^3.0.0`
- [ ] Ran `flutter pub get`
- [ ] Updated code that uses `user.appId` to handle String type
- [ ] Tested authentication flows (sign up, sign in, profile)
- [ ] Verified backend server is updated to v3.0

---

**Questions?** Open an issue or check the [documentation](https://your-docs-url.com).
