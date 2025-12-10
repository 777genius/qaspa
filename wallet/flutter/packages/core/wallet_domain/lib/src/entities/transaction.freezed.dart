// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Transaction {
  @TransactionIdConverter()
  TransactionId get id;
  TransactionKind get kind;
  @NetworkIdConverter()
  NetworkId get networkId;

  /// Transaction timestamp (Unix milliseconds)
  int get timestamp;

  /// Amount in SOMPI (always positive, direction determined by kind)
  @BigIntConverter()
  BigInt get amount;

  /// Fee paid in SOMPI (for outgoing transactions)
  @NullableBigIntConverter()
  BigInt? get fee;

  /// Sender addresses (for incoming)
  List<String>? get fromAddresses;

  /// Recipient addresses (for outgoing)
  List<String>? get toAddresses;

  /// User note
  String? get note;

  /// Custom metadata (JSON string)
  String? get metadata;

  /// Block DAA score when accepted
  int? get acceptedDaaScore;

  /// Whether transaction is confirmed
  bool get isConfirmed;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TransactionCopyWith<Transaction> get copyWith =>
      _$TransactionCopyWithImpl<Transaction>(this as Transaction, _$identity);

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Transaction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            const DeepCollectionEquality()
                .equals(other.fromAddresses, fromAddresses) &&
            const DeepCollectionEquality()
                .equals(other.toAddresses, toAddresses) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.acceptedDaaScore, acceptedDaaScore) ||
                other.acceptedDaaScore == acceptedDaaScore) &&
            (identical(other.isConfirmed, isConfirmed) ||
                other.isConfirmed == isConfirmed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      kind,
      networkId,
      timestamp,
      amount,
      fee,
      const DeepCollectionEquality().hash(fromAddresses),
      const DeepCollectionEquality().hash(toAddresses),
      note,
      metadata,
      acceptedDaaScore,
      isConfirmed);

  @override
  String toString() {
    return 'Transaction(id: $id, kind: $kind, networkId: $networkId, timestamp: $timestamp, amount: $amount, fee: $fee, fromAddresses: $fromAddresses, toAddresses: $toAddresses, note: $note, metadata: $metadata, acceptedDaaScore: $acceptedDaaScore, isConfirmed: $isConfirmed)';
  }
}

/// @nodoc
abstract mixin class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
          Transaction value, $Res Function(Transaction) _then) =
      _$TransactionCopyWithImpl;
  @useResult
  $Res call(
      {@TransactionIdConverter() TransactionId id,
      TransactionKind kind,
      @NetworkIdConverter() NetworkId networkId,
      int timestamp,
      @BigIntConverter() BigInt amount,
      @NullableBigIntConverter() BigInt? fee,
      List<String>? fromAddresses,
      List<String>? toAddresses,
      String? note,
      String? metadata,
      int? acceptedDaaScore,
      bool isConfirmed});
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res> implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._self, this._then);

  final Transaction _self;
  final $Res Function(Transaction) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kind = null,
    Object? networkId = null,
    Object? timestamp = null,
    Object? amount = null,
    Object? fee = freezed,
    Object? fromAddresses = freezed,
    Object? toAddresses = freezed,
    Object? note = freezed,
    Object? metadata = freezed,
    Object? acceptedDaaScore = freezed,
    Object? isConfirmed = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as TransactionId,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as TransactionKind,
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as NetworkId,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as BigInt,
      fee: freezed == fee
          ? _self.fee
          : fee // ignore: cast_nullable_to_non_nullable
              as BigInt?,
      fromAddresses: freezed == fromAddresses
          ? _self.fromAddresses
          : fromAddresses // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      toAddresses: freezed == toAddresses
          ? _self.toAddresses
          : toAddresses // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as String?,
      acceptedDaaScore: freezed == acceptedDaaScore
          ? _self.acceptedDaaScore
          : acceptedDaaScore // ignore: cast_nullable_to_non_nullable
              as int?,
      isConfirmed: null == isConfirmed
          ? _self.isConfirmed
          : isConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [Transaction].
