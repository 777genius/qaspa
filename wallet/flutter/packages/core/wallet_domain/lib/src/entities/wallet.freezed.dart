// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Wallet {
  /// Unique wallet identifier
  String get id;

  /// Wallet name (user-defined)
  String get name;

  /// Network ID (mainnet/testnet)
  String get networkId;

  /// Whether wallet is currently open/unlocked
  bool get isOpen;

  /// Wallet creation timestamp
  int get createdAt;

  /// Last accessed timestamp
  int? get lastAccessedAt;

  /// Account IDs belonging to this wallet
  List<String> get accountIds;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WalletCopyWith<Wallet> get copyWith =>
      _$WalletCopyWithImpl<Wallet>(this as Wallet, _$identity);

  /// Serializes this Wallet to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Wallet &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.isOpen, isOpen) || other.isOpen == isOpen) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastAccessedAt, lastAccessedAt) ||
                other.lastAccessedAt == lastAccessedAt) &&
            const DeepCollectionEquality()
                .equals(other.accountIds, accountIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      networkId,
      isOpen,
      createdAt,
      lastAccessedAt,
      const DeepCollectionEquality().hash(accountIds));

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, networkId: $networkId, isOpen: $isOpen, createdAt: $createdAt, lastAccessedAt: $lastAccessedAt, accountIds: $accountIds)';
  }
}

/// @nodoc
abstract mixin class $WalletCopyWith<$Res> {
  factory $WalletCopyWith(Wallet value, $Res Function(Wallet) _then) =
      _$WalletCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String networkId,
      bool isOpen,
      int createdAt,
      int? lastAccessedAt,
      List<String> accountIds});
}

/// @nodoc
class _$WalletCopyWithImpl<$Res> implements $WalletCopyWith<$Res> {
  _$WalletCopyWithImpl(this._self, this._then);

  final Wallet _self;
  final $Res Function(Wallet) _then;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? networkId = null,
    Object? isOpen = null,
    Object? createdAt = null,
    Object? lastAccessedAt = freezed,
    Object? accountIds = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as String,
      isOpen: null == isOpen
          ? _self.isOpen
          : isOpen // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      lastAccessedAt: freezed == lastAccessedAt
          ? _self.lastAccessedAt
          : lastAccessedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      accountIds: null == accountIds
          ? _self.accountIds
          : accountIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [Wallet].
extension WalletPatterns on Wallet {
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
    TResult Function(_Wallet value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Wallet() when $default != null:
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
    TResult Function(_Wallet value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Wallet():
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
    TResult? Function(_Wallet value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Wallet() when $default != null:
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
    TResult Function(String id, String name, String networkId, bool isOpen,
            int createdAt, int? lastAccessedAt, List<String> accountIds)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Wallet() when $default != null:
        return $default(_that.id, _that.name, _that.networkId, _that.isOpen,
            _that.createdAt, _that.lastAccessedAt, _that.accountIds);
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
    TResult Function(String id, String name, String networkId, bool isOpen,
            int createdAt, int? lastAccessedAt, List<String> accountIds)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Wallet():
        return $default(_that.id, _that.name, _that.networkId, _that.isOpen,
            _that.createdAt, _that.lastAccessedAt, _that.accountIds);
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
    TResult? Function(String id, String name, String networkId, bool isOpen,
            int createdAt, int? lastAccessedAt, List<String> accountIds)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Wallet() when $default != null:
        return $default(_that.id, _that.name, _that.networkId, _that.isOpen,
            _that.createdAt, _that.lastAccessedAt, _that.accountIds);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Wallet extends Wallet {
  const _Wallet(
      {required this.id,
      required this.name,
      required this.networkId,
      this.isOpen = false,
      required this.createdAt,
      this.lastAccessedAt,
      final List<String> accountIds = const []})
      : _accountIds = accountIds,
        super._();
  factory _Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  /// Unique wallet identifier
  @override
  final String id;

  /// Wallet name (user-defined)
  @override
  final String name;

  /// Network ID (mainnet/testnet)
  @override
  final String networkId;

  /// Whether wallet is currently open/unlocked
  @override
  @JsonKey()
  final bool isOpen;

  /// Wallet creation timestamp
  @override
  final int createdAt;

  /// Last accessed timestamp
  @override
  final int? lastAccessedAt;

  /// Account IDs belonging to this wallet
  final List<String> _accountIds;

  /// Account IDs belonging to this wallet
  @override
  @JsonKey()
  List<String> get accountIds {
    if (_accountIds is EqualUnmodifiableListView) return _accountIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_accountIds);
  }

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WalletCopyWith<_Wallet> get copyWith =>
      __$WalletCopyWithImpl<_Wallet>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WalletToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Wallet &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.isOpen, isOpen) || other.isOpen == isOpen) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastAccessedAt, lastAccessedAt) ||
                other.lastAccessedAt == lastAccessedAt) &&
            const DeepCollectionEquality()
                .equals(other._accountIds, _accountIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      networkId,
      isOpen,
      createdAt,
      lastAccessedAt,
      const DeepCollectionEquality().hash(_accountIds));

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, networkId: $networkId, isOpen: $isOpen, createdAt: $createdAt, lastAccessedAt: $lastAccessedAt, accountIds: $accountIds)';
  }
}

