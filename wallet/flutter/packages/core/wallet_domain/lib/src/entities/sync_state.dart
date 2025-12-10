import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_state.freezed.dart';
part 'sync_state.g.dart';

/// Sync state representing node synchronization progress.
/// Maps 1:1 to Rust `SyncState` enum from `wallet/core/src/events.rs`
@freezed
sealed class SyncState with _$SyncState {
  const SyncState._();

  /// Proof-of-work synchronization
  const factory SyncState.proof({
    required int level,
  }) = SyncStateProof;

  /// Headers synchronization
  const factory SyncState.headers({
    required int headers,
    required int progress,
  }) = SyncStateHeaders;

  /// Blocks synchronization
  const factory SyncState.blocks({
    required int blocks,
    required int progress,
  }) = SyncStateBlocks;

  /// UTXO snapshot synchronization
  const factory SyncState.utxoSync({
    required int chunks,
    required int total,
  }) = SyncStateUtxoSync;

  /// Trust synchronization
  const factory SyncState.trustSync({
    required int processed,
    required int total,
  }) = SyncStateTrustSync;

  /// UTXO resync in progress
  const factory SyncState.utxoResync() = SyncStateUtxoResync;

  /// Not synced (waiting for peers)
  const factory SyncState.notSynced() = SyncStateNotSynced;

  /// Fully synced
  const factory SyncState.synced() = SyncStateSynced;

  factory SyncState.fromJson(Map<String, dynamic> json) =>
      _$SyncStateFromJson(json);

  /// Whether the node is fully synced
  bool get isSynced => this is SyncStateSynced;

  /// Get progress percentage (0.0 - 1.0) if applicable
  double? get progressPercent => switch (this) {
        SyncStateHeaders(:final headers, :final progress) when progress > 0 =>
          headers / progress,
        SyncStateBlocks(:final blocks, :final progress) when progress > 0 =>
          blocks / progress,
        SyncStateUtxoSync(:final chunks, :final total) when total > 0 =>
          chunks / total,
        SyncStateTrustSync(:final processed, :final total) when total > 0 =>
          processed / total,
        SyncStateSynced() => 1.0,
        SyncStateNotSynced() => 0.0,
        _ => null,
      };

  /// Human-readable description
  String get description => switch (this) {
        SyncStateProof(:final level) => 'Syncing proof level $level',
        SyncStateHeaders(:final headers, :final progress) =>
          'Syncing headers: $headers / $progress',
        SyncStateBlocks(:final blocks, :final progress) =>
          'Syncing blocks: $blocks / $progress',
        SyncStateUtxoSync(:final chunks, :final total) =>
          'Syncing UTXO: $chunks / $total',
        SyncStateTrustSync(:final processed, :final total) =>
          'Trust sync: $processed / $total',
        SyncStateUtxoResync() => 'Resyncing UTXO...',
        SyncStateNotSynced() => 'Waiting for peers...',
        SyncStateSynced() => 'Synced',
      };
}
