import 'dart:async';
import 'dart:typed_data';
import 'firestack_client.dart';
import 'firestack_firestore.dart';
import 'models/file_resource.dart';

/// Callback for upload progress. [bytesSent] / [totalBytes].
typedef UploadProgressCallback = void Function(int bytesSent, int totalBytes);

/// Upload task state.
enum UploadTaskState { running, paused, success, error, canceled }

/// Represents an ongoing file upload with progress tracking.
///
/// ```dart
/// final task = storage.uploadWithProgress(
///   filePath: 'video.mp4',
///   fileBytes: videoBytes,
/// );
///
/// // Listen to progress
/// task.onProgress.listen((snapshot) {
///   print('${snapshot.bytesTransferred}/${snapshot.totalBytes}');
///   print('${(snapshot.progress * 100).toStringAsFixed(1)}%');
/// });
///
/// // Wait for completion
/// final file = await task.future;
/// ```
class UploadTask {
  final Future<FirestackFile> future;
  final Stream<UploadSnapshot> onProgress;

  UploadTask({required this.future, required this.onProgress});
}

/// A snapshot of upload progress.
class UploadSnapshot {
  final int bytesTransferred;
  final int totalBytes;
  final UploadTaskState state;

  const UploadSnapshot({
    required this.bytesTransferred,
    required this.totalBytes,
    required this.state,
  });

  /// Upload progress as a fraction (0.0 to 1.0).
  double get progress => totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;
}

/// File storage service for Firestack.
///
/// ```dart
/// final storage = app.storage;
///
/// // Upload a file
/// final file = await storage.upload(
///   filePath: 'photo.jpg',
///   fileBytes: bytes,
///   visibility: 'public',
/// );
///
/// // Upload with progress tracking
/// final task = storage.uploadWithProgress(
///   filePath: 'video.mp4',
///   fileBytes: videoBytes,
/// );
/// task.onProgress.listen((snap) {
///   print('${(snap.progress * 100).toStringAsFixed(1)}%');
/// });
/// final videoFile = await task.future;
///
/// // Get a signed download URL
/// final url = await storage.getDownloadUrl(file.id);
///
/// // Download file bytes
/// final bytes = await storage.download(file.id);
///
/// // List files
/// final files = await storage.list();
///
/// // Batch delete
/// await storage.deleteFiles(['uuid1', 'uuid2', 'uuid3']);
/// ```
class FirestackStorage {
  final FirestackClient _client;

  FirestackStorage({required FirestackClient client}) : _client = client;

