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
