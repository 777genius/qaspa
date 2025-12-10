// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'utxo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Utxo {
  @TransactionIdConverter()
  TransactionId get transactionId;
  int get index;
  @BigIntConverter()
  BigInt get amount;
  String get address;
  int get blockDaaScore;
  bool get isCoinbase;
  bool get isLocked;

  /// Create a copy of Utxo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UtxoCopyWith<Utxo> get copyWith =>
      _$UtxoCopyWithImpl<Utxo>(this as Utxo, _$identity);

  /// Serializes this Utxo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Utxo &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.blockDaaScore, blockDaaScore) ||
                other.blockDaaScore == blockDaaScore) &&
            (identical(other.isCoinbase, isCoinbase) ||
                other.isCoinbase == isCoinbase) &&
            (identical(other.isLocked, isLocked) ||
                other.isLocked == isLocked));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, transactionId, index, amount,
      address, blockDaaScore, isCoinbase, isLocked);

  @override
  String toString() {
    return 'Utxo(transactionId: $transactionId, index: $index, amount: $amount, address: $address, blockDaaScore: $blockDaaScore, isCoinbase: $isCoinbase, isLocked: $isLocked)';
  }
}

/// @nodoc
abstract mixin class $UtxoCopyWith<$Res> {
  factory $UtxoCopyWith(Utxo value, $Res Function(Utxo) _then) =
      _$UtxoCopyWithImpl;
  @useResult
  $Res call(
      {@TransactionIdConverter() TransactionId transactionId,
      int index,
      @BigIntConverter() BigInt amount,
      String address,
      int blockDaaScore,
      bool isCoinbase,
      bool isLocked});
}

/// @nodoc
class _$UtxoCopyWithImpl<$Res> implements $UtxoCopyWith<$Res> {
  _$UtxoCopyWithImpl(this._self, this._then);

  final Utxo _self;
  final $Res Function(Utxo) _then;

  /// Create a copy of Utxo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactionId = null,
    Object? index = null,
    Object? amount = null,
    Object? address = null,
    Object? blockDaaScore = null,
    Object? isCoinbase = null,
    Object? isLocked = null,
  }) {
    return _then(_self.copyWith(
      transactionId: null == transactionId
          ? _self.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as TransactionId,
      index: null == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as BigInt,
      address: null == address
          ? _self.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      blockDaaScore: null == blockDaaScore
          ? _self.blockDaaScore
          : blockDaaScore // ignore: cast_nullable_to_non_nullable
              as int,
      isCoinbase: null == isCoinbase
          ? _self.isCoinbase
          : isCoinbase // ignore: cast_nullable_to_non_nullable
              as bool,
      isLocked: null == isLocked
          ? _self.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [Utxo].
extension UtxoPatterns on Utxo {
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
    TResult Function(_Utxo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Utxo() when $default != null:
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
    TResult Function(_Utxo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Utxo():
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
    TResult? Function(_Utxo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Utxo() when $default != null:
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
            @TransactionIdConverter() TransactionId transactionId,
            int index,
            @BigIntConverter() BigInt amount,
            String address,
            int blockDaaScore,
            bool isCoinbase,
            bool isLocked)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Utxo() when $default != null:
        return $default(
            _that.transactionId,
            _that.index,
            _that.amount,
            _that.address,
            _that.blockDaaScore,
            _that.isCoinbase,
            _that.isLocked);
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
            @TransactionIdConverter() TransactionId transactionId,
            int index,
            @BigIntConverter() BigInt amount,
            String address,
            int blockDaaScore,
            bool isCoinbase,
            bool isLocked)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Utxo():
        return $default(
            _that.transactionId,
            _that.index,
            _that.amount,
            _that.address,
            _that.blockDaaScore,
            _that.isCoinbase,
            _that.isLocked);
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
            @TransactionIdConverter() TransactionId transactionId,
            int index,
            @BigIntConverter() BigInt amount,
            String address,
            int blockDaaScore,
            bool isCoinbase,
            bool isLocked)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Utxo() when $default != null:
        return $default(
            _that.transactionId,
            _that.index,
            _that.amount,
            _that.address,
            _that.blockDaaScore,
            _that.isCoinbase,
            _that.isLocked);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Utxo extends Utxo {
  const _Utxo(
      {@TransactionIdConverter() required this.transactionId,
      required this.index,
      @BigIntConverter() required this.amount,
      required this.address,
      required this.blockDaaScore,
      required this.isCoinbase,
      required this.isLocked})
      : super._();
  factory _Utxo.fromJson(Map<String, dynamic> json) => _$UtxoFromJson(json);

  @override
  @TransactionIdConverter()
  final TransactionId transactionId;
  @override
  final int index;
  @override
  @BigIntConverter()
  final BigInt amount;
  @override
  final String address;
  @override
  final int blockDaaScore;
  @override
  final bool isCoinbase;
  @override
  final bool isLocked;

  /// Create a copy of Utxo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UtxoCopyWith<_Utxo> get copyWith =>
      __$UtxoCopyWithImpl<_Utxo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UtxoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Utxo &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.blockDaaScore, blockDaaScore) ||
                other.blockDaaScore == blockDaaScore) &&
            (identical(other.isCoinbase, isCoinbase) ||
                other.isCoinbase == isCoinbase) &&
            (identical(other.isLocked, isLocked) ||
                other.isLocked == isLocked));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, transactionId, index, amount,
      address, blockDaaScore, isCoinbase, isLocked);

  @override
  String toString() {
    return 'Utxo(transactionId: $transactionId, index: $index, amount: $amount, address: $address, blockDaaScore: $blockDaaScore, isCoinbase: $isCoinbase, isLocked: $isLocked)';
  }
}

