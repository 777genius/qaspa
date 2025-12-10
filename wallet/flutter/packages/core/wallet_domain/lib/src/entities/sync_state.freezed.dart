// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
SyncState _$SyncStateFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'proof':
      return SyncStateProof.fromJson(json);
    case 'headers':
      return SyncStateHeaders.fromJson(json);
    case 'blocks':
      return SyncStateBlocks.fromJson(json);
    case 'utxoSync':
      return SyncStateUtxoSync.fromJson(json);
    case 'trustSync':
      return SyncStateTrustSync.fromJson(json);
    case 'utxoResync':
      return SyncStateUtxoResync.fromJson(json);
    case 'notSynced':
      return SyncStateNotSynced.fromJson(json);
    case 'synced':
      return SyncStateSynced.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'SyncState',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$SyncState {
  /// Serializes this SyncState to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is SyncState);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SyncState()';
  }
}

/// @nodoc
class $SyncStateCopyWith<$Res> {
  $SyncStateCopyWith(SyncState _, $Res Function(SyncState) __);
}

/// Adds pattern-matching-related methods to [SyncState].
extension SyncStatePatterns on SyncState {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncStateProof value)? proof,
    TResult Function(SyncStateHeaders value)? headers,
    TResult Function(SyncStateBlocks value)? blocks,
    TResult Function(SyncStateUtxoSync value)? utxoSync,
    TResult Function(SyncStateTrustSync value)? trustSync,
    TResult Function(SyncStateUtxoResync value)? utxoResync,
    TResult Function(SyncStateNotSynced value)? notSynced,
    TResult Function(SyncStateSynced value)? synced,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SyncStateProof() when proof != null:
        return proof(_that);
      case SyncStateHeaders() when headers != null:
        return headers(_that);
      case SyncStateBlocks() when blocks != null:
        return blocks(_that);
      case SyncStateUtxoSync() when utxoSync != null:
        return utxoSync(_that);
      case SyncStateTrustSync() when trustSync != null:
        return trustSync(_that);
      case SyncStateUtxoResync() when utxoResync != null:
        return utxoResync(_that);
      case SyncStateNotSynced() when notSynced != null:
        return notSynced(_that);
      case SyncStateSynced() when synced != null:
        return synced(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SyncStateProof value) proof,
    required TResult Function(SyncStateHeaders value) headers,
    required TResult Function(SyncStateBlocks value) blocks,
    required TResult Function(SyncStateUtxoSync value) utxoSync,
    required TResult Function(SyncStateTrustSync value) trustSync,
    required TResult Function(SyncStateUtxoResync value) utxoResync,
    required TResult Function(SyncStateNotSynced value) notSynced,
    required TResult Function(SyncStateSynced value) synced,
  }) {
    final _that = this;
    switch (_that) {
      case SyncStateProof():
        return proof(_that);
      case SyncStateHeaders():
        return headers(_that);
      case SyncStateBlocks():
        return blocks(_that);
      case SyncStateUtxoSync():
        return utxoSync(_that);
      case SyncStateTrustSync():
        return trustSync(_that);
      case SyncStateUtxoResync():
        return utxoResync(_that);
      case SyncStateNotSynced():
        return notSynced(_that);
      case SyncStateSynced():
        return synced(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncStateProof value)? proof,
    TResult? Function(SyncStateHeaders value)? headers,
    TResult? Function(SyncStateBlocks value)? blocks,
    TResult? Function(SyncStateUtxoSync value)? utxoSync,
    TResult? Function(SyncStateTrustSync value)? trustSync,
    TResult? Function(SyncStateUtxoResync value)? utxoResync,
    TResult? Function(SyncStateNotSynced value)? notSynced,
    TResult? Function(SyncStateSynced value)? synced,
  }) {
    final _that = this;
    switch (_that) {
      case SyncStateProof() when proof != null:
        return proof(_that);
      case SyncStateHeaders() when headers != null:
        return headers(_that);
      case SyncStateBlocks() when blocks != null:
        return blocks(_that);
      case SyncStateUtxoSync() when utxoSync != null:
        return utxoSync(_that);
      case SyncStateTrustSync() when trustSync != null:
        return trustSync(_that);
      case SyncStateUtxoResync() when utxoResync != null:
        return utxoResync(_that);
      case SyncStateNotSynced() when notSynced != null:
        return notSynced(_that);
      case SyncStateSynced() when synced != null:
        return synced(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int level)? proof,
    TResult Function(int headers, int progress)? headers,
    TResult Function(int blocks, int progress)? blocks,
    TResult Function(int chunks, int total)? utxoSync,
    TResult Function(int processed, int total)? trustSync,
    TResult Function()? utxoResync,
    TResult Function()? notSynced,
    TResult Function()? synced,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SyncStateProof() when proof != null:
        return proof(_that.level);
      case SyncStateHeaders() when headers != null:
        return headers(_that.headers, _that.progress);
      case SyncStateBlocks() when blocks != null:
        return blocks(_that.blocks, _that.progress);
      case SyncStateUtxoSync() when utxoSync != null:
        return utxoSync(_that.chunks, _that.total);
      case SyncStateTrustSync() when trustSync != null:
        return trustSync(_that.processed, _that.total);
      case SyncStateUtxoResync() when utxoResync != null:
        return utxoResync();
      case SyncStateNotSynced() when notSynced != null:
        return notSynced();
      case SyncStateSynced() when synced != null:
        return synced();
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int level) proof,
    required TResult Function(int headers, int progress) headers,
    required TResult Function(int blocks, int progress) blocks,
    required TResult Function(int chunks, int total) utxoSync,
    required TResult Function(int processed, int total) trustSync,
    required TResult Function() utxoResync,
    required TResult Function() notSynced,
    required TResult Function() synced,
  }) {
    final _that = this;
    switch (_that) {
      case SyncStateProof():
        return proof(_that.level);
      case SyncStateHeaders():
        return headers(_that.headers, _that.progress);
      case SyncStateBlocks():
        return blocks(_that.blocks, _that.progress);
      case SyncStateUtxoSync():
        return utxoSync(_that.chunks, _that.total);
      case SyncStateTrustSync():
        return trustSync(_that.processed, _that.total);
      case SyncStateUtxoResync():
        return utxoResync();
      case SyncStateNotSynced():
        return notSynced();
      case SyncStateSynced():
        return synced();
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int level)? proof,
    TResult? Function(int headers, int progress)? headers,
    TResult? Function(int blocks, int progress)? blocks,
    TResult? Function(int chunks, int total)? utxoSync,
    TResult? Function(int processed, int total)? trustSync,
    TResult? Function()? utxoResync,
    TResult? Function()? notSynced,
    TResult? Function()? synced,
  }) {
    final _that = this;
    switch (_that) {
      case SyncStateProof() when proof != null:
        return proof(_that.level);
      case SyncStateHeaders() when headers != null:
        return headers(_that.headers, _that.progress);
      case SyncStateBlocks() when blocks != null:
        return blocks(_that.blocks, _that.progress);
      case SyncStateUtxoSync() when utxoSync != null:
        return utxoSync(_that.chunks, _that.total);
      case SyncStateTrustSync() when trustSync != null:
        return trustSync(_that.processed, _that.total);
      case SyncStateUtxoResync() when utxoResync != null:
        return utxoResync();
      case SyncStateNotSynced() when notSynced != null:
        return notSynced();
      case SyncStateSynced() when synced != null:
        return synced();
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateProof extends SyncState {
  const SyncStateProof({required this.level, final String? $type})
      : $type = $type ?? 'proof',
        super._();
  factory SyncStateProof.fromJson(Map<String, dynamic> json) =>
      _$SyncStateProofFromJson(json);

  final int level;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncStateProofCopyWith<SyncStateProof> get copyWith =>
      _$SyncStateProofCopyWithImpl<SyncStateProof>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateProofToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncStateProof &&
            (identical(other.level, level) || other.level == level));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, level);

  @override
  String toString() {
    return 'SyncState.proof(level: $level)';
  }
}

