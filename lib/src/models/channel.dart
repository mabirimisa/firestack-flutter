/// Firestack messaging channel model.
class FirestackChannel {
  final String id; // uuid
  final String name;
  final String slug;
  final String? description;
  final String type; // direct, group, project
  final String? avatar;
  final bool isPrivate;
  final bool isArchived;
  final Map<String, dynamic>? metadata;
  final int? membersCount;
  final int? unreadCount;
  final FirestackChannelMessage? lastMessage;
  final String? lastMessageAt;
  final String createdAt;
  final String updatedAt;

  const FirestackChannel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.type,
    this.avatar,
    required this.isPrivate,
    required this.isArchived,
    this.metadata,
    this.membersCount,
    this.unreadCount,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDirect => type == 'direct';
  bool get isGroup => type == 'group';

  factory FirestackChannel.fromJson(Map<String, dynamic> json) {
    return FirestackChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'group',
      avatar: json['avatar'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      membersCount: json['members_count'] as int?,
      unreadCount: json['unread_count'] as int?,
      lastMessage: json['last_message'] != null
          ? FirestackChannelMessage.fromJson(
              json['last_message'] as Map<String, dynamic>)
          : null,
      lastMessageAt: json['last_message_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'type': type,
        'avatar': avatar,
        'is_private': isPrivate,
        'is_archived': isArchived,
        'metadata': metadata,
        'members_count': membersCount,
        'unread_count': unreadCount,
        'last_message': lastMessage?.toJson(),
        'last_message_at': lastMessageAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  String toString() => 'FirestackChannel(id: $id, name: $name, type: $type)';
}

/// Minimal message reference used in channel's lastMessage.
class FirestackChannelMessage {
  final String id;
  final String? senderName;
  final String type;
  final String body;
  final String createdAt;

  const FirestackChannelMessage({
    required this.id,
    this.senderName,
    required this.type,
    required this.body,
    required this.createdAt,
  });

  factory FirestackChannelMessage.fromJson(Map<String, dynamic> json) {
    return FirestackChannelMessage(
      id: json['id'] as String,
      senderName: json['sender'] is Map
          ? (json['sender'] as Map)['name'] as String?
          : null,
      type: json['type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_name': senderName,
        'type': type,
        'body': body,
        'created_at': createdAt,
      };
}