  /// List files with optional filters.
  Future<PaginatedResult<FirestackFile>> list({
    int perPage = 15,
    int page = 1,
    String? category,
    String? mimeType,
    String? visibility,
  }) async {
    final params = <String, dynamic>{
      'per_page': perPage.toString(),
      'page': page.toString(),
    };
    if (category != null) params['category'] = category;
    if (mimeType != null) params['mime_type'] = mimeType;
    if (visibility != null) params['visibility'] = visibility;

    final response = await _client.get('/files', queryParams: params);

    final data = (response['data'] as List)
        .map((e) => FirestackFile.fromJson(e as Map<String, dynamic>))
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

  /// Upload a file.
  Future<FirestackFile> upload({
    required String filePath,
    required Uint8List fileBytes,
    String? visibility,
    String? category,
    Map<String, String>? metadata,
    UploadProgressCallback? onProgress,
  }) async {
    // Emit initial progress
    onProgress?.call(0, fileBytes.length);

    final response = await _client.uploadFile(
      '/files',
      filePath: filePath,
      fileBytes: fileBytes,
      visibility: visibility,
      category: category,
      metadata: metadata,
    );

    // Emit completion progress
    onProgress?.call(fileBytes.length, fileBytes.length);

    return FirestackFile.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Upload a file with progress tracking via streams.
  ///
  /// Returns an [UploadTask] with a progress stream and completion future.
  UploadTask uploadWithProgress({
    required String filePath,
    required Uint8List fileBytes,
    String? visibility,
    String? category,
    Map<String, String>? metadata,
  }) {
    final controller = StreamController<UploadSnapshot>.broadcast();

    final future = _uploadTracked(
      controller: controller,
      filePath: filePath,
      fileBytes: fileBytes,
      visibility: visibility,
      category: category,
      metadata: metadata,
    );

    return UploadTask(
      future: future,
      onProgress: controller.stream,
    );
  }

  Future<FirestackFile> _uploadTracked({
    required StreamController<UploadSnapshot> controller,
    required String filePath,
    required Uint8List fileBytes,
    String? visibility,
    String? category,
    Map<String, String>? metadata,
  }) async {
    final total = fileBytes.length;

    controller.add(UploadSnapshot(
      bytesTransferred: 0,
      totalBytes: total,
      state: UploadTaskState.running,
    ));

    try {
      final response = await _client.uploadFile(
        '/files',
        filePath: filePath,
        fileBytes: fileBytes,
        visibility: visibility,
        category: category,
        metadata: metadata,
      );

      controller.add(UploadSnapshot(
        bytesTransferred: total,
        totalBytes: total,
        state: UploadTaskState.success,
      ));

      final file =
          FirestackFile.fromJson(response['data'] as Map<String, dynamic>);
      await controller.close();
      return file;
    } catch (e) {
      controller.add(UploadSnapshot(
        bytesTransferred: 0,
        totalBytes: total,
        state: UploadTaskState.error,
      ));
      await controller.close();
      rethrow;
    }
  }

  /// Update file metadata (visibility, category, custom metadata).
  Future<FirestackFile> updateFile(
    String uuid, {
    String? visibility,
    String? category,
    Map<String, String>? metadata,
  }) async {
    final body = <String, dynamic>{};
    if (visibility != null) body['visibility'] = visibility;
    if (category != null) body['category'] = category;
    if (metadata != null) body['metadata'] = metadata;

    final response = await _client.patch('/files/$uuid', body: body);
    return FirestackFile.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Get file metadata by UUID.
  Future<FirestackFile> getFile(String uuid) async {
    final response = await _client.get('/files/$uuid');
    return FirestackFile.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Get a temporary signed download URL.
  Future<FileDownloadUrl> getDownloadUrl(
    String uuid, {
    int minutes = 60,
  }) async {
    final response = await _client.get(
      '/files/$uuid/url',
      queryParams: {'minutes': minutes.toString()},
    );

    final data = response['data'] as Map<String, dynamic>;
    return FileDownloadUrl(
      url: data['url'] as String,
      expiresAt: data['expires_at'] as String,
    );
  }

  /// Download file bytes.
  Future<Uint8List> download(String uuid, {int minutes = 60}) async {
    final urlInfo = await getDownloadUrl(uuid, minutes: minutes);
    return _client.downloadBytes(urlInfo.url);
  }

  /// Delete a file by UUID.
  Future<void> deleteFile(String uuid) async {
    await _client.delete('/files/$uuid');
  }

  /// Delete multiple files by UUID.
  ///
  /// ```dart
  /// await storage.deleteFiles(['uuid1', 'uuid2', 'uuid3']);
  /// ```
  Future<void> deleteFiles(List<String> uuids) async {
    await Future.wait(uuids.map((uuid) => deleteFile(uuid)));
  }

  /// Copy a file to a new location with optional metadata changes.
  Future<FirestackFile> copyFile(
    String uuid, {
    String? visibility,
    String? category,
  }) async {
    final response = await _client.post('/files/$uuid/copy', body: {
      if (visibility != null) 'visibility': visibility,
      if (category != null) 'category': category,
    });
    return FirestackFile.fromJson(response['data'] as Map<String, dynamic>);
  }
}

/// A signed download URL with expiration.
class FileDownloadUrl {
  final String url;
  final String expiresAt;

  const FileDownloadUrl({required this.url, required this.expiresAt});

  /// Parse [expiresAt] as a [DateTime].
  DateTime get expiresAtDate => DateTime.parse(expiresAt);

  /// Whether this URL has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAtDate);

  @override
  String toString() => 'FileDownloadUrl(url: $url, expiresAt: $expiresAt)';
}