/// @nodoc
abstract mixin class _$UtxoCopyWith<$Res> implements $UtxoCopyWith<$Res> {
  factory _$UtxoCopyWith(_Utxo value, $Res Function(_Utxo) _then) =
      __$UtxoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@TransactionIdConverter() TransactionId transactionId,
      int index,
      @BigIntConverter() BigInt amount,
      String address,
      int blockDaaScore,
      bool isCoinbase,
      bool isLocked});
}

/// @nodoc
class __$UtxoCopyWithImpl<$Res> implements _$UtxoCopyWith<$Res> {
  __$UtxoCopyWithImpl(this._self, this._then);

  final _Utxo _self;
  final $Res Function(_Utxo) _then;

  /// Create a copy of Utxo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? transactionId = null,
    Object? index = null,
    Object? amount = null,
    Object? address = null,
    Object? blockDaaScore = null,
    Object? isCoinbase = null,
    Object? isLocked = null,
  }) {
    return _then(_Utxo(
      transactionId: null == transactionId
          ? _self.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as TransactionId,
      index: null == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as BigInt,
      address: null == address
          ? _self.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      blockDaaScore: null == blockDaaScore
          ? _self.blockDaaScore
          : blockDaaScore // ignore: cast_nullable_to_non_nullable
              as int,
      isCoinbase: null == isCoinbase
          ? _self.isCoinbase
          : isCoinbase // ignore: cast_nullable_to_non_nullable
              as bool,
      isLocked: null == isLocked
          ? _self.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$UtxoSet {
  List<Utxo> get mature;
  List<Utxo> get pending;
  List<Utxo> get stasis;

  /// Create a copy of UtxoSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UtxoSetCopyWith<UtxoSet> get copyWith =>
      _$UtxoSetCopyWithImpl<UtxoSet>(this as UtxoSet, _$identity);

  /// Serializes this UtxoSet to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UtxoSet &&
            const DeepCollectionEquality().equals(other.mature, mature) &&
            const DeepCollectionEquality().equals(other.pending, pending) &&
            const DeepCollectionEquality().equals(other.stasis, stasis));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(mature),
      const DeepCollectionEquality().hash(pending),
      const DeepCollectionEquality().hash(stasis));

  @override
  String toString() {
    return 'UtxoSet(mature: $mature, pending: $pending, stasis: $stasis)';
  }
}

/// @nodoc
abstract mixin class $UtxoSetCopyWith<$Res> {
  factory $UtxoSetCopyWith(UtxoSet value, $Res Function(UtxoSet) _then) =
      _$UtxoSetCopyWithImpl;
  @useResult
  $Res call({List<Utxo> mature, List<Utxo> pending, List<Utxo> stasis});
}

/// @nodoc
class _$UtxoSetCopyWithImpl<$Res> implements $UtxoSetCopyWith<$Res> {
  _$UtxoSetCopyWithImpl(this._self, this._then);

  final UtxoSet _self;
  final $Res Function(UtxoSet) _then;

  /// Create a copy of UtxoSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mature = null,
    Object? pending = null,
    Object? stasis = null,
  }) {
    return _then(_self.copyWith(
      mature: null == mature
          ? _self.mature
          : mature // ignore: cast_nullable_to_non_nullable
              as List<Utxo>,
      pending: null == pending
          ? _self.pending
          : pending // ignore: cast_nullable_to_non_nullable
              as List<Utxo>,
      stasis: null == stasis
          ? _self.stasis
          : stasis // ignore: cast_nullable_to_non_nullable
              as List<Utxo>,
    ));
  }
}

