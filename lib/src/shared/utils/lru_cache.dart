import 'dart:collection';

/// A simple implementation of a Least Recently Used (LRU) cache.
class LruCache<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();
  final List<K> _usageOrder = [];

  LruCache(this._maxSize) : assert(_maxSize > 0);

  /// Retrieves a value from the cache.
  ///
  /// If the key exists, it is marked as recently used.
  V? get(K key) {
    if (_cache.containsKey(key)) {
      // Move the key to the end of the usage list to mark it as recently used.
      _usageOrder.remove(key);
      _usageOrder.add(key);
      return _cache[key];
    }
    return null;
  }

  /// Adds or updates a value in the cache.
  ///
  /// If the cache is full, the least recently used item is removed.
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      // Key already exists, just update the value and move it to the end.
      _usageOrder.remove(key);
    } else if (_cache.length >= _maxSize) {
      // Cache is full, remove the least recently used item.
      final keyToRemove = _usageOrder.removeAt(0);
      _cache.remove(keyToRemove);
    }
    _cache[key] = value;
    _usageOrder.add(key);
  }

  /// Removes a value from the cache.
  void remove(K key) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      _usageOrder.remove(key);
    }
  }

  /// Clears the cache.
  void clear() {
    _cache.clear();
    _usageOrder.clear();
  }

  /// Checks if the cache contains the given key.
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  /// Returns all values in the cache.
  Map<K, V> toMap() {
    return Map<K, V>.from(_cache);
  }
}
