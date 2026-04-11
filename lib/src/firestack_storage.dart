import 'dart:typed_data';
import 'firestack_client.dart';
import 'firestack_firestore.dart';
import 'models/file_resource.dart';

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
/// // Get a signed download URL
/// final url = await storage.getDownloadUrl(file.id);
///
/// // Download file bytes
/// final bytes = await storage.download(file.id);
///
/// // List files
/// final files = await storage.list();
/// ```
class FirestackStorage {
  final FirestackClient _client;

  FirestackStorage({required FirestackClient client}) : _client = client;

  /// List files with optional filters.
  Future<PaginatedResult<FirestackFile>> list({
    int perPage = 15,
    String? category,
    String? mimeType,
    String? visibility,
  }) async {
    final params = <String, dynamic>{
      'per_page': perPage.toString(),
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
  }) async {
    final response = await _client.uploadFile(
      '/files',
      filePath: filePath,
      fileBytes: fileBytes,
      visibility: visibility,
      category: category,
      metadata: metadata,
    );

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
}

/// A signed download URL with expiration.
class FileDownloadUrl {
  final String url;
  final String expiresAt;

  const FileDownloadUrl({required this.url, required this.expiresAt});

  @override
  String toString() => 'FileDownloadUrl(url: $url, expiresAt: $expiresAt)';
}
