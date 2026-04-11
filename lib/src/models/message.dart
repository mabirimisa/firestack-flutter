/// Firestack message model for instant messaging.
class FirestackMessage {
  final String id; // uuid
  final int channelId;
  final FirestackMessageSender? sender;
  final String type; // text, image, file, system, reply
  final String body;
  final Map<String, dynamic>? metadata;
  final FirestackMessage? replyTo;
  final List<FirestackReaction> reactions;
  final int? readCount;
  final bool isEdited;
  final String? editedAt;
  final String createdAt;
  final String updatedAt;

  const FirestackMessage({
    required this.id,
    required this.channelId,
    this.sender,
    required this.type,
    required this.body,
    this.metadata,
    this.replyTo,
    this.reactions = const [],
    this.readCount,
    required this.isEdited,
    this.editedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file';
  bool get isSystem => type == 'system';
  bool get isReply => type == 'reply';

  factory FirestackMessage.fromJson(Map<String, dynamic> json) {
    return FirestackMessage(
      id: json['id'] as String,
      channelId: json['channel_id'] as int? ?? 0,
      sender: json['sender'] != null
          ? FirestackMessageSender.fromJson(
              json['sender'] as Map<String, dynamic>)
          : null,
      type: json['type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      replyTo: json['reply_to'] != null
          ? FirestackMessage.fromJson(
              json['reply_to'] as Map<String, dynamic>)
          : null,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((r) =>
                  FirestackReaction.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      readCount: json['read_count'] as int?,
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel_id': channelId,
        'sender': sender?.toJson(),
        'type': type,
        'body': body,
        'metadata': metadata,
        'reply_to': replyTo?.toJson(),
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'read_count': readCount,
        'is_edited': isEdited,
        'edited_at': editedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  String toString() =>
      'FirestackMessage(id: $id, type: $type, body: ${body.length > 50 ? '${body.substring(0, 50)}...' : body})';
}

/// Sender info embedded in a message.
class FirestackMessageSender {
  final int id;
  final String name;
  final String? email;
  final String? avatar;

  const FirestackMessageSender({
    required this.id,
    required this.name,
    this.email,
    this.avatar,
  });

  factory FirestackMessageSender.fromJson(Map<String, dynamic> json) {
    return FirestackMessageSender(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
      };
}

/// Aggregated reaction on a message.
class FirestackReaction {
  final String emoji;
  final int count;
  final List<int> userIds;

  const FirestackReaction({
    required this.emoji,
    required this.count,
    required this.userIds,
  });

  factory FirestackReaction.fromJson(Map<String, dynamic> json) {
    return FirestackReaction(
      emoji: json['emoji'] as String,
      count: json['count'] as int? ?? 0,
      userIds: (json['users'] as List<dynamic>?)
              ?.map((u) => u as int)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'count': count,
        'users': userIds,
      };
}
