import 'firestack_client.dart';
import 'models/collection.dart';
import 'models/document.dart';
import 'models/query_builder.dart';

/// Paginated result wrapper.
class PaginatedResult<T> {
  final List<T> data;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  const PaginatedResult({
    required this.data,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Firestore-like database service.
///
/// ```dart
/// final firestore = app.firestore;
///
/// // Get all collections
/// final collections = await firestore.collections();
///
/// // CRUD on a collection
/// final ref = firestore.collection('users');
/// final docs = await ref.get();
/// final doc = await ref.doc('user123').get();
/// await ref.add({'name': 'Alice', 'age': 30});
/// ```
class FirestackFirestore {
  final FirestackClient _client;

  FirestackFirestore({required FirestackClient client}) : _client = client;

  /// Get a collection reference.
  CollectionReference collection(String slug) {
    return CollectionReference(client: _client, slug: slug);
  }

  /// List all top-level collections.
  Future<PaginatedResult<FirestackCollection>> collections({
    int perPage = 15,
  }) async {
    final response = await _client.get('/collections', queryParams: {
      'per_page': perPage.toString(),
    });

    final data = (response['data'] as List)
        .map((e) => FirestackCollection.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = response['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedResult(
      data: data,
      currentPage: meta['current_page'] as int? ?? 1,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? data.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Create a new collection.
  Future<FirestackCollection> createCollection({
    required String name,
    String? description,
    Map<String, dynamic>? schema,
    bool? isPublic,
  }) async {
    final response = await _client.post('/collections', body: {
      'name': name,
      if (description != null) 'description': description,
      if (schema != null) 'schema': schema,
      if (isPublic != null) 'is_public': isPublic,
    });

    return FirestackCollection.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Get a document by UUID (globally unique).
  Future<FirestackDocument> getDocumentByUuid(String uuid) async {
    final response = await _client.get('/documents/$uuid');
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Update a document by UUID (full replace).
  Future<FirestackDocument> setDocumentByUuid(
      String uuid, Map<String, dynamic> data) async {
    final response = await _client.put('/documents/$uuid', body: {
      'data': data,
    });
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Update a document by UUID (partial merge).
  Future<FirestackDocument> updateDocumentByUuid(
      String uuid, Map<String, dynamic> data) async {
    final response = await _client.patch('/documents/$uuid', body: {
      'data': data,
    });
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Delete a document by UUID.
  Future<void> deleteDocumentByUuid(String uuid) async {
    await _client.delete('/documents/$uuid');
  }

  /// Get subcollections of a document.
  Future<List<FirestackCollection>> getSubcollections(String documentUuid) async {
    final response = await _client.get('/documents/$documentUuid/collections');
    return (response['data'] as List)
        .map((e) => FirestackCollection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a subcollection under a document.
  Future<FirestackCollection> createSubcollection(
      String documentUuid, String name) async {
    final response = await _client.post(
      '/documents/$documentUuid/collections',
      body: {'name': name},
    );
    return FirestackCollection.fromJson(
        response['data'] as Map<String, dynamic>);
  }
}

/// Reference to a specific collection.
class CollectionReference {
  final FirestackClient _client;
  final String slug;
  final String? _parentDocUuid;

  CollectionReference({
    required FirestackClient client,
    required this.slug,
    String? parentDocUuid,
  })  : _client = client,
        _parentDocUuid = parentDocUuid;

  String get _basePath => _parentDocUuid != null
      ? '/documents/$_parentDocUuid/collections/$slug'
      : '/collections/$slug';

  /// Get collection details.
  Future<FirestackCollection> get() async {
    final response = await _client.get(_basePath);
    return FirestackCollection.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Update collection metadata.
  Future<FirestackCollection> update({
    String? name,
    String? description,
    Map<String, dynamic>? schema,
    bool? isPublic,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (schema != null) body['schema'] = schema;
    if (isPublic != null) body['is_public'] = isPublic;

    final response = await _client.patch(_basePath, body: body);
    return FirestackCollection.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Delete the collection and all its documents.
  Future<void> delete() async {
    await _client.delete(_basePath);
  }

  /// Get a document reference by doc_id.
  DocumentReference doc(String docId) {
    return DocumentReference(
      client: _client,
      collectionPath: _basePath,
      docId: docId,
    );
  }

  /// List documents in this collection.
  Future<PaginatedResult<FirestackDocument>> getDocs({
    QueryBuilder? query,
  }) async {
    final queryParams = query?.toQueryParams() ?? <String, dynamic>{};
    final response = await _client.get(
      '$_basePath/documents',
      queryParams: queryParams,
    );

    final data = (response['data'] as List)
        .map((e) => FirestackDocument.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = response['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedResult(
      data: data,
      currentPage: meta['current_page'] as int? ?? 1,
      perPage: meta['per_page'] as int? ?? 15,
      total: meta['total'] as int? ?? data.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Add a new document to the collection (auto-generated ID).
  Future<FirestackDocument> add(Map<String, dynamic> data) async {
    final response = await _client.post(
      '$_basePath/documents',
      body: {'data': data},
    );
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Add a document with a specific doc_id.
  Future<FirestackDocument> addWithId(
      String docId, Map<String, dynamic> data) async {
    final response = await _client.post(
      '$_basePath/documents',
      body: {'doc_id': docId, 'data': data},
    );
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Set (upsert) a document by doc_id - creates or fully replaces.
  Future<FirestackDocument> setDoc(
      String docId, Map<String, dynamic> data) async {
    final response = await _client.put(
      '$_basePath/documents/$docId',
      body: {'data': data},
    );
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Query documents with a query builder.
  Future<PaginatedResult<FirestackDocument>> query(
      QueryBuilder Function(QueryBuilder q) build) {
    final q = build(QueryBuilder());
    return getDocs(query: q);
  }
}

/// Reference to a specific document within a collection.
class DocumentReference {
  final FirestackClient _client;
  final String collectionPath;
  final String docId;

  DocumentReference({
    required FirestackClient client,
    required this.collectionPath,
    required this.docId,
  }) : _client = client;

  /// Get the document.
  Future<FirestackDocument> get() async {
    final response = await _client.get('$collectionPath/documents/$docId');
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Set (upsert) the document - full replace.
  Future<FirestackDocument> set(Map<String, dynamic> data) async {
    final response = await _client.put(
      '$collectionPath/documents/$docId',
      body: {'data': data},
    );
    return FirestackDocument.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  /// Get a subcollection reference from this document.
  /// Requires first fetching the document to get its UUID.
  CollectionReference collection(String slug, {required String documentUuid}) {
    return CollectionReference(
      client: _client,
      slug: slug,
      parentDocUuid: documentUuid,
    );
  }
}
