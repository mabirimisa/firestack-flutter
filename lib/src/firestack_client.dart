import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'firestack_exception.dart';

/// Low-level HTTP client for Firestack API.
class FirestackClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _httpClient;
  String? _bearerToken;

  FirestackClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Set the bearer token for authenticated requests.
  void setToken(String? token) => _bearerToken = token;

  /// Get the current bearer token.
  String? get token => _bearerToken;

  Map<String, String> get _headers => {
        'X-API-Key': apiKey,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_bearerToken != null) 'Authorization': 'Bearer $_bearerToken',
      };

  Uri _uri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$cleanBase$cleanPath');
    if (queryParams == null || queryParams.isEmpty) return uri;

    final flatParams = <String, String>{};
    for (final entry in queryParams.entries) {
      if (entry.value == null) continue;
      if (entry.value is Map) {
        _flattenMap(entry.key, entry.value as Map, flatParams);
      } else {
        flatParams[entry.key] = entry.value.toString();
      }
    }
    return uri.replace(queryParameters: flatParams);
  }

  void _flattenMap(String prefix, Map map, Map<String, String> result) {
    for (final entry in map.entries) {
      final key = '$prefix[${entry.key}]';
      if (entry.value is Map) {
        _flattenMap(key, entry.value as Map, result);
      } else {
        result[key] = entry.value.toString();
      }
    }
  }

  /// Make a GET request and return parsed JSON body.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    final response = await _httpClient.get(
      _uri(path, queryParams),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  /// Make a POST request with JSON body.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Make a PUT request with JSON body.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Make a PATCH request with JSON body.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.patch(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Make a DELETE request.
  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _httpClient.delete(
      _uri(path),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  /// Upload a file via multipart POST.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String filePath,
    required Uint8List fileBytes,
    String? visibility,
    String? category,
    Map<String, String>? metadata,
  }) async {
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);

    request.headers['X-API-Key'] = apiKey;
    request.headers['Accept'] = 'application/json';
    if (_bearerToken != null) {
      request.headers['Authorization'] = 'Bearer $_bearerToken';
    }

    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    final parts = mimeType.split('/');
    final mediaType = MediaType(
      parts[0],
      parts.length > 1 ? parts[1] : 'octet-stream',
    );

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: p.basename(filePath),
      contentType: mediaType,
    ));

    if (visibility != null) request.fields['visibility'] = visibility;
    if (category != null) request.fields['category'] = category;
    if (metadata != null) {
      for (final entry in metadata.entries) {
        request.fields['metadata[${entry.key}]'] = entry.value;
      }
    }

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  /// Download file bytes from a URL.
  Future<Uint8List> downloadBytes(String url) async {
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw FirestackException(
        'Download failed',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw FirestackException.fromResponse(response.statusCode, body);
  }

  void dispose() => _httpClient.close();
}
