/// Firestack collection model (Firestore-like).
class FirestackCollection {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final bool isPublic;
  final bool isSubcollection;
  final int? parentDocumentId;
  final Map<String, dynamic>? schema;
  final int? documentsCount;
  final String createdAt;
  final String updatedAt;

  const FirestackCollection({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.isPublic,
    required this.isSubcollection,
    this.parentDocumentId,
    this.schema,
    this.documentsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FirestackCollection.fromJson(Map<String, dynamic> json) {
    return FirestackCollection(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      isSubcollection: json['is_subcollection'] as bool? ?? false,
      parentDocumentId: json['parent_document_id'] as int?,
      schema: json['schema'] as Map<String, dynamic>?,
      documentsCount: json['documents_count'] as int?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'is_public': isPublic,
        'is_subcollection': isSubcollection,
        'parent_document_id': parentDocumentId,
        'schema': schema,
        'documents_count': documentsCount,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  String toString() =>
      'FirestackCollection(name: $name, docs: $documentsCount)';
}