/// @nodoc
abstract mixin class $SyncStateProofCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory $SyncStateProofCopyWith(
          SyncStateProof value, $Res Function(SyncStateProof) _then) =
      _$SyncStateProofCopyWithImpl;
  @useResult
  $Res call({int level});
}

/// @nodoc
class _$SyncStateProofCopyWithImpl<$Res>
    implements $SyncStateProofCopyWith<$Res> {
  _$SyncStateProofCopyWithImpl(this._self, this._then);

  final SyncStateProof _self;
  final $Res Function(SyncStateProof) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? level = null,
  }) {
    return _then(SyncStateProof(
      level: null == level
          ? _self.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateHeaders extends SyncState {
  const SyncStateHeaders(
      {required this.headers, required this.progress, final String? $type})
      : $type = $type ?? 'headers',
        super._();
  factory SyncStateHeaders.fromJson(Map<String, dynamic> json) =>
      _$SyncStateHeadersFromJson(json);

  final int headers;
  final int progress;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncStateHeadersCopyWith<SyncStateHeaders> get copyWith =>
      _$SyncStateHeadersCopyWithImpl<SyncStateHeaders>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateHeadersToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncStateHeaders &&
            (identical(other.headers, headers) || other.headers == headers) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, headers, progress);

  @override
  String toString() {
    return 'SyncState.headers(headers: $headers, progress: $progress)';
  }
}

/// @nodoc
abstract mixin class $SyncStateHeadersCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory $SyncStateHeadersCopyWith(
          SyncStateHeaders value, $Res Function(SyncStateHeaders) _then) =
      _$SyncStateHeadersCopyWithImpl;
  @useResult
  $Res call({int headers, int progress});
}

/// @nodoc
class _$SyncStateHeadersCopyWithImpl<$Res>
    implements $SyncStateHeadersCopyWith<$Res> {
  _$SyncStateHeadersCopyWithImpl(this._self, this._then);

  final SyncStateHeaders _self;
  final $Res Function(SyncStateHeaders) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? headers = null,
    Object? progress = null,
  }) {
    return _then(SyncStateHeaders(
      headers: null == headers
          ? _self.headers
          : headers // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateBlocks extends SyncState {
  const SyncStateBlocks(
      {required this.blocks, required this.progress, final String? $type})
      : $type = $type ?? 'blocks',
        super._();
  factory SyncStateBlocks.fromJson(Map<String, dynamic> json) =>
      _$SyncStateBlocksFromJson(json);

  final int blocks;
  final int progress;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncStateBlocksCopyWith<SyncStateBlocks> get copyWith =>
      _$SyncStateBlocksCopyWithImpl<SyncStateBlocks>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateBlocksToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncStateBlocks &&
            (identical(other.blocks, blocks) || other.blocks == blocks) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, blocks, progress);

  @override
  String toString() {
    return 'SyncState.blocks(blocks: $blocks, progress: $progress)';
  }
}

/// @nodoc
abstract mixin class $SyncStateBlocksCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory $SyncStateBlocksCopyWith(
          SyncStateBlocks value, $Res Function(SyncStateBlocks) _then) =
      _$SyncStateBlocksCopyWithImpl;
  @useResult
  $Res call({int blocks, int progress});
}

