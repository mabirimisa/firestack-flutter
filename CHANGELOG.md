## 3.2.0 - Verification flow + OAuth + push topics

### Authentication
- **NEW**: `auth.sendRegistrationCode()` / `auth.verifyAndRegister()` — the
  full email-code based registration flow. Replaces the prior single-step
  `signUp()` for apps that want email verification before account creation.
- **NEW**: `auth.sendEmailVerificationCode()` / `auth.verifyEmail(code:)`
  for verifying the email of a signed-in user.
- **NEW**: `auth.sendPasswordResetCode()` + `auth.verifyAndResetPassword()`
  6-digit code-based password reset, scoped per app.
- **NEW**: `auth.resendCode(email:, type:)` to resend any code.
- **DEPRECATED**: `changePassword`, `deleteAccount`, `refreshToken`,
  `sendEmailVerification`, `resetPassword(token:)` — either replaced by
  the new code flow or not yet implemented on the backend.

### Push Notifications
- **NEW**: `notifications.subscribeToTopic(topic, deviceId:)`,
  `notifications.unsubscribeFromTopic()`, and `notifications.listTopics()`
  now backed by the new per-device `topics` JSON column on the server.
- **DEPRECATED**: `notifications.unreadCount()`, `delete()`, `deleteAll()`
  — endpoints not yet implemented on the backend.

### OAuth (Social Sign-In)
- **NEW**: Backend now implements `POST /auth/oauth/{provider}` for sign-in
  and `POST /auth/oauth/{provider}/link` / `DELETE .../unlink` for account
  linking. **Google** is supported out of the box (verified via Google's
  tokeninfo endpoint). Other providers return `501 Not Implemented`.
- The existing SDK methods `signInWithOAuth()`, `linkOAuthProvider()`, and
  `unlinkOAuthProvider()` now work end-to-end with the backend.

## 3.1.0 - Per-app device tracking

### Push Notifications & Devices

- **NEW**: Devices are now tracked per app user. Every successful `signIn` /
  `signUp` can include an optional `device:` payload that the backend stores
  against the authenticated `AppUser` and returns on `GET /devices`.
- **NEW**: `auth.registerDevice()`, `auth.listDevices()`, `auth.unregisterDevice()`
  for explicit device lifecycle management.
- **CHANGED**: `notifications.registerDevice()` and `notifications.unregisterDevice()`
  now hit the new `/devices` and `/devices/unregister` endpoints (previously
  `/auth/devices` / `/auth/devices/remove`).
- **CHANGED**: `notifications.configure()` accepts richer device metadata
  (`deviceId`, `deviceName`, `osVersion`, `appVersion`, `model`) which is
  forwarded to the server. `appId` is now optional.
- The backend project Notifications page lists all registered devices and
  push targeting can be scoped to specific devices.

## 3.0.0 - **BREAKING CHANGES** (UUID Migration)

### App UUID Migration

**BREAKING CHANGE**: App identification now uses secure UUIDs instead of integer IDs for enhanced security and privacy.

