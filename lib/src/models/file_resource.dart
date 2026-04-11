import 'user.dart';

/// Firestack file resource model.
class FirestackFile {
  final String id;
  final String originalName;
  final String mimeType;
  final int size;
  final String sizeHuman;
  final String visibility;
  final String? category;
  final Map<String, dynamic>? metadata;
  final String? url;
  final FirestackUser? uploadedBy;
  final String createdAt;
  final String updatedAt;

  const FirestackFile({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.sizeHuman,
    required this.visibility,
    this.category,
    this.metadata,
    this.url,
    this.uploadedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FirestackFile.fromJson(Map<String, dynamic> json) {
    return FirestackFile(
      id: json['id'] as String,
      originalName: json['original_name'] as String,
      mimeType: json['mime_type'] as String,
      size: json['size'] as int,
      sizeHuman: json['size_human'] as String? ?? '',
      visibility: json['visibility'] as String,
      category: json['category'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      url: json['url'] as String?,
      uploadedBy: json['uploaded_by'] != null
          ? FirestackUser.fromJson(json['uploaded_by'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'original_name': originalName,
        'mime_type': mimeType,
        'size': size,
        'size_human': sizeHuman,
        'visibility': visibility,
        'category': category,
        'metadata': metadata,
        'url': url,
        'uploaded_by': uploadedBy?.toJson(),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  bool get isPublic => visibility == 'public';
  bool get isPrivate => visibility == 'private';
  bool get isImage => mimeType.startsWith('image/');

  @override
  String toString() => 'FirestackFile(id: $id, name: $originalName)';
}
