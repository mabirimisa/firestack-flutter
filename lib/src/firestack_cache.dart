/// In-memory document cache with TTL for offline-first reads.
///
/// Like Firebase's offline persistence, but in-memory (no disk I/O dependency).
///
/// ```dart
/// final cache = FirestackCache(defaultTtl: Duration(minutes: 5));
///
/// // Cache a document
/// cache.put('users/alice', {'name': 'Alice', 'age': 30});
///
/// // Read from cache (returns null if expired or not found)
/// final data = cache.get('users/alice');
///
/// // Check if cached
/// if (cache.has('users/alice')) { ... }
///
/// // Invalidate
/// cache.invalidate('users/alice');
///
/// // Clear all
/// cache.clear();
/// ```
class FirestackCache {
  final Duration defaultTtl;
  final int maxEntries;
  final Map<String, _CacheEntry> _store = {};

  /// Create a cache with a default TTL and optional max entry count.
  ///
  /// When [maxEntries] is exceeded, the oldest entries are evicted (LRU).
  FirestackCache({
    this.defaultTtl = const Duration(minutes: 5),
    this.maxEntries = 1000,
  });

  /// Get a cached value by key. Returns `null` if missing or expired.
  Map<String, dynamic>? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    entry.lastAccessedAt = DateTime.now();
    return entry.data;
  }

  /// Get a cached list value by key. Returns `null` if missing or expired.
  List<Map<String, dynamic>>? getList(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    entry.lastAccessedAt = DateTime.now();
    return entry.listData;
  }

  /// Cache a single document/map.
  void put(String key, Map<String, dynamic> data, {Duration? ttl}) {
    _evictIfNeeded();
    _store[key] = _CacheEntry(
      data: data,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Cache a list of documents/maps.
  void putList(String key, List<Map<String, dynamic>> data, {Duration? ttl}) {
    _evictIfNeeded();
    _store[key] = _CacheEntry(
      listData: data,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Check if a non-expired entry exists for [key].
  bool has(String key) {
    final entry = _store[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  /// Remove a specific key.
  void invalidate(String key) => _store.remove(key);

  /// Remove all entries matching a key prefix (e.g. collection path).
  void invalidatePrefix(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear the entire cache.
  void clear() => _store.clear();

  /// Number of entries currently in the cache.
  int get length => _store.length;

  /// Remove expired entries.
  void prune() {
    _store.removeWhere((_, entry) => entry.isExpired);
  }

  void _evictIfNeeded() {
    if (_store.length < maxEntries) return;
    // Remove expired first
    prune();
    if (_store.length < maxEntries) return;
    // LRU eviction — remove oldest accessed entries
    final sorted = _store.entries.toList()
      ..sort(
          (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt));
    final toRemove = sorted.take(_store.length - maxEntries + 1);
    for (final entry in toRemove) {
      _store.remove(entry.key);
    }
  }
}

class _CacheEntry {
  final Map<String, dynamic>? data;
  final List<Map<String, dynamic>>? listData;
  final DateTime expiresAt;
  DateTime lastAccessedAt;

  _CacheEntry({
    this.data,
    this.listData,
    required this.expiresAt,
  }) : lastAccessedAt = DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Source of a cached read result.
enum CacheSource { cache, server }

/// Result wrapper that indicates the source (cache or server).
class CachedResult<T> {
  final T data;
  final CacheSource source;

  const CachedResult({required this.data, required this.source});

  bool get isFromCache => source == CacheSource.cache;
  bool get isFromServer => source == CacheSource.server;
}