/// @nodoc
class _$SyncStateBlocksCopyWithImpl<$Res>
    implements $SyncStateBlocksCopyWith<$Res> {
  _$SyncStateBlocksCopyWithImpl(this._self, this._then);

  final SyncStateBlocks _self;
  final $Res Function(SyncStateBlocks) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? blocks = null,
    Object? progress = null,
  }) {
    return _then(SyncStateBlocks(
      blocks: null == blocks
          ? _self.blocks
          : blocks // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateUtxoSync extends SyncState {
  const SyncStateUtxoSync(
      {required this.chunks, required this.total, final String? $type})
      : $type = $type ?? 'utxoSync',
        super._();
  factory SyncStateUtxoSync.fromJson(Map<String, dynamic> json) =>
      _$SyncStateUtxoSyncFromJson(json);

  final int chunks;
  final int total;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncStateUtxoSyncCopyWith<SyncStateUtxoSync> get copyWith =>
      _$SyncStateUtxoSyncCopyWithImpl<SyncStateUtxoSync>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateUtxoSyncToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncStateUtxoSync &&
            (identical(other.chunks, chunks) || other.chunks == chunks) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, chunks, total);

  @override
  String toString() {
    return 'SyncState.utxoSync(chunks: $chunks, total: $total)';
  }
}

/// @nodoc
abstract mixin class $SyncStateUtxoSyncCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory $SyncStateUtxoSyncCopyWith(
          SyncStateUtxoSync value, $Res Function(SyncStateUtxoSync) _then) =
      _$SyncStateUtxoSyncCopyWithImpl;
  @useResult
  $Res call({int chunks, int total});
}

