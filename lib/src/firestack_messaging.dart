import 'firestack_client.dart';
import 'firestack_firestore.dart';
import 'models/channel.dart';
import 'models/message.dart';

/// Instant messaging service for Firestack.
///
/// Provides channel management, message CRUD, reactions, read receipts,
/// typing indicators, and member management.
///
/// ```dart
/// final messaging = app.messaging;
///
/// // List channels
/// final channels = await messaging.channels(projectId: 1);
///
/// // Create a group channel
/// final channel = await messaging.createChannel(
///   projectId: 1,
///   name: 'general',
///   memberIds: [2, 3],
/// );
///
/// // Send a message
/// final msg = await messaging.sendMessage(
///   channelId: channel.id,
///   body: 'Hello world!',
/// );
///
/// // React to a message
/// await messaging.addReaction(messageId: msg.id, emoji: '👍');
///
/// // Mark channel as read
/// await messaging.markAsRead(channelId: channel.id);
/// ```
class FirestackMessaging {
  final FirestackClient _client;

  FirestackMessaging({required FirestackClient client}) : _client = client;

  // ─── Channels ────────────────────────────────────────────────

  /// List channels the authenticated user belongs to.
  Future<PaginatedResult<FirestackChannel>> channels({
    required int projectId,
    int perPage = 20,
    int page = 1,
  }) async {
    final response = await _client.get('channels', queryParams: {
      'project_id': projectId.toString(),
      'per_page': perPage.toString(),
      'page': page.toString(),
    });
    final items = (response['data'] as List)
        .map((e) => FirestackChannel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = response['meta'] as Map<String, dynamic>? ?? {};
    return PaginatedResult<FirestackChannel>(
      data: items,
      currentPage: meta['current_page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Create a group or project channel.
  Future<FirestackChannel> createChannel({
    required int projectId,
    required String name,
    String? description,
    String type = 'group',
    bool isPrivate = false,
    Map<String, dynamic>? metadata,
    List<int>? memberIds,
  }) async {
    final response = await _client.post('channels', body: {
      'project_id': projectId,
      'name': name,
      if (description != null) 'description': description,
      'type': type,
      'is_private': isPrivate,
      if (metadata != null) 'metadata': metadata,
      if (memberIds != null) 'member_ids': memberIds,
    });
    return FirestackChannel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Create or retrieve a direct message channel with another user.
  Future<FirestackChannel> createDirectChannel({
    required int projectId,
    required int userId,
  }) async {
    final response = await _client.post('channels/direct', body: {
      'project_id': projectId,
      'user_id': userId,
    });
    return FirestackChannel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Get a single channel by UUID.
  Future<FirestackChannel> getChannel(String channelId) async {
    final response = await _client.get('channels/$channelId');
    return FirestackChannel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Update a channel.
  Future<FirestackChannel> updateChannel(
    String channelId, {
    String? name,
    String? description,
    String? avatar,
    bool? isArchived,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _client.patch('channels/$channelId', body: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatar != null) 'avatar': avatar,
      if (isArchived != null) 'is_archived': isArchived,
      if (metadata != null) 'metadata': metadata,
    });
    return FirestackChannel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Delete a channel.
  Future<void> deleteChannel(String channelId) async {
    await _client.delete('channels/$channelId');
  }

  // ─── Members ─────────────────────────────────────────────────

  /// List members of a channel.
  Future<List<Map<String, dynamic>>> getMembers(String channelId) async {
    final response = await _client.get('channels/$channelId/members');
    return (response['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Add a member to a channel.
  Future<void> addMember(
    String channelId, {
    required int userId,
    String role = 'member',
  }) async {
    await _client.post('channels/$channelId/members', body: {
      'user_id': userId,
      'role': role,
    });
  }

  /// Remove a member from a channel.
  Future<void> removeMember(String channelId, {required int userId}) async {
    await _client.delete('channels/$channelId/members/$userId');
  }

  /// Update a member's role.
  Future<void> updateMemberRole(
    String channelId, {
    required int userId,
    required String role,
  }) async {
    await _client.patch('channels/$channelId/members/$userId/role', body: {
      'role': role,
    });
  }

  // ─── Messages ────────────────────────────────────────────────

  /// List messages in a channel (newest first).
  Future<PaginatedResult<FirestackMessage>> messages(
    String channelId, {
    int perPage = 50,
    int? beforeId,
    int page = 1,
  }) async {
    final response =
        await _client.get('channels/$channelId/messages', queryParams: {
      'per_page': perPage.toString(),
      'page': page.toString(),
      if (beforeId != null) 'before_id': beforeId.toString(),
    });
    final items = (response['data'] as List)
        .map((e) => FirestackMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = response['meta'] as Map<String, dynamic>? ?? {};
    return PaginatedResult<FirestackMessage>(
      data: items,
      currentPage: meta['current_page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Send a message to a channel.
  Future<FirestackMessage> sendMessage({
    required String channelId,
    required String body,
    String type = 'text',
    Map<String, dynamic>? metadata,
    int? replyToId,
  }) async {
    final response = await _client.post('channels/$channelId/messages', body: {
      'body': body,
      'type': type,
      if (metadata != null) 'metadata': metadata,
      if (replyToId != null) 'reply_to_id': replyToId,
    });
    return FirestackMessage.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Edit a message.
  Future<FirestackMessage> updateMessage(
    String messageId, {
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _client.put('messages/$messageId', body: {
      'body': body,
      if (metadata != null) 'metadata': metadata,
    });
    return FirestackMessage.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _client.delete('messages/$messageId');
  }

  // ─── Reactions ───────────────────────────────────────────────

  /// Add an emoji reaction to a message.
  Future<void> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    await _client.post('messages/$messageId/reactions', body: {
      'emoji': emoji,
    });
  }

  /// Remove an emoji reaction from a message.
  Future<void> removeReaction({
    required String messageId,
    required String emoji,
  }) async {
    await _client.delete('messages/$messageId/reactions/$emoji');
  }

  // ─── Read Receipts ──────────────────────────────────────────

  /// Mark all messages in a channel as read for the authenticated user.
  Future<int> markAsRead(String channelId) async {
    final response = await _client.post('channels/$channelId/read');
    return (response['data'] as Map<String, dynamic>?)?['marked_read']
            as int? ??
        0;
  }

  // ─── Typing ──────────────────────────────────────────────────

  /// Send a typing indicator to a channel.
  Future<void> sendTyping(String channelId, {bool isTyping = true}) async {
    await _client.post('channels/$channelId/typing', body: {
      'is_typing': isTyping,
    });
  }

  // ─── Search ──────────────────────────────────────────────────

  /// Search messages in a channel.
  Future<PaginatedResult<FirestackMessage>> searchMessages(
    String channelId, {
    required String query,
    int perPage = 20,
    int page = 1,
  }) async {
    final response =
        await _client.get('channels/$channelId/search', queryParams: {
      'q': query,
      'per_page': perPage.toString(),
      'page': page.toString(),
    });
    final items = (response['data'] as List)
        .map((e) => FirestackMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = response['meta'] as Map<String, dynamic>? ?? {};
    return PaginatedResult<FirestackMessage>(
      data: items,
      currentPage: meta['current_page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  // ─── Mute / Pin ─────────────────────────────────────────────

  /// Toggle mute on a channel for the authenticated user.
  Future<bool> toggleMute(String channelId) async {
    final response = await _client.post('channels/$channelId/mute');
    return (response['data'] as Map<String, dynamic>?)?['is_muted'] as bool? ??
        false;
  }

  /// Toggle pin on a channel for the authenticated user.
  Future<bool> togglePin(String channelId) async {
    final response = await _client.post('channels/$channelId/pin');
    return (response['data'] as Map<String, dynamic>?)?['is_pinned'] as bool? ??
        false;
  }
}