/// @nodoc
abstract mixin class _$WalletCopyWith<$Res> implements $WalletCopyWith<$Res> {
  factory _$WalletCopyWith(_Wallet value, $Res Function(_Wallet) _then) =
      __$WalletCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String networkId,
      bool isOpen,
      int createdAt,
      int? lastAccessedAt,
      List<String> accountIds});
}

/// @nodoc
class __$WalletCopyWithImpl<$Res> implements _$WalletCopyWith<$Res> {
  __$WalletCopyWithImpl(this._self, this._then);

  final _Wallet _self;
  final $Res Function(_Wallet) _then;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? networkId = null,
    Object? isOpen = null,
    Object? createdAt = null,
    Object? lastAccessedAt = freezed,
    Object? accountIds = null,
  }) {
    return _then(_Wallet(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as String,
      isOpen: null == isOpen
          ? _self.isOpen
          : isOpen // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      lastAccessedAt: freezed == lastAccessedAt
          ? _self.lastAccessedAt
          : lastAccessedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      accountIds: null == accountIds
          ? _self._accountIds
          : accountIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
mixin _$WalletDescriptor {
  String get id;
  String get name;
  String get networkId;
  int get createdAt;

  /// Create a copy of WalletDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WalletDescriptorCopyWith<WalletDescriptor> get copyWith =>
      _$WalletDescriptorCopyWithImpl<WalletDescriptor>(
          this as WalletDescriptor, _$identity);

  /// Serializes this WalletDescriptor to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WalletDescriptor &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, networkId, createdAt);

  @override
  String toString() {
    return 'WalletDescriptor(id: $id, name: $name, networkId: $networkId, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $WalletDescriptorCopyWith<$Res> {
  factory $WalletDescriptorCopyWith(
          WalletDescriptor value, $Res Function(WalletDescriptor) _then) =
      _$WalletDescriptorCopyWithImpl;
  @useResult
  $Res call({String id, String name, String networkId, int createdAt});
}

/// @nodoc
class _$WalletDescriptorCopyWithImpl<$Res>
    implements $WalletDescriptorCopyWith<$Res> {
  _$WalletDescriptorCopyWithImpl(this._self, this._then);

  final WalletDescriptor _self;
  final $Res Function(WalletDescriptor) _then;

  /// Create a copy of WalletDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? networkId = null,
    Object? createdAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [WalletDescriptor].
extension WalletDescriptorPatterns on WalletDescriptor {
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
    TResult Function(_WalletDescriptor value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WalletDescriptor() when $default != null:
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
    TResult Function(_WalletDescriptor value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletDescriptor():
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
    TResult? Function(_WalletDescriptor value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletDescriptor() when $default != null:
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
    TResult Function(String id, String name, String networkId, int createdAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WalletDescriptor() when $default != null:
        return $default(_that.id, _that.name, _that.networkId, _that.createdAt);
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
    TResult Function(String id, String name, String networkId, int createdAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletDescriptor():
        return $default(_that.id, _that.name, _that.networkId, _that.createdAt);
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
    TResult? Function(String id, String name, String networkId, int createdAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletDescriptor() when $default != null:
        return $default(_that.id, _that.name, _that.networkId, _that.createdAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WalletDescriptor extends WalletDescriptor {
  const _WalletDescriptor(
      {required this.id,
      required this.name,
      required this.networkId,
      required this.createdAt})
      : super._();
  factory _WalletDescriptor.fromJson(Map<String, dynamic> json) =>
      _$WalletDescriptorFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String networkId;
  @override
  final int createdAt;

  /// Create a copy of WalletDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WalletDescriptorCopyWith<_WalletDescriptor> get copyWith =>
      __$WalletDescriptorCopyWithImpl<_WalletDescriptor>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WalletDescriptorToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WalletDescriptor &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.networkId, networkId) ||
                other.networkId == networkId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, networkId, createdAt);

  @override
  String toString() {
    return 'WalletDescriptor(id: $id, name: $name, networkId: $networkId, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$WalletDescriptorCopyWith<$Res>
    implements $WalletDescriptorCopyWith<$Res> {
  factory _$WalletDescriptorCopyWith(
          _WalletDescriptor value, $Res Function(_WalletDescriptor) _then) =
      __$WalletDescriptorCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String name, String networkId, int createdAt});
}

/// @nodoc
class __$WalletDescriptorCopyWithImpl<$Res>
    implements _$WalletDescriptorCopyWith<$Res> {
  __$WalletDescriptorCopyWithImpl(this._self, this._then);

  final _WalletDescriptor _self;
  final $Res Function(_WalletDescriptor) _then;

  /// Create a copy of WalletDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? networkId = null,
    Object? createdAt = null,
  }) {
    return _then(_WalletDescriptor(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      networkId: null == networkId
          ? _self.networkId
          : networkId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
