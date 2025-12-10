// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'network_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NetworkInfo {
  @NetworkIdConverter()
  NetworkId get networkId;
  int get blockCount;
  int get headerCount;
  int get daaScore;
  int get difficulty;
  String get nodeVersion;
  bool get isSynced;
  int? get peerCount;
  int? get mempoolSize;

  /// Create a copy of NetworkInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NetworkInfoCopyWith<NetworkInfo> get copyWith =>
      _$NetworkInfoCopyWithImpl<NetworkInfo>(this as NetworkInfo, _$identity);

  /// Serializes this NetworkInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NetworkInfo &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.blockCount, blockCount) ||
                other.blockCount == blockCount) &&
            (identical(other.headerCount, headerCount) ||
                other.headerCount == headerCount) &&
            (identical(other.daaScore, daaScore) ||
                other.daaScore == daaScore) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.nodeVersion, nodeVersion) ||
                other.nodeVersion == nodeVersion) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced) &&
            (identical(other.peerCount, peerCount) ||
                other.peerCount == peerCount) &&
            (identical(other.mempoolSize, mempoolSize) ||
                other.mempoolSize == mempoolSize));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      networkId,
      blockCount,
      headerCount,
      daaScore,
      difficulty,
      nodeVersion,
      isSynced,
      peerCount,
      mempoolSize);

  @override
  String toString() {
    return 'NetworkInfo(networkId: $networkId, blockCount: $blockCount, headerCount: $headerCount, daaScore: $daaScore, difficulty: $difficulty, nodeVersion: $nodeVersion, isSynced: $isSynced, peerCount: $peerCount, mempoolSize: $mempoolSize)';
  }
}

/// @nodoc
abstract mixin class $NetworkInfoCopyWith<$Res> {
  factory $NetworkInfoCopyWith(
          NetworkInfo value, $Res Function(NetworkInfo) _then) =
      _$NetworkInfoCopyWithImpl;
  @useResult
  $Res call(
      {@NetworkIdConverter() NetworkId networkId,
      int blockCount,
      int headerCount,
      int daaScore,
      int difficulty,
      String nodeVersion,
      bool isSynced,
      int? peerCount,
      int? mempoolSize});
}

/// @nodoc
class _$NetworkInfoCopyWithImpl<$Res> implements $NetworkInfoCopyWith<$Res> {
  _$NetworkInfoCopyWithImpl(this._self, this._then);

  final NetworkInfo _self;
  final $Res Function(NetworkInfo) _then;