/// Adds pattern-matching-related methods to [UtxoSet].
extension UtxoSetPatterns on UtxoSet {
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
    TResult Function(_UtxoSet value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UtxoSet() when $default != null:
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
    TResult Function(_UtxoSet value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UtxoSet():
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
    TResult? Function(_UtxoSet value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UtxoSet() when $default != null:
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
    TResult Function(List<Utxo> mature, List<Utxo> pending, List<Utxo> stasis)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UtxoSet() when $default != null:
        return $default(_that.mature, _that.pending, _that.stasis);
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
    TResult Function(List<Utxo> mature, List<Utxo> pending, List<Utxo> stasis)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UtxoSet():
        return $default(_that.mature, _that.pending, _that.stasis);
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
    TResult? Function(List<Utxo> mature, List<Utxo> pending, List<Utxo> stasis)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UtxoSet() when $default != null:
        return $default(_that.mature, _that.pending, _that.stasis);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _UtxoSet extends UtxoSet {
  const _UtxoSet(
      {required final List<Utxo> mature,
      required final List<Utxo> pending,
      required final List<Utxo> stasis})
      : _mature = mature,
        _pending = pending,
        _stasis = stasis,
        super._();
  factory _UtxoSet.fromJson(Map<String, dynamic> json) =>
      _$UtxoSetFromJson(json);

  final List<Utxo> _mature;
  @override
  List<Utxo> get mature {
    if (_mature is EqualUnmodifiableListView) return _mature;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mature);
  }

  final List<Utxo> _pending;
  @override
  List<Utxo> get pending {
    if (_pending is EqualUnmodifiableListView) return _pending;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pending);
  }

  final List<Utxo> _stasis;
  @override
  List<Utxo> get stasis {
    if (_stasis is EqualUnmodifiableListView) return _stasis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_stasis);
  }

  /// Create a copy of UtxoSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UtxoSetCopyWith<_UtxoSet> get copyWith =>
      __$UtxoSetCopyWithImpl<_UtxoSet>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UtxoSetToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UtxoSet &&
            const DeepCollectionEquality().equals(other._mature, _mature) &&
            const DeepCollectionEquality().equals(other._pending, _pending) &&
            const DeepCollectionEquality().equals(other._stasis, _stasis));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_mature),
      const DeepCollectionEquality().hash(_pending),
      const DeepCollectionEquality().hash(_stasis));

  @override
  String toString() {
    return 'UtxoSet(mature: $mature, pending: $pending, stasis: $stasis)';
  }
}

/// @nodoc
abstract mixin class _$UtxoSetCopyWith<$Res> implements $UtxoSetCopyWith<$Res> {
  factory _$UtxoSetCopyWith(_UtxoSet value, $Res Function(_UtxoSet) _then) =
      __$UtxoSetCopyWithImpl;
  @override
  @useResult
  $Res call({List<Utxo> mature, List<Utxo> pending, List<Utxo> stasis});
}

/// @nodoc
class __$UtxoSetCopyWithImpl<$Res> implements _$UtxoSetCopyWith<$Res> {
  __$UtxoSetCopyWithImpl(this._self, this._then);

  final _UtxoSet _self;
  final $Res Function(_UtxoSet) _then;

  /// Create a copy of UtxoSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? mature = null,
    Object? pending = null,
    Object? stasis = null,
  }) {
    return _then(_UtxoSet(
      mature: null == mature
          ? _self._mature
          : mature // ignore: cast_nullable_to_non_nullable
              as List<Utxo>,
      pending: null == pending
          ? _self._pending
          : pending // ignore: cast_nullable_to_non_nullable
              as List<Utxo>,
      stasis: null == stasis
          ? _self._stasis
          : stasis // ignore: cast_nullable_to_non_nullable
              as List<Utxo>,
    ));
  }
}

// dart format on
