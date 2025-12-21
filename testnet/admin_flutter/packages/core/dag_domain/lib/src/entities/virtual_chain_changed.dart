import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/value_objects.dart';

part 'virtual_chain_changed.freezed.dart';
part 'virtual_chain_changed.g.dart';

/// Domain Event: represents a reorganization in the virtual chain
/// When this event occurs, some blocks change from blue to red or vice versa
@freezed
sealed class VirtualChainChanged with _$VirtualChainChanged {
  const VirtualChainChanged._();

  const factory VirtualChainChanged({
    required List<BlockHash> removedHashes,
    required List<BlockHash> addedHashes,
  }) = _VirtualChainChanged;

  /// Check if there are any changes
  bool get hasChanges => removedHashes.isNotEmpty || addedHashes.isNotEmpty;

  /// Total number of changed blocks
  int get totalChanges => removedHashes.length + addedHashes.length;

  /// Number of blocks removed from consensus
  int get removedCount => removedHashes.length;

  /// Number of blocks added to consensus
  int get addedCount => addedHashes.length;

  /// Check if a specific block was removed from consensus
  bool wasRemoved(BlockHash hash) => removedHashes.contains(hash);

  /// Check if a specific block was added to consensus
  bool wasAdded(BlockHash hash) => addedHashes.contains(hash);

  /// Empty event (no changes)
  factory VirtualChainChanged.empty() => const VirtualChainChanged(
        removedHashes: [],
        addedHashes: [],
      );

  factory VirtualChainChanged.fromJson(Map<String, dynamic> json) =>
      _$VirtualChainChangedFromJson(json);
}