extension TransactionPatterns on Transaction {
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
    TResult Function(_Transaction value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Transaction() when $default != null:
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
    TResult Function(_Transaction value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Transaction():
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
    TResult? Function(_Transaction value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Transaction() when $default != null:
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
            @TransactionIdConverter() TransactionId id,
            TransactionKind kind,
            @NetworkIdConverter() NetworkId networkId,
            int timestamp,
            @BigIntConverter() BigInt amount,
            @NullableBigIntConverter() BigInt? fee,
            List<String>? fromAddresses,
            List<String>? toAddresses,
            String? note,
            String? metadata,
            int? acceptedDaaScore,
            bool isConfirmed)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Transaction() when $default != null:
        return $default(
            _that.id,
            _that.kind,
            _that.networkId,
            _that.timestamp,
            _that.amount,
            _that.fee,
            _that.fromAddresses,
            _that.toAddresses,
            _that.note,
            _that.metadata,
            _that.acceptedDaaScore,
            _that.isConfirmed);
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
            @TransactionIdConverter() TransactionId id,
            TransactionKind kind,
            @NetworkIdConverter() NetworkId networkId,
            int timestamp,
            @BigIntConverter() BigInt amount,
            @NullableBigIntConverter() BigInt? fee,
            List<String>? fromAddresses,
            List<String>? toAddresses,
            String? note,
            String? metadata,
            int? acceptedDaaScore,
            bool isConfirmed)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Transaction():
        return $default(
            _that.id,
            _that.kind,
            _that.networkId,
            _that.timestamp,
            _that.amount,
            _that.fee,
            _that.fromAddresses,
            _that.toAddresses,
            _that.note,
            _that.metadata,
            _that.acceptedDaaScore,
            _that.isConfirmed);
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
            @TransactionIdConverter() TransactionId id,
            TransactionKind kind,
            @NetworkIdConverter() NetworkId networkId,
            int timestamp,
            @BigIntConverter() BigInt amount,
            @NullableBigIntConverter() BigInt? fee,
            List<String>? fromAddresses,
            List<String>? toAddresses,
            String? note,
            String? metadata,
            int? acceptedDaaScore,
            bool isConfirmed)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Transaction() when $default != null:
        return $default(
            _that.id,
            _that.kind,
            _that.networkId,
            _that.timestamp,
            _that.amount,
            _that.fee,
            _that.fromAddresses,
            _that.toAddresses,
            _that.note,
            _that.metadata,
            _that.acceptedDaaScore,
            _that.isConfirmed);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Transaction extends Transaction {
  const _Transaction(
      {@TransactionIdConverter() required this.id,
      required this.kind,
      @NetworkIdConverter() required this.networkId,
      required this.timestamp,
      @BigIntConverter() required this.amount,
      @NullableBigIntConverter() this.fee,
      final List<String>? fromAddresses,
      final List<String>? toAddresses,
      this.note,
      this.metadata,
      this.acceptedDaaScore,
      this.isConfirmed = false})
      : _fromAddresses = fromAddresses,
        _toAddresses = toAddresses,
        super._();
  factory _Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  @override
  @TransactionIdConverter()
  final TransactionId id;
  @override
  final TransactionKind kind;
  @override
  @NetworkIdConverter()
  final NetworkId networkId;

  /// Transaction timestamp (Unix milliseconds)
  @override
  final int timestamp;

  /// Amount in SOMPI (always positive, direction determined by kind)
  @override
  @BigIntConverter()
  final BigInt amount;

  /// Fee paid in SOMPI (for outgoing transactions)
  @override
  @NullableBigIntConverter()
  final BigInt? fee;

  /// Sender addresses (for incoming)
  final List<String>? _fromAddresses;

  /// Sender addresses (for incoming)
  @override
  List<String>? get fromAddresses {
    final value = _fromAddresses;
    if (value == null) return null;
    if (_fromAddresses is EqualUnmodifiableListView) return _fromAddresses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Recipient addresses (for outgoing)
  final List<String>? _toAddresses;

  /// Recipient addresses (for outgoing)
  @override
  List<String>? get toAddresses {
    final value = _toAddresses;
    if (value == null) return null;
    if (_toAddresses is EqualUnmodifiableListView) return _toAddresses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// User note
  @override
  final String? note;

  /// Custom metadata (JSON string)
  @override
  final String? metadata;

  /// Block DAA score when accepted
  @override
  final int? acceptedDaaScore;

  /// Whether transaction is confirmed
  @override
  @JsonKey()
  final bool isConfirmed;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TransactionCopyWith<_Transaction> get copyWith =>
      __$TransactionCopyWithImpl<_Transaction>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TransactionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Transaction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            const DeepCollectionEquality()
                .equals(other._fromAddresses, _fromAddresses) &&
            const DeepCollectionEquality()
                .equals(other._toAddresses, _toAddresses) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.acceptedDaaScore, acceptedDaaScore) ||
                other.acceptedDaaScore == acceptedDaaScore) &&
            (identical(other.isConfirmed, isConfirmed) ||
                other.isConfirmed == isConfirmed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      kind,
      networkId,
      timestamp,
      amount,
      fee,
      const DeepCollectionEquality().hash(_fromAddresses),
      const DeepCollectionEquality().hash(_toAddresses),
      note,
      metadata,
      acceptedDaaScore,
      isConfirmed);

  @override
  String toString() {
    return 'Transaction(id: $id, kind: $kind, networkId: $networkId, timestamp: $timestamp, amount: $amount, fee: $fee, fromAddresses: $fromAddresses, toAddresses: $toAddresses, note: $note, metadata: $metadata, acceptedDaaScore: $acceptedDaaScore, isConfirmed: $isConfirmed)';
  }
}

/// @nodoc
abstract mixin class _$TransactionCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$TransactionCopyWith(
          _Transaction value, $Res Function(_Transaction) _then) =
      __$TransactionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@TransactionIdConverter() TransactionId id,
      TransactionKind kind,
      @NetworkIdConverter() NetworkId networkId,
      int timestamp,
      @BigIntConverter() BigInt amount,
      @NullableBigIntConverter() BigInt? fee,
      List<String>? fromAddresses,
      List<String>? toAddresses,
      String? note,
      String? metadata,
      int? acceptedDaaScore,
      bool isConfirmed});
}

