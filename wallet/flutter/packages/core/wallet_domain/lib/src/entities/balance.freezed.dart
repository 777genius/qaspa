// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'balance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Balance {
  /// Confirmed/mature balance in SOMPI (1 KAS = 100,000,000 SOMPI)
  @BigIntConverter()
  BigInt get mature;

  /// Pending incoming balance in SOMPI
  @BigIntConverter()
  BigInt get pending;

  /// Outgoing balance (being sent) in SOMPI
  @BigIntConverter()
  BigInt get outgoing;

  /// Number of mature UTXOs
  int get matureUtxoCount;

  /// Number of pending UTXOs
  int get pendingUtxoCount;

  /// Number of stasis UTXOs (coinbase during maturity period)
  int get stasisUtxoCount;

  /// Create a copy of Balance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BalanceCopyWith<Balance> get copyWith =>
      _$BalanceCopyWithImpl<Balance>(this as Balance, _$identity);

  /// Serializes this Balance to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Balance &&
            (identical(other.mature, mature) || other.mature == mature) &&
            (identical(other.pending, pending) || other.pending == pending) &&
            (identical(other.outgoing, outgoing) ||
                other.outgoing == outgoing) &&
            (identical(other.matureUtxoCount, matureUtxoCount) ||
                other.matureUtxoCount == matureUtxoCount) &&
            (identical(other.pendingUtxoCount, pendingUtxoCount) ||
                other.pendingUtxoCount == pendingUtxoCount) &&
            (identical(other.stasisUtxoCount, stasisUtxoCount) ||
                other.stasisUtxoCount == stasisUtxoCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mature, pending, outgoing,
      matureUtxoCount, pendingUtxoCount, stasisUtxoCount);

  @override
  String toString() {
    return 'Balance(mature: $mature, pending: $pending, outgoing: $outgoing, matureUtxoCount: $matureUtxoCount, pendingUtxoCount: $pendingUtxoCount, stasisUtxoCount: $stasisUtxoCount)';
  }
}

/// @nodoc
abstract mixin class $BalanceCopyWith<$Res> {
  factory $BalanceCopyWith(Balance value, $Res Function(Balance) _then) =
      _$BalanceCopyWithImpl;
  @useResult
  $Res call(
      {@BigIntConverter() BigInt mature,
      @BigIntConverter() BigInt pending,
      @BigIntConverter() BigInt outgoing,
      int matureUtxoCount,
      int pendingUtxoCount,
      int stasisUtxoCount});
}

/// @nodoc
class _$BalanceCopyWithImpl<$Res> implements $BalanceCopyWith<$Res> {
  _$BalanceCopyWithImpl(this._self, this._then);

  final Balance _self;
  final $Res Function(Balance) _then;

