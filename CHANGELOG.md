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
