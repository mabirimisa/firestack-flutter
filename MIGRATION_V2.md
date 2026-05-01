# Firestack Flutter SDK v2.0 - Migration Guide

## Breaking Changes: App User Separation

Version 2.0 introduces a major architectural change to support proper multi-tenancy. Each project now has its own isolated user base.

### What Changed

**Before (v1.x):**
```dart
final app = Firestack.initialize(
  apiKey: 'fsk_your_api_key',
);

await auth.signUp(
  name: 'John',
  email: 'john@example.com',
  password: 'password123',
  passwordConfirmation: 'password123',
);
```

**After (v2.0):**
```dart
final app = Firestack.initialize(
  apiKey: 'fsk_your_api_key',
  appId: 1, // REQUIRED: Your app ID from dashboard
);

await auth.signUp(
  email: 'john@example.com',
  password: 'password123',
  name: 'John', // Optional
);
```

### Key Changes

#### 1. App ID Required
The `appId` parameter is now **required** when initializing Firestack:

```dart
final app = Firestack.initialize(
  apiKey: 'fsk_your_api_key',
  appId: 1, // Get this from your Firestack dashboard
);
```

#### 2. Simplified Registration
- No more `passwordConfirmation` parameter
- `name` is now optional
- Automatically scoped to your app/project

```dart
// Minimal registration
await auth.signUp(
  email: 'user@example.com',
  password: 'password123',
);

// With name
await auth.signUp(
  email: 'user@example.com',
  password: 'password123',
  name: 'John Doe',
);
```

#### 3. Updated User Model
The `FirestackUser` model now includes:

```dart
class FirestackUser {
  final int id;
  final int projectId;      // NEW: Project ID
  final int appId;          // NEW: App ID
  final String name;
  final String email;
  final String? avatar;
  final String? phone;
  final String status;      // 'active', 'pending', 'disabled'
  final Map<String, dynamic>? customClaims;  // NEW: Custom claims
  final Map<String, dynamic>? metadata;      // NEW: User metadata
  // ... other fields
}
```

#### 4. New User Helper Methods

```dart
final user = await auth.currentUser();

// Check status
if (user.isActive) { }
if (user.isPending) { }
if (user.isDisabled) { }

// Custom claims (for role-based access)
if (user.hasClaim('admin')) {
  // User has admin claim
}

final role = user.getClaim<String>('role');
final isPremium = user.getClaim<bool>('premium');

// Metadata
final onboardingComplete = user.getMetadata<bool>('onboarding_complete');
```

#### 5. Updated API Endpoints

The SDK now uses new endpoints that are scoped to app users:

- `POST /api/v1/register` (was `/api/v1/auth/register`)
- `POST /api/v1/login` (was `/api/v1/auth/login`)
- `POST /api/v1/logout` (was `/api/v1/auth/logout`)
- `GET /api/v1/me` (was `/api/v1/auth/user`)
- `PUT /api/v1/me` (was `/api/v1/auth/user`)

### Migration Steps

1. **Update SDK Version**
   ```yaml
   dependencies:
     firestack: ^2.0.0
   ```

2. **Get Your App ID**
   - Login to your Firestack dashboard
   - Navigate to your project
   - Go to Apps section
   - Copy your app ID

3. **Update Initialization Code**
   ```dart
   // Add appId parameter
   final app = Firestack.initialize(
     apiKey: 'fsk_your_api_key',
     appId: 1, // Your app ID
   );
   ```

4. **Update Registration Calls**
   ```dart
   // Remove passwordConfirmation parameter
   await auth.signUp(
     email: email,
     password: password,
     name: name, // Now optional
   );
   ```

5. **Update User Model References**
   If you're using the user model directly, update to handle new fields:
   ```dart
   final user = await auth.currentUser();
   print('Project: ${user.projectId}');
   print('App: ${user.appId}');
   
   // Use new helper methods
   if (user.hasClaim('admin')) {
     // Handle admin user
   }
   ```

### Benefits

- **Data Isolation**: Each project has its own user base
- **Security**: No cross-project data leakage
- **Scalability**: Better query performance per project
- **Custom Claims**: Built-in support for role-based access
- **Metadata**: Store additional user data flexibly

### Backward Compatibility

This is a **breaking change**. Version 1.x apps will not work with v2.0 without updating the initialization code and registration calls.

If you need to maintain v1.x compatibility, pin your dependency:
```yaml
dependencies:
  firestack: ^1.0.0
```

### Need Help?

- Check the [API Documentation](https://docs.firestack.co.za)
- Read the [Complete Guide](../APP_USER_SEPARATION_GUIDE.md)
- Open an issue on GitHub