  /// Create a copy of Balance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mature = null,
    Object? pending = null,
    Object? outgoing = null,
    Object? matureUtxoCount = null,
    Object? pendingUtxoCount = null,
    Object? stasisUtxoCount = null,
  }) {
    return _then(_self.copyWith(
      mature: null == mature
          ? _self.mature
          : mature // ignore: cast_nullable_to_non_nullable
              as BigInt,
      pending: null == pending
          ? _self.pending
          : pending // ignore: cast_nullable_to_non_nullable
              as BigInt,
      outgoing: null == outgoing
          ? _self.outgoing
          : outgoing // ignore: cast_nullable_to_non_nullable
              as BigInt,
      matureUtxoCount: null == matureUtxoCount
          ? _self.matureUtxoCount
          : matureUtxoCount // ignore: cast_nullable_to_non_nullable
              as int,
      pendingUtxoCount: null == pendingUtxoCount
          ? _self.pendingUtxoCount
          : pendingUtxoCount // ignore: cast_nullable_to_non_nullable
              as int,
      stasisUtxoCount: null == stasisUtxoCount
          ? _self.stasisUtxoCount
          : stasisUtxoCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [Balance].
extension BalancePatterns on Balance {
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
    TResult Function(_Balance value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Balance() when $default != null:
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
    TResult Function(_Balance value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Balance():
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
    TResult? Function(_Balance value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Balance() when $default != null:
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
            @BigIntConverter() BigInt mature,
            @BigIntConverter() BigInt pending,
            @BigIntConverter() BigInt outgoing,
            int matureUtxoCount,
            int pendingUtxoCount,
            int stasisUtxoCount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Balance() when $default != null:
        return $default(
            _that.mature,
            _that.pending,
            _that.outgoing,
            _that.matureUtxoCount,
            _that.pendingUtxoCount,
            _that.stasisUtxoCount);
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
            @BigIntConverter() BigInt mature,
            @BigIntConverter() BigInt pending,
            @BigIntConverter() BigInt outgoing,
            int matureUtxoCount,
            int pendingUtxoCount,
            int stasisUtxoCount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Balance():
        return $default(
            _that.mature,
            _that.pending,
            _that.outgoing,
            _that.matureUtxoCount,
            _that.pendingUtxoCount,
            _that.stasisUtxoCount);
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
            @BigIntConverter() BigInt mature,
            @BigIntConverter() BigInt pending,
            @BigIntConverter() BigInt outgoing,
            int matureUtxoCount,
            int pendingUtxoCount,
            int stasisUtxoCount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Balance() when $default != null:
        return $default(
            _that.mature,
            _that.pending,
            _that.outgoing,
            _that.matureUtxoCount,
            _that.pendingUtxoCount,
            _that.stasisUtxoCount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Balance extends Balance {
  const _Balance(
      {@BigIntConverter() required this.mature,
      @BigIntConverter() required this.pending,
      @BigIntConverter() required this.outgoing,
      required this.matureUtxoCount,
      required this.pendingUtxoCount,
      required this.stasisUtxoCount})
      : super._();
  factory _Balance.fromJson(Map<String, dynamic> json) =>
      _$BalanceFromJson(json);

  /// Confirmed/mature balance in SOMPI (1 KAS = 100,000,000 SOMPI)
  @override
  @BigIntConverter()
  final BigInt mature;

  /// Pending incoming balance in SOMPI
  @override
  @BigIntConverter()
  final BigInt pending;

  /// Outgoing balance (being sent) in SOMPI
  @override
  @BigIntConverter()
  final BigInt outgoing;

  /// Number of mature UTXOs
  @override
  final int matureUtxoCount;

  /// Number of pending UTXOs
  @override
  final int pendingUtxoCount;

  /// Number of stasis UTXOs (coinbase during maturity period)
  @override
  final int stasisUtxoCount;

  /// Create a copy of Balance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BalanceCopyWith<_Balance> get copyWith =>
      __$BalanceCopyWithImpl<_Balance>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BalanceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Balance &&
            (identical(other.mature, mature) || other.mature == mature) &&
            (identical(other.pending, pending) || other.pending == pending) &&
            (identical(other.outgoing, outgoing) ||
                other.outgoing == outgoing) &&
            (identical(other.matureUtxoCount, matureUtxoCount) ||
                other.matureUtxoCount == matureUtxoCount) &&
            (identical(other.pendingUtxoCount, pendingUtxoCount) ||
                other.pendingUtxoCount == pendingUtxoCount) &&
            (identical(other.stasisUtxoCount, stasisUtxoCount) ||
                other.stasisUtxoCount == stasisUtxoCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mature, pending, outgoing,
      matureUtxoCount, pendingUtxoCount, stasisUtxoCount);

  @override
  String toString() {
    return 'Balance(mature: $mature, pending: $pending, outgoing: $outgoing, matureUtxoCount: $matureUtxoCount, pendingUtxoCount: $pendingUtxoCount, stasisUtxoCount: $stasisUtxoCount)';
  }
}

/// @nodoc
abstract mixin class _$BalanceCopyWith<$Res> implements $BalanceCopyWith<$Res> {
  factory _$BalanceCopyWith(_Balance value, $Res Function(_Balance) _then) =
      __$BalanceCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@BigIntConverter() BigInt mature,
      @BigIntConverter() BigInt pending,
      @BigIntConverter() BigInt outgoing,
      int matureUtxoCount,
      int pendingUtxoCount,
      int stasisUtxoCount});
}

/// @nodoc
class __$BalanceCopyWithImpl<$Res> implements _$BalanceCopyWith<$Res> {
  __$BalanceCopyWithImpl(this._self, this._then);

  final _Balance _self;
  final $Res Function(_Balance) _then;

  /// Create a copy of Balance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? mature = null,
    Object? pending = null,
    Object? outgoing = null,
    Object? matureUtxoCount = null,
    Object? pendingUtxoCount = null,
    Object? stasisUtxoCount = null,
  }) {
    return _then(_Balance(
      mature: null == mature
          ? _self.mature
          : mature // ignore: cast_nullable_to_non_nullable
              as BigInt,
      pending: null == pending
          ? _self.pending
          : pending // ignore: cast_nullable_to_non_nullable
              as BigInt,
      outgoing: null == outgoing
          ? _self.outgoing
          : outgoing // ignore: cast_nullable_to_non_nullable
              as BigInt,
      matureUtxoCount: null == matureUtxoCount
          ? _self.matureUtxoCount
          : matureUtxoCount // ignore: cast_nullable_to_non_nullable
              as int,
      pendingUtxoCount: null == pendingUtxoCount
          ? _self.pendingUtxoCount
          : pendingUtxoCount // ignore: cast_nullable_to_non_nullable
              as int,
      stasisUtxoCount: null == stasisUtxoCount
          ? _self.stasisUtxoCount
          : stasisUtxoCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
