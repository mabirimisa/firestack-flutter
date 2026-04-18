import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'firestack_exception.dart';

/// Log level for debug output.
enum FirestackLogLevel { none, error, info, verbose }

/// Low-level HTTP client for Firestack API.
class FirestackClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _httpClient;
  String? _bearerToken;

  /// Request timeout. Defaults to 30 seconds.
  Duration timeout;

  /// Max retry attempts for retryable failures (5xx, timeout). 0 = no retries.
  int maxRetries;

  /// Log level for debug output.
  FirestackLogLevel logLevel;

  /// Custom log function. Defaults to [print].
  void Function(String message)? logger;

  FirestackClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.logLevel = FirestackLogLevel.none,
    this.logger,
  }) : _httpClient = httpClient ?? http.Client();

  /// Set the bearer token for authenticated requests.
  void setToken(String? token) => _bearerToken = token;

  /// Get the current bearer token.
  String? get token => _bearerToken;

  void _log(FirestackLogLevel level, String message) {
    if (logLevel.index >= level.index && level != FirestackLogLevel.none) {
      (logger ?? print)('[Firestack] $message');
    }
  }

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

  bool _isRetryable(int statusCode) =>
      statusCode == 429 || (statusCode >= 500 && statusCode < 600);

  Future<http.Response> _withRetry(
    String method,
    Future<http.Response> Function() request,
  ) async {
    var attempts = 0;
    while (true) {
      try {
        _log(FirestackLogLevel.verbose, '$method attempt ${attempts + 1}');
        final response = await request().timeout(timeout);
        if (_isRetryable(response.statusCode) && attempts < maxRetries) {
          attempts++;
          final delay = Duration(
            milliseconds: min(pow(2, attempts).toInt() * 500, 8000) +
                Random().nextInt(500),
          );
          _log(FirestackLogLevel.info,
              '$method ${response.statusCode} — retrying in ${delay.inMilliseconds}ms');
          await Future.delayed(delay);
          continue;
        }
        return response;
      } on TimeoutException {
        if (attempts < maxRetries) {
          attempts++;
          _log(FirestackLogLevel.info,
              '$method timeout — retrying ($attempts/$maxRetries)');
          continue;
        }
        _log(FirestackLogLevel.error,
            '$method timeout after $maxRetries retries');
        throw FirestackException(
          'Request timed out after $maxRetries retries',
          errorCode: 'timeout',
        );
      }
    }
  }

  /// Make a GET request and return parsed JSON body.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    final uri = _uri(path, queryParams);
    _log(FirestackLogLevel.verbose, 'GET $uri');
    final response = await _withRetry(
      'GET $path',
      () => _httpClient.get(uri, headers: _headers),
    );
    return _handleResponse(response);
  }

  /// Make a POST request with JSON body.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    _log(FirestackLogLevel.verbose, 'POST $uri');
    final response = await _withRetry(
      'POST $path',
      () => _httpClient.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    return _handleResponse(response);
  }

  /// Make a PUT request with JSON body.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    _log(FirestackLogLevel.verbose, 'PUT $uri');
    final response = await _withRetry(
      'PUT $path',
      () => _httpClient.put(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    return _handleResponse(response);
  }

  /// Make a PATCH request with JSON body.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    _log(FirestackLogLevel.verbose, 'PATCH $uri');
    final response = await _withRetry(
      'PATCH $path',
      () => _httpClient.patch(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    return _handleResponse(response);
  }

  /// Make a DELETE request.
  Future<Map<String, dynamic>> delete(String path) async {
    final uri = _uri(path);
    _log(FirestackLogLevel.verbose, 'DELETE $uri');
    final response = await _withRetry(
      'DELETE $path',
      () => _httpClient.delete(uri, headers: _headers),
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
    _log(FirestackLogLevel.verbose, 'UPLOAD $uri (${fileBytes.length} bytes)');
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

    final streamed = await _httpClient.send(request).timeout(timeout);
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