#### Why This Change?
- ✅ **Security**: UUIDs prevent enumeration attacks (can't guess other app IDs like 2, 3, 4...)
- ✅ **Privacy**: Doesn't expose how many apps exist in your Firestack instance
- ✅ **Industry Standard**: Public-facing APIs should use UUIDs, not internal database IDs

#### What Changed

**1. SDK Initialization**
- **BREAKING**: `appId` parameter is now `String` (UUID) instead of `int`
- Get your app UUID from the Firestack dashboard → Apps → Settings
```dart
// Before (v2.x)
final app = Firestack.initialize(
  apiKey: 'fsk_key',
  appId: 1,  // ❌ Integer ID
);

// After (v3.0)
final app = Firestack.initialize(
  apiKey: 'fsk_key',
  appId: '550e8400-e29b-41d4-a716-446655440000',  // ✅ UUID
);
```

**2. User Model**
- **BREAKING**: `FirestackUser.appId` is now `String` (UUID) instead of `int`
- JSON key changed from `app_id` to `app_uuid`

**3. API Requests**
- **BREAKING**: Registration/login now send `app_uuid` instead of `app_id`
```json
// Before (v2.x)
{"app_id": 1, "email": "...", "password": "..."}

// After (v3.0)
{"app_uuid": "550e8400-e29b-41d4-a716-446655440000", "email": "...", "password": "..."}
```

#### Migration Steps

1. **Get your app UUID** from Firestack dashboard
2. **Update initialization** to use UUID string
3. **Run tests** to ensure authentication works
4. See [MIGRATION_V3.md](MIGRATION_V3.md) for detailed instructions

---

## 2.0.0 - **BREAKING CHANGES**

### App User Separation & Multi-Tenancy

**BREAKING CHANGE**: The SDK now requires an `appId` parameter to support proper multi-tenant app user isolation. Each project maintains its own separate user base.

#### Authentication
- **BREAKING**: `Firestack.initialize()` now requires `appId` parameter
- **BREAKING**: `signUp()` no longer requires `passwordConfirmation` parameter
- **BREAKING**: `signUp()` changed parameter order - `name` is now optional
- **BREAKING**: Authentication endpoints changed:
  - `/api/v1/auth/register` → `/api/v1/register`
  - `/api/v1/auth/login` → `/api/v1/login`
  - `/api/v1/auth/user` → `/api/v1/me`
  - `/api/v1/auth/logout` → `/api/v1/logout`
- **BREAKING**: API responses simplified - removed `data` wrapper for user objects

#### User Model
- **NEW**: `FirestackUser.projectId` - The project this user belongs to
- **NEW**: `FirestackUser.appId` - The app this user belongs to
- **NEW**: `FirestackUser.customClaims` - Map for role-based access control
- **NEW**: `FirestackUser.metadata` - Map for additional user data
- **NEW**: `user.isPending` - Check if user status is pending
- **NEW**: `user.isDisabled` - Check if user status is disabled
- **NEW**: `user.hasClaim(claim)` - Check if user has a specific custom claim
- **NEW**: `user.getClaim<T>(claim)` - Get custom claim value with type casting
- **NEW**: `user.getMetadata<T>(key)` - Get metadata value with type casting

#### Migration Path
See [MIGRATION_V2.md](MIGRATION_V2.md) for complete migration instructions.

**Example Before (v1.x):**
```dart
final app = Firestack.initialize(apiKey: 'fsk_key');
await auth.signUp(
  name: 'John',
  email: 'john@example.com',
  password: 'pass',
  passwordConfirmation: 'pass',
);
```

**Example After (v2.0):**
```dart
final app = Firestack.initialize(apiKey: 'fsk_key', appId: 1);
await auth.signUp(
  email: 'john@example.com',
  password: 'pass',
  name: 'John', // Optional
);
```

---

## 1.2.0

### Authentication
- Auth state stream (`authStateChanges`) — Firebase `onAuthStateChanged` equivalent
- OAuth / social login (`signInWithOAuth`, `linkOAuthProvider`, `unlinkOAuthProvider`)
- Password management: `sendPasswordResetEmail`, `resetPassword`, `changePassword`
- Email verification: `sendEmailVerification`
- Token persistence callback (`setTokenPersistence`)
- Token refresh (`refreshToken`)
- Account deletion (`deleteAccount`)

### Firestore
- `FieldValue` operations: `increment`, `decrement`, `arrayUnion`, `arrayRemove`, `serverTimestamp`, `delete`
- Batch writes (`WriteBatch` with `set`, `update`, `delete`, `commit`)
- Transactions (`runTransaction` with read-then-write semantics)
- Aggregate queries: `count()`, `sum(field)`, `average(field)`
- Collection group queries (`collectionGroup`)
- In-memory document cache with TTL and LRU eviction (`FirestackCache`, `CacheSource`)
- Realtime document/collection snapshots (`snapshots()` stream)
- `PaginatedResult` improvements: `hasNextPage`, `hasPreviousPage`, `isEmpty`, `isNotEmpty`, `count`, `map<R>()`

### Storage
- Upload progress callback (`onProgress` parameter)
- Stream-based upload progress (`uploadWithProgress`, `UploadTask`, `UploadSnapshot`)
- Batch delete (`deleteFiles`)
- File copy (`copyFile`)
- Download URL expiry check (`FileDownloadUrl.isExpired`)

### Notifications
- Full push notification lifecycle: permission handler, device token provider, foreground message handling
- `NotificationAuthorizationStatus` and `NotificationSettings`
- `requestPermission()` with auto device registration
- Topic subscriptions (`subscribeToTopic`, `unsubscribeFromTopic`)
- `onMessage` and `onMessageStream` for foreground push
- `unreadCount()`, `deleteAll()`

### Remote Config
- Fetch throttling with configurable `minimumFetchInterval`
- `fetchAndActivate()` convenience method
- `setDefaults()` for fallback values before first fetch
- `getActivated()` for fetched-but-not-yet-synced values
- `RemoteConfigFetchStatus` enum with throttle detection
- `lastFetchStatus` and `lastFetchTime` tracking

### Analytics
- `setUserId()` for user identity (auto-merged into all events)
- `setUserProperty()` with `userProperties` getter
- `logScreenView()` for screen tracking
- `logLogin()` and `logSignUp()` convenience methods

### Models
- `User`: `copyWith()`, `==`/`hashCode` by id, DateTime parsing for timestamps, convenience getters
- `Document`: `copyWith()`, `hasField()`, `==`/`hashCode` by uuid
- `QueryBuilder`: `isNull`, `arrayContains`, `search()`, `select()`, `page()` operators

### Client
- HTTP retry with exponential backoff (429, 5xx, timeout)
- Configurable request timeout and max retries
- `FirestackLogLevel` enum (none, error, info, verbose)

### Core
- Multiple named app instances (`Firestack.initialize(name: ...)`, `Firestack.instanceFor(name: ...)`)
- `dispose()` cleans up auth streams, notification handlers, realtime connections

## 1.1.0

- **Messaging**: Full instant messaging — channels (group, direct, project), messages (text, image, file, reply, system), reactions (emoji), read receipts, typing indicators, message search, mute/pin
- **Realtime Engine**: Auto-reconnect with exponential backoff, heartbeat ping/pong, connection state stream, offline event queue, snapshot streams (Firestore onSnapshot-like API), message/typing/reaction streams
- New models: `FirestackChannel`, `FirestackMessage`, `FirestackReaction`, `FirestackMessageSender`
- New `ConnectionState` enum for connection state tracking
- Client-side typing whisper events (no server roundtrip)
- `off()` and `removeAllListeners()` for granular listener management

## 1.0.0

- Initial release
- Authentication: register, sign in/out, profile management, device registration
- Firestore: collections CRUD, documents CRUD, queries with filters, subcollections
- Storage: file upload, download, signed URLs, metadata
- Notifications: list, mark as read
- Remote Config: fetch all/single, type-safe cached getters, feature flags
- Analytics: event logging, batch events, default properties
- Realtime: WebSocket listeners via Reverb (Pusher protocol)
