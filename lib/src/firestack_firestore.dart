import 'dart:async';
import 'firestack_cache.dart';
import 'firestack_client.dart';
import 'firestack_realtime.dart';
import 'models/collection.dart';
import 'models/document.dart';
import 'models/field_value.dart';
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

  /// Whether there is a next page.
  bool get hasMore => currentPage < lastPage;

  /// Whether there is a next page (alias).
  bool get hasNextPage => currentPage < lastPage;

  /// Whether there is a previous page.
  bool get hasPreviousPage => currentPage > 1;

  /// Whether the result set is empty.
  bool get isEmpty => data.isEmpty;

  /// Whether the result set is not empty.
  bool get isNotEmpty => data.isNotEmpty;

  /// The number of items on this page.
  int get count => data.length;

  /// The next page number, or `null` if this is the last page.
  int? get nextPage => hasNextPage ? currentPage + 1 : null;

  /// The previous page number, or `null` if this is the first page.
  int? get previousPage => hasPreviousPage ? currentPage - 1 : null;

  /// Transform the data items.
  PaginatedResult<R> map<R>(R Function(T item) transform) {
    return PaginatedResult<R>(
      data: data.map(transform).toList(),
      currentPage: currentPage,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }
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
///
/// // Realtime snapshots (like Firebase onSnapshot)
/// ref.snapshots(projectId: 1).listen((docs) {
///   print('Collection updated: ${docs.length} documents');
/// });
/// ```
class FirestackFirestore {
  final FirestackClient _client;
  FirestackRealtime? _realtime;

  /// In-memory document cache for offline-first reads.
  final FirestackCache cache;

  /// Whether to use the cache for reads. Defaults to `true`.
  bool enableCache;

  FirestackFirestore({
    required FirestackClient client,
    FirestackCache? cache,
    this.enableCache = true,
  })  : _client = client,
        cache = cache ?? FirestackCache();

  /// Attach the realtime engine (for snapshot streams).
  void attachRealtime(FirestackRealtime realtime) => _realtime = realtime;

  /// Get a collection reference.
  CollectionReference collection(String slug) {
    return CollectionReference(
      client: _client,
      slug: slug,
      realtime: _realtime,
      cache: enableCache ? cache : null,
    );
  }

  /// Query documents across all collections with the given slug
  /// (collection group query — like Firebase's `collectionGroup()`).
  ///
  /// ```dart
  /// final allComments = await firestore.collectionGroup('comments').getDocs();
  /// ```
  CollectionReference collectionGroup(String slug) {
    return CollectionReference(
      client: _client,
      slug: slug,
      realtime: _realtime,
      cache: enableCache ? cache : null,
      isCollectionGroup: true,
    );
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
    return FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Update a document by UUID (full replace).
  Future<FirestackDocument> setDocumentByUuid(
      String uuid, Map<String, dynamic> data) async {
    final response = await _client.put('/documents/$uuid', body: {
      'data': data,
    });
    return FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Update a document by UUID (partial merge).
  Future<FirestackDocument> updateDocumentByUuid(
      String uuid, Map<String, dynamic> data) async {
    final response = await _client.patch('/documents/$uuid', body: {
      'data': data,
    });
    return FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Delete a document by UUID.
  Future<void> deleteDocumentByUuid(String uuid) async {
    await _client.delete('/documents/$uuid');
  }

  /// Get subcollections of a document.
  Future<List<FirestackCollection>> getSubcollections(
      String documentUuid) async {
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

  /// Create a new write batch for atomic operations.
  WriteBatch batch() => WriteBatch._(client: _client);

  /// Run a transaction.
  ///
  /// The [updateFunction] receives a [Transaction] object that provides
  /// `get`, `set`, `update`, and `delete` methods. All reads happen first,
  /// then all writes are committed atomically.
  ///
  /// ```dart
  /// await firestore.runTransaction((transaction) async {
  ///   final doc = await transaction.get(
  ///     firestore.collection('accounts').doc('alice'),
  ///   );
  ///   final balance = doc.get<int>('balance') ?? 0;
  ///   transaction.update(
  ///     firestore.collection('accounts').doc('alice'),
  ///     {'balance': balance + 100},
  ///   );
  /// });
  /// ```
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    final transaction = Transaction._(client: _client);
    try {
      final result = await updateFunction(transaction);
      await transaction._commit();
      return result;
    } catch (e) {
      rethrow;
    }
  }
}

/// Reference to a specific collection.
class CollectionReference {
  final FirestackClient _client;
  final String slug;
  final String? _parentDocUuid;
  final FirestackRealtime? _realtime;
  final FirestackCache? _cache;
  final bool isCollectionGroup;

  CollectionReference({
    required FirestackClient client,
    required this.slug,
    String? parentDocUuid,
    FirestackRealtime? realtime,
    FirestackCache? cache,
    this.isCollectionGroup = false,
  })  : _client = client,
        _parentDocUuid = parentDocUuid,
        _realtime = realtime,
        _cache = cache;

  String get _basePath {
    if (isCollectionGroup) return '/collection-group/$slug';
    return _parentDocUuid != null
        ? '/documents/$_parentDocUuid/collections/$slug'
        : '/collections/$slug';
  }

  String get _cachePrefix => 'col:$slug';

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
      realtime: _realtime,
      cache: _cache,
      cachePrefix: _cachePrefix,
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

    // Cache each document individually
    if (_cache != null) {
      for (final doc in data) {
        _cache!.put('$_cachePrefix:doc:${doc.id}', doc.toJson());
      }
    }

    return PaginatedResult(
      data: data,
      currentPage: meta['current_page'] as int? ?? 1,
      perPage: meta['per_page'] as int? ?? 15,
      total: meta['total'] as int? ?? data.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Get the count of documents in this collection (aggregate query).
  ///
  /// ```dart
  /// final count = await firestore.collection('users').count();
  /// print('$count users');
  /// ```
  Future<int> count({QueryBuilder? query}) async {
    final queryParams = query?.toQueryParams() ?? <String, dynamic>{};
    queryParams['aggregate'] = 'count';
    final response = await _client.get(
      '$_basePath/documents',
      queryParams: queryParams,
    );
    return (response['data'] as Map<String, dynamic>?)?['count'] as int? ??
        (response['meta'] as Map<String, dynamic>?)?['total'] as int? ??
        0;
  }

  /// Get the sum of a numeric field across documents (aggregate query).
  ///
  /// ```dart
  /// final totalRevenue = await firestore.collection('orders').sum('amount');
  /// ```
  Future<num> sum(String field, {QueryBuilder? query}) async {
    final queryParams = query?.toQueryParams() ?? <String, dynamic>{};
    queryParams['aggregate'] = 'sum';
    queryParams['aggregate_field'] = field;
    final response = await _client.get(
      '$_basePath/documents',
      queryParams: queryParams,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['sum'] as num? ?? 0;
  }

  /// Get the average of a numeric field across documents (aggregate query).
  ///
  /// ```dart
  /// final avgAge = await firestore.collection('users').average('age');
  /// ```
  Future<double> average(String field, {QueryBuilder? query}) async {
    final queryParams = query?.toQueryParams() ?? <String, dynamic>{};
    queryParams['aggregate'] = 'average';
    queryParams['aggregate_field'] = field;
    final response = await _client.get(
      '$_basePath/documents',
      queryParams: queryParams,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return (data['average'] as num?)?.toDouble() ?? 0.0;
  }

  /// Add a new document to the collection (auto-generated ID).
  Future<FirestackDocument> add(Map<String, dynamic> data) async {
    final response = await _client.post(
      '$_basePath/documents',
      body: {'data': encodeFieldValues(data)},
    );
    return FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Add a document with a specific doc_id.
  Future<FirestackDocument> addWithId(
      String docId, Map<String, dynamic> data) async {
    final response = await _client.post(
      '$_basePath/documents',
      body: {'doc_id': docId, 'data': encodeFieldValues(data)},
    );
    return FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Set (upsert) a document by doc_id - creates or fully replaces.
  Future<FirestackDocument> setDoc(
      String docId, Map<String, dynamic> data) async {
    final response = await _client.put(
      '$_basePath/documents/$docId',
      body: {'data': encodeFieldValues(data)},
    );
    return FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Query documents with a query builder.
  Future<PaginatedResult<FirestackDocument>> query(
      QueryBuilder Function(QueryBuilder q) build) {
    final q = build(QueryBuilder());
    return getDocs(query: q);
  }

  /// Stream of document changes in this collection (like Firebase onSnapshot).
  ///
  /// Fetches initial data then listens for realtime create/update/delete events.
  /// Requires the realtime engine to be connected.
  ///
  /// ```dart
  /// firestore.collection('users').snapshots(projectId: 1).listen((docs) {
  ///   print('${docs.length} users');
  /// });
  /// ```
  Stream<List<FirestackDocument>> snapshots({
    required int projectId,
    QueryBuilder? query,
  }) {
    if (_realtime == null) {
      throw StateError(
          'Realtime engine not attached. Call app.realtime.connect() first.');
    }

    final controller = StreamController<List<FirestackDocument>>.broadcast();
    final docs = <String, FirestackDocument>{};

    // Fetch initial data
    getDocs(query: query).then((result) {
      for (final doc in result.data) {
        docs[doc.uuid] = doc;
      }
      if (!controller.isClosed) {
        controller.add(docs.values.toList());
      }
    }).catchError((e) {
      if (!controller.isClosed) controller.addError(e);
    });

    void onCreated(Map<String, dynamic> data) {
      if (controller.isClosed) return;
      final doc = FirestackDocument.fromJson(data);
      docs[doc.uuid] = doc;
      controller.add(docs.values.toList());
    }

    void onUpdated(Map<String, dynamic> data) {
      if (controller.isClosed) return;
      final doc = FirestackDocument.fromJson(data);
      docs[doc.uuid] = doc;
      controller.add(docs.values.toList());
    }

    void onDeleted(Map<String, dynamic> data) {
      if (controller.isClosed) return;
      final uuid = data['uuid'] as String?;
      if (uuid != null) docs.remove(uuid);
      controller.add(docs.values.toList());
    }

    _realtime!.onDocumentCreated(projectId, onCreated);
    _realtime!.onDocumentUpdated(projectId, onUpdated);
    _realtime!.onDocumentDeleted(projectId, onDeleted);

    final channelName = 'private-project.$projectId.collections';
    controller.onCancel = () {
      _realtime!.off(channelName, '.document.created', onCreated);
      _realtime!.off(channelName, '.document.updated', onUpdated);
      _realtime!.off(channelName, '.document.deleted', onDeleted);
    };

    return controller.stream;
  }
}

/// Reference to a specific document within a collection.
class DocumentReference {
  final FirestackClient _client;
  final String collectionPath;
  final String docId;
  final FirestackRealtime? _realtime;
  final FirestackCache? _cache;
  final String? _cachePrefix;

  DocumentReference({
    required FirestackClient client,
    required this.collectionPath,
    required this.docId,
    FirestackRealtime? realtime,
    FirestackCache? cache,
    String? cachePrefix,
  })  : _client = client,
        _realtime = realtime,
        _cache = cache,
        _cachePrefix = cachePrefix;

  String get _cacheKey => '${_cachePrefix ?? collectionPath}:doc:$docId';

  /// Get the document.
  ///
  /// If [source] is [CacheSource.cache], returns cached data only (null if miss).
  /// If [source] is [CacheSource.server], bypasses cache and fetches from server.
  /// Defaults to server-first with cache as fallback on error.
  Future<FirestackDocument> get({CacheSource? source}) async {
    // Cache-only read
    if (source == CacheSource.cache && _cache != null) {
      final cached = _cache!.get(_cacheKey);
      if (cached != null) return FirestackDocument.fromJson(cached);
      throw StateError('Document not found in cache: $docId');
    }

    try {
      final response = await _client.get('$collectionPath/documents/$docId');
      final doc =
          FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
      _cache?.put(_cacheKey, doc.toJson());
      return doc;
    } catch (e) {
      // Fallback to cache on network error (if not explicitly server-only)
      if (source != CacheSource.server && _cache != null) {
        final cached = _cache!.get(_cacheKey);
        if (cached != null) return FirestackDocument.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Set (upsert) the document - full replace.
  Future<FirestackDocument> set(Map<String, dynamic> data) async {
    final response = await _client.put(
      '$collectionPath/documents/$docId',
      body: {'data': encodeFieldValues(data)},
    );
    final doc =
        FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
    _cache?.put(_cacheKey, doc.toJson());
    return doc;
  }

  /// Update the document - partial merge of fields.
  ///
  /// Supports [FieldValue] operations:
  /// ```dart
  /// await ref.update({
  ///   'score': FieldValue.increment(10),
  ///   'tags': FieldValue.arrayUnion(['dart']),
  ///   'updated_at': FieldValue.serverTimestamp(),
  /// });
  /// ```
  Future<FirestackDocument> update(Map<String, dynamic> data) async {
    final response = await _client.patch(
      '$collectionPath/documents/$docId',
      body: {'data': encodeFieldValues(data)},
    );
    final doc =
        FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
    _cache?.put(_cacheKey, doc.toJson());
    return doc;
  }

  /// Delete the document.
  Future<void> delete() async {
    await _client.delete('$collectionPath/documents/$docId');
    _cache?.invalidate(_cacheKey);
  }

  /// Check if the document exists.
  Future<bool> exists() async {
    try {
      await get();
      return true;
    } on Exception {
      return false;
    }
  }

  /// Get a subcollection reference from this document.
  /// Requires first fetching the document to get its UUID.
  CollectionReference collection(String slug, {required String documentUuid}) {
    return CollectionReference(
      client: _client,
      slug: slug,
      parentDocUuid: documentUuid,
      realtime: _realtime,
      cache: _cache,
    );
  }

  /// Stream of changes to this document (like Firebase onSnapshot).
  ///
  /// Fetches the initial document then listens for realtime update/delete events.
  ///
  /// ```dart
  /// firestore.collection('users').doc('alice').snapshots(projectId: 1).listen((doc) {
  ///   if (doc != null) {
  ///     print('Alice: ${doc.data}');
  ///   } else {
  ///     print('Alice was deleted');
  ///   }
  /// });
  /// ```
  Stream<FirestackDocument?> snapshots({required int projectId}) {
    if (_realtime == null) {
      throw StateError(
          'Realtime engine not attached. Call app.realtime.connect() first.');
    }

    final controller = StreamController<FirestackDocument?>.broadcast();

    // Fetch initial data
    get().then((doc) {
      if (!controller.isClosed) controller.add(doc);
    }).catchError((e) {
      if (!controller.isClosed) controller.addError(e);
    });

    void onUpdated(Map<String, dynamic> data) {
      if (controller.isClosed) return;
      final doc = FirestackDocument.fromJson(data);
      if (doc.id == docId) {
        controller.add(doc);
      }
    }

    void onDeleted(Map<String, dynamic> data) {
      if (controller.isClosed) return;
      final deletedId = data['id'] as String? ?? data['doc_id'] as String?;
      if (deletedId == docId) {
        controller.add(null);
      }
    }

    _realtime!.onDocumentUpdated(projectId, onUpdated);
    _realtime!.onDocumentDeleted(projectId, onDeleted);

    final channelName = 'private-project.$projectId.collections';
    controller.onCancel = () {
      _realtime!.off(channelName, '.document.updated', onUpdated);
      _realtime!.off(channelName, '.document.deleted', onDeleted);
    };

    return controller.stream;
  }
}

/// A batch of write operations to execute together.
///
/// ```dart
/// final batch = firestore.batch();
/// batch.set(firestore.collection('users').doc('alice'), {'name': 'Alice'});
/// batch.update(firestore.collection('users').doc('bob'), {'age': 31});
/// batch.delete(firestore.collection('users').doc('charlie'));
/// final results = await batch.commit();
/// ```
class WriteBatch {
  final FirestackClient _client;
  final List<_BatchOperation> _operations = [];

  WriteBatch._({required FirestackClient client}) : _client = client;

  /// Add a set (upsert) operation.
  void set(DocumentReference ref, Map<String, dynamic> data) {
    _operations.add(_BatchOperation(
      type: 'set',
      path: '${ref.collectionPath}/documents/${ref.docId}',
      data: encodeFieldValues(data),
    ));
  }

  /// Add an update (partial merge) operation. Supports [FieldValue] ops.
  void update(DocumentReference ref, Map<String, dynamic> data) {
    _operations.add(_BatchOperation(
      type: 'update',
      path: '${ref.collectionPath}/documents/${ref.docId}',
      data: encodeFieldValues(data),
    ));
  }

  /// Add a delete operation.
  void delete(DocumentReference ref) {
    _operations.add(_BatchOperation(
      type: 'delete',
      path: '${ref.collectionPath}/documents/${ref.docId}',
    ));
  }

  /// Commit all operations. Returns the list of results.
  Future<List<Map<String, dynamic>>> commit() async {
    final response = await _client.post('/batch', body: {
      'operations': _operations
          .map((op) => {
                'type': op.type,
                'path': op.path,
                if (op.data != null) 'data': op.data,
              })
          .toList(),
    });
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Number of pending operations.
  int get length => _operations.length;
}

class _BatchOperation {
  final String type;
  final String path;
  final Map<String, dynamic>? data;

  const _BatchOperation({
    required this.type,
    required this.path,
    this.data,
  });
}

/// A transaction for reading and writing documents atomically.
///
/// Reads are executed immediately. Writes are buffered and committed
/// together at the end of the transaction.
class Transaction {
  final FirestackClient _client;
  final List<_BatchOperation> _writes = [];

  Transaction._({required FirestackClient client}) : _client = client;

  /// Read a document within the transaction.
  Future<FirestackDocument> get(DocumentReference ref) async {
    final response =
        await _client.get('${ref.collectionPath}/documents/${ref.docId}');
    return FirestackDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Set (upsert) a document within the transaction.
  void set(DocumentReference ref, Map<String, dynamic> data) {
    _writes.add(_BatchOperation(
      type: 'set',
      path: '${ref.collectionPath}/documents/${ref.docId}',
      data: encodeFieldValues(data),
    ));
  }

  /// Update a document within the transaction. Supports [FieldValue] ops.
  void update(DocumentReference ref, Map<String, dynamic> data) {
    _writes.add(_BatchOperation(
      type: 'update',
      path: '${ref.collectionPath}/documents/${ref.docId}',
      data: encodeFieldValues(data),
    ));
  }

  /// Delete a document within the transaction.
  void delete(DocumentReference ref) {
    _writes.add(_BatchOperation(
      type: 'delete',
      path: '${ref.collectionPath}/documents/${ref.docId}',
    ));
  }

  Future<void> _commit() async {
    if (_writes.isEmpty) return;
    await _client.post('/batch', body: {
      'operations': _writes
          .map((op) => {
                'type': op.type,
                'path': op.path,
                if (op.data != null) 'data': op.data,
              })
          .toList(),
    });
  }
}
