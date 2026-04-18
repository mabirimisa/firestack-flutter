import 'user.dart';

/// Firestack document model (Firestore-like).
class FirestackDocument {
  final String id;
  final String uuid;
  final Map<String, dynamic> data;
  final int collectionId;
  final FirestackUser? createdBy;
  final FirestackUser? updatedBy;
  final String createdAt;
  final String updatedAt;

  const FirestackDocument({
    required this.id,
    required this.uuid,
    required this.data,
    required this.collectionId,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FirestackDocument.fromJson(Map<String, dynamic> json) {
    return FirestackDocument(
      id: json['id'] as String,
      uuid: json['uuid'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      collectionId: json['collection_id'] as int,
      createdBy: json['created_by'] != null
          ? FirestackUser.fromJson(json['created_by'] as Map<String, dynamic>)
          : null,
      updatedBy: json['updated_by'] != null
          ? FirestackUser.fromJson(json['updated_by'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'data': data,
        'collection_id': collectionId,
        'created_by': createdBy?.toJson(),
        'updated_by': updatedBy?.toJson(),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Get a field from the document data.
  T? get<T>(String field) => data[field] as T?;

  /// Get a nested field using dot notation (e.g., 'address.city').
  dynamic getNestedField(String path) {
    final parts = path.split('.');
    dynamic current = data;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Create a copy with updated fields.
  FirestackDocument copyWith({
    String? id,
    String? uuid,
    Map<String, dynamic>? data,
    int? collectionId,
    FirestackUser? createdBy,
    FirestackUser? updatedBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return FirestackDocument(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      data: data ?? Map<String, dynamic>.from(this.data),
      collectionId: collectionId ?? this.collectionId,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if the document contains a specific field.
  bool hasField(String field) => data.containsKey(field);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirestackDocument &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;

  @override
  String toString() => 'FirestackDocument(id: $id, uuid: $uuid)';
}