/// @nodoc
class _$SyncStateUtxoSyncCopyWithImpl<$Res>
    implements $SyncStateUtxoSyncCopyWith<$Res> {
  _$SyncStateUtxoSyncCopyWithImpl(this._self, this._then);

  final SyncStateUtxoSync _self;
  final $Res Function(SyncStateUtxoSync) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? chunks = null,
    Object? total = null,
  }) {
    return _then(SyncStateUtxoSync(
      chunks: null == chunks
          ? _self.chunks
          : chunks // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateTrustSync extends SyncState {
  const SyncStateTrustSync(
      {required this.processed, required this.total, final String? $type})
      : $type = $type ?? 'trustSync',
        super._();
  factory SyncStateTrustSync.fromJson(Map<String, dynamic> json) =>
      _$SyncStateTrustSyncFromJson(json);

  final int processed;
  final int total;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncStateTrustSyncCopyWith<SyncStateTrustSync> get copyWith =>
      _$SyncStateTrustSyncCopyWithImpl<SyncStateTrustSync>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateTrustSyncToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncStateTrustSync &&
            (identical(other.processed, processed) ||
                other.processed == processed) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, processed, total);

  @override
  String toString() {
    return 'SyncState.trustSync(processed: $processed, total: $total)';
  }
}

/// @nodoc
abstract mixin class $SyncStateTrustSyncCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory $SyncStateTrustSyncCopyWith(
          SyncStateTrustSync value, $Res Function(SyncStateTrustSync) _then) =
      _$SyncStateTrustSyncCopyWithImpl;
  @useResult
  $Res call({int processed, int total});
}

/// @nodoc
class _$SyncStateTrustSyncCopyWithImpl<$Res>
    implements $SyncStateTrustSyncCopyWith<$Res> {
  _$SyncStateTrustSyncCopyWithImpl(this._self, this._then);

  final SyncStateTrustSync _self;
  final $Res Function(SyncStateTrustSync) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? processed = null,
    Object? total = null,
  }) {
    return _then(SyncStateTrustSync(
      processed: null == processed
          ? _self.processed
          : processed // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateUtxoResync extends SyncState {
  const SyncStateUtxoResync({final String? $type})
      : $type = $type ?? 'utxoResync',
        super._();
  factory SyncStateUtxoResync.fromJson(Map<String, dynamic> json) =>
      _$SyncStateUtxoResyncFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateUtxoResyncToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is SyncStateUtxoResync);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SyncState.utxoResync()';
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateNotSynced extends SyncState {
  const SyncStateNotSynced({final String? $type})
      : $type = $type ?? 'notSynced',
        super._();
  factory SyncStateNotSynced.fromJson(Map<String, dynamic> json) =>
      _$SyncStateNotSyncedFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateNotSyncedToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is SyncStateNotSynced);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SyncState.notSynced()';
  }
}

/// @nodoc
@JsonSerializable()
class SyncStateSynced extends SyncState {
  const SyncStateSynced({final String? $type})
      : $type = $type ?? 'synced',
        super._();
  factory SyncStateSynced.fromJson(Map<String, dynamic> json) =>
      _$SyncStateSyncedFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  Map<String, dynamic> toJson() {
    return _$SyncStateSyncedToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is SyncStateSynced);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SyncState.synced()';
  }
}

// dart format on