  /// Create a copy of NetworkInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? networkId = null,
    Object? blockCount = null,
    Object? headerCount = null,
    Object? daaScore = null,
    Object? difficulty = null,
    Object? nodeVersion = null,
    Object? isSynced = null,
    Object? peerCount = freezed,
    Object? mempoolSize = freezed,
  }) {
    return _then(_self.copyWith(
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as NetworkId,
      blockCount: null == blockCount
          ? _self.blockCount
          : blockCount // ignore: cast_nullable_to_non_nullable
              as int,
      headerCount: null == headerCount
          ? _self.headerCount
          : headerCount // ignore: cast_nullable_to_non_nullable
              as int,
      daaScore: null == daaScore
          ? _self.daaScore
          : daaScore // ignore: cast_nullable_to_non_nullable
              as int,
      difficulty: null == difficulty
          ? _self.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as int,
      nodeVersion: null == nodeVersion
          ? _self.nodeVersion
          : nodeVersion // ignore: cast_nullable_to_non_nullable
              as String,
      isSynced: null == isSynced
          ? _self.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
      peerCount: freezed == peerCount
          ? _self.peerCount
          : peerCount // ignore: cast_nullable_to_non_nullable
              as int?,
      mempoolSize: freezed == mempoolSize
          ? _self.mempoolSize
          : mempoolSize // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [NetworkInfo].
extension NetworkInfoPatterns on NetworkInfo {
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
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_NetworkInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NetworkInfo() when $default != null:
        return $default(_that);
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
  TResult map<TResult extends Object?>(
    TResult Function(_NetworkInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NetworkInfo():
        return $default(_that);
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
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_NetworkInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NetworkInfo() when $default != null:
        return $default(_that);
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
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            @NetworkIdConverter() NetworkId networkId,
            int blockCount,
            int headerCount,
            int daaScore,
            int difficulty,
            String nodeVersion,
            bool isSynced,
            int? peerCount,
            int? mempoolSize)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NetworkInfo() when $default != null:
        return $default(
            _that.networkId,
            _that.blockCount,
            _that.headerCount,
            _that.daaScore,
            _that.difficulty,
            _that.nodeVersion,
            _that.isSynced,
            _that.peerCount,
            _that.mempoolSize);
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
  TResult when<TResult extends Object?>(
    TResult Function(
            @NetworkIdConverter() NetworkId networkId,
            int blockCount,
            int headerCount,
            int daaScore,
            int difficulty,
            String nodeVersion,
            bool isSynced,
            int? peerCount,
            int? mempoolSize)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NetworkInfo():
        return $default(
            _that.networkId,
            _that.blockCount,
            _that.headerCount,
            _that.daaScore,
            _that.difficulty,
            _that.nodeVersion,
            _that.isSynced,
            _that.peerCount,
            _that.mempoolSize);
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
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            @NetworkIdConverter() NetworkId networkId,
            int blockCount,
            int headerCount,
            int daaScore,
            int difficulty,
            String nodeVersion,
            bool isSynced,
            int? peerCount,
            int? mempoolSize)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NetworkInfo() when $default != null:
        return $default(
            _that.networkId,
            _that.blockCount,
            _that.headerCount,
            _that.daaScore,
            _that.difficulty,
            _that.nodeVersion,
            _that.isSynced,
            _that.peerCount,
            _that.mempoolSize);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NetworkInfo extends NetworkInfo {
  const _NetworkInfo(
      {@NetworkIdConverter() required this.networkId,
      required this.blockCount,
      required this.headerCount,
      required this.daaScore,
      required this.difficulty,
      required this.nodeVersion,
      required this.isSynced,
      this.peerCount,
      this.mempoolSize})
      : super._();
  factory _NetworkInfo.fromJson(Map<String, dynamic> json) =>
      _$NetworkInfoFromJson(json);

  @override
  @NetworkIdConverter()
  final NetworkId networkId;
  @override
  final int blockCount;
  @override
  final int headerCount;
  @override
  final int daaScore;
  @override
  final int difficulty;
  @override
  final String nodeVersion;
  @override
  final bool isSynced;
  @override
  final int? peerCount;
  @override
  final int? mempoolSize;

  /// Create a copy of NetworkInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NetworkInfoCopyWith<_NetworkInfo> get copyWith =>
      __$NetworkInfoCopyWithImpl<_NetworkInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NetworkInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NetworkInfo &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.blockCount, blockCount) ||
                other.blockCount == blockCount) &&
            (identical(other.headerCount, headerCount) ||
                other.headerCount == headerCount) &&
            (identical(other.daaScore, daaScore) ||
                other.daaScore == daaScore) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.nodeVersion, nodeVersion) ||
                other.nodeVersion == nodeVersion) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced) &&
            (identical(other.peerCount, peerCount) ||
                other.peerCount == peerCount) &&
            (identical(other.mempoolSize, mempoolSize) ||
                other.mempoolSize == mempoolSize));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      networkId,
      blockCount,
      headerCount,
      daaScore,
      difficulty,
      nodeVersion,
      isSynced,
      peerCount,
      mempoolSize);

  @override
  String toString() {
    return 'NetworkInfo(networkId: $networkId, blockCount: $blockCount, headerCount: $headerCount, daaScore: $daaScore, difficulty: $difficulty, nodeVersion: $nodeVersion, isSynced: $isSynced, peerCount: $peerCount, mempoolSize: $mempoolSize)';
  }
}

/// @nodoc
abstract mixin class _$NetworkInfoCopyWith<$Res>
    implements $NetworkInfoCopyWith<$Res> {
  factory _$NetworkInfoCopyWith(
          _NetworkInfo value, $Res Function(_NetworkInfo) _then) =
      __$NetworkInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@NetworkIdConverter() NetworkId networkId,
      int blockCount,
      int headerCount,
      int daaScore,
      int difficulty,
      String nodeVersion,
      bool isSynced,
      int? peerCount,
      int? mempoolSize});
}

/// @nodoc
class __$NetworkInfoCopyWithImpl<$Res> implements _$NetworkInfoCopyWith<$Res> {
  __$NetworkInfoCopyWithImpl(this._self, this._then);

  final _NetworkInfo _self;
  final $Res Function(_NetworkInfo) _then;

  /// Create a copy of NetworkInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? networkId = null,
    Object? blockCount = null,
    Object? headerCount = null,
    Object? daaScore = null,
    Object? difficulty = null,
    Object? nodeVersion = null,
    Object? isSynced = null,
    Object? peerCount = freezed,
    Object? mempoolSize = freezed,
  }) {
    return _then(_NetworkInfo(
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as NetworkId,
      blockCount: null == blockCount
          ? _self.blockCount
          : blockCount // ignore: cast_nullable_to_non_nullable
              as int,
      headerCount: null == headerCount
          ? _self.headerCount
          : headerCount // ignore: cast_nullable_to_non_nullable
              as int,
      daaScore: null == daaScore
          ? _self.daaScore
          : daaScore // ignore: cast_nullable_to_non_nullable
              as int,
      difficulty: null == difficulty
          ? _self.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as int,
      nodeVersion: null == nodeVersion
          ? _self.nodeVersion
          : nodeVersion // ignore: cast_nullable_to_non_nullable
              as String,
      isSynced: null == isSynced
          ? _self.isSynced
          : isSynced // ignore: cast_nullable_to_non_nullable
              as bool,
      peerCount: freezed == peerCount
          ? _self.peerCount
          : peerCount // ignore: cast_nullable_to_non_nullable
              as int?,
      mempoolSize: freezed == mempoolSize
          ? _self.mempoolSize
          : mempoolSize // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

// dart format on