/// @nodoc
class __$TransactionCopyWithImpl<$Res> implements _$TransactionCopyWith<$Res> {
  __$TransactionCopyWithImpl(this._self, this._then);

  final _Transaction _self;
  final $Res Function(_Transaction) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? kind = null,
    Object? networkId = null,
    Object? timestamp = null,
    Object? amount = null,
    Object? fee = freezed,
    Object? fromAddresses = freezed,
    Object? toAddresses = freezed,
    Object? note = freezed,
    Object? metadata = freezed,
    Object? acceptedDaaScore = freezed,
    Object? isConfirmed = null,
  }) {
    return _then(_Transaction(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as TransactionId,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as TransactionKind,
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as NetworkId,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as BigInt,
      fee: freezed == fee
          ? _self.fee
          : fee // ignore: cast_nullable_to_non_nullable
              as BigInt?,
      fromAddresses: freezed == fromAddresses
          ? _self._fromAddresses
          : fromAddresses // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      toAddresses: freezed == toAddresses
          ? _self._toAddresses
          : toAddresses // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as String?,
      acceptedDaaScore: freezed == acceptedDaaScore
          ? _self.acceptedDaaScore
          : acceptedDaaScore // ignore: cast_nullable_to_non_nullable
              as int?,
      isConfirmed: null == isConfirmed
          ? _self.isConfirmed
          : isConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
