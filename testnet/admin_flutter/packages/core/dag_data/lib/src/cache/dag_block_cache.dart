import 'dart:collection';

import 'package:dag_domain/dag_domain.dart';
import 'package:injectable/injectable.dart';

/// LRU cache for DAG blocks
/// Keeps last N blocks in memory, evicting oldest when full
@lazySingleton
class DagBlockCache {
  static const int _defaultMaxSize = 200;

  final int maxSize;
  final LinkedHashMap<String, DagBlock> _cache = LinkedHashMap();

  @factoryMethod
  DagBlockCache() : maxSize = _defaultMaxSize;

  /// Get block by hash
  DagBlock? get(BlockHash hash) => _cache[hash.value];

  /// Check if block exists in cache
  bool contains(BlockHash hash) => _cache.containsKey(hash.value);

  /// Put block into cache
  void put(DagBlock block) {
    final key = block.hash.value;

    // If exists, remove to update position
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }

    // Add to end (most recent)
    _cache[key] = block;

    // Evict oldest if over capacity
    while (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Put multiple blocks
  void putAll(Iterable<DagBlock> blocks) {
    for (final block in blocks) {
      put(block);
    }
  }

  /// Update block in cache
  void update(BlockHash hash, DagBlock Function(DagBlock) updater) {
    final existing = _cache[hash.value];
    if (existing != null) {
      _cache[hash.value] = updater(existing);
    }
  }

  /// Add child to parent block
  void addChild(BlockHash parentHash, BlockHash childHash) {
    update(parentHash, (parent) {
      if (parent.childrenHashes.contains(childHash)) return parent;
      return parent.copyWith(
        childrenHashes: [...parent.childrenHashes, childHash],
      );
    });
  }

  /// Mark block as chain block (blue)
  void markAsChainBlock(BlockHash hash, bool isChainBlock) {
    update(hash, (block) => block.copyWith(isChainBlock: isChainBlock));
  }

  /// Get all blocks
  List<DagBlock> get all => _cache.values.toList();

  /// Get all blocks as map
  Map<String, DagBlock> get allAsMap => Map.from(_cache);

  /// Get blocks sorted by DAA score (descending)
  List<DagBlock> get sortedByDaaScore {
    final list = all;
    list.sort((a, b) => b.daaScore.value.compareTo(a.daaScore.value));
    return list;
  }

  /// Number of blocks in cache
  int get length => _cache.length;

  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Clear cache
  void clear() => _cache.clear();

  /// Remove block by hash
  void remove(BlockHash hash) => _cache.remove(hash.value);

  /// Get blocks in DAA score range
  List<DagBlock> getInRange(DaaScore from, DaaScore to) {
    return all.where((b) =>
      b.daaScore.value >= from.value && b.daaScore.value <= to.value
    ).toList();
  }
}
