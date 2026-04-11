/// Firestack notification model.
class FirestackNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String status;
  final String? readAt;
  final String? sentAt;
  final String createdAt;

  const FirestackNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.status,
    this.readAt,
    this.sentAt,
    required this.createdAt,
  });

  factory FirestackNotification.fromJson(Map<String, dynamic> json) {
    return FirestackNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>?,
      status: json['status'] as String,
      readAt: json['read_at'] as String?,
      sentAt: json['sent_at'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'status': status,
        'read_at': readAt,
        'sent_at': sentAt,
        'created_at': createdAt,
      };

  bool get isRead => readAt != null;

  @override
  String toString() => 'FirestackNotification(id: $id, title: $title)';
}
