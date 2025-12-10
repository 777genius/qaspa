// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Account {
  /// Unique account identifier
  String get id;

  /// Parent wallet ID
  String get walletId;

  /// Account name (user-defined)
  String get name;

  /// Account kind/type
  AccountKind get kind;

  /// Account index in derivation path
  int get accountIndex;

  /// Whether account is active/enabled
  bool get isActive;

  /// Receive address index (for BIP-32)
  int get receiveAddressIndex;

  /// Change address index (for BIP-32)
  int get changeAddressIndex;

  /// Current balance (may be null if not loaded)
  Balance? get balance;

  /// Current receive address
  String? get receiveAddress;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AccountCopyWith<Account> get copyWith =>
      _$AccountCopyWithImpl<Account>(this as Account, _$identity);

  /// Serializes this Account to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Account &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.walletId, walletId) ||
                other.walletId == walletId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.accountIndex, accountIndex) ||
                other.accountIndex == accountIndex) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.receiveAddressIndex, receiveAddressIndex) ||
                other.receiveAddressIndex == receiveAddressIndex) &&
            (identical(other.changeAddressIndex, changeAddressIndex) ||
                other.changeAddressIndex == changeAddressIndex) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.receiveAddress, receiveAddress) ||
                other.receiveAddress == receiveAddress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      walletId,
      name,
      kind,
      accountIndex,
      isActive,
      receiveAddressIndex,
      changeAddressIndex,
      balance,
      receiveAddress);

  @override
  String toString() {
    return 'Account(id: $id, walletId: $walletId, name: $name, kind: $kind, accountIndex: $accountIndex, isActive: $isActive, receiveAddressIndex: $receiveAddressIndex, changeAddressIndex: $changeAddressIndex, balance: $balance, receiveAddress: $receiveAddress)';
  }
}

/// @nodoc
abstract mixin class $AccountCopyWith<$Res> {
  factory $AccountCopyWith(Account value, $Res Function(Account) _then) =
      _$AccountCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String walletId,
      String name,
      AccountKind kind,
      int accountIndex,
      bool isActive,
      int receiveAddressIndex,
      int changeAddressIndex,
      Balance? balance,
      String? receiveAddress});

  $BalanceCopyWith<$Res>? get balance;
}

/// @nodoc
class _$AccountCopyWithImpl<$Res> implements $AccountCopyWith<$Res> {
  _$AccountCopyWithImpl(this._self, this._then);

  final Account _self;
  final $Res Function(Account) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? walletId = null,
    Object? name = null,
    Object? kind = null,
    Object? accountIndex = null,
    Object? isActive = null,
    Object? receiveAddressIndex = null,
    Object? changeAddressIndex = null,
    Object? balance = freezed,
    Object? receiveAddress = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      walletId: null == walletId
          ? _self.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as AccountKind,
      accountIndex: null == accountIndex
          ? _self.accountIndex
          : accountIndex // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      receiveAddressIndex: null == receiveAddressIndex
          ? _self.receiveAddressIndex
          : receiveAddressIndex // ignore: cast_nullable_to_non_nullable
              as int,
      changeAddressIndex: null == changeAddressIndex
          ? _self.changeAddressIndex
          : changeAddressIndex // ignore: cast_nullable_to_non_nullable
              as int,
      balance: freezed == balance
          ? _self.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as Balance?,
      receiveAddress: freezed == receiveAddress
          ? _self.receiveAddress
          : receiveAddress // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BalanceCopyWith<$Res>? get balance {
    if (_self.balance == null) {
      return null;
    }

    return $BalanceCopyWith<$Res>(_self.balance!, (value) {
      return _then(_self.copyWith(balance: value));
    });
  }
}

/// Adds pattern-matching-related methods to [Account].
extension AccountPatterns on Account {
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
    TResult Function(_Account value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Account() when $default != null:
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
    TResult Function(_Account value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Account():
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
    TResult? Function(_Account value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Account() when $default != null:
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
            String id,
            String walletId,
            String name,
            AccountKind kind,
            int accountIndex,
            bool isActive,
            int receiveAddressIndex,
            int changeAddressIndex,
            Balance? balance,
            String? receiveAddress)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Account() when $default != null:
        return $default(
            _that.id,
            _that.walletId,
            _that.name,
            _that.kind,
            _that.accountIndex,
            _that.isActive,
            _that.receiveAddressIndex,
            _that.changeAddressIndex,
            _that.balance,
            _that.receiveAddress);
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
            String id,
            String walletId,
            String name,
            AccountKind kind,
            int accountIndex,
            bool isActive,
            int receiveAddressIndex,
            int changeAddressIndex,
            Balance? balance,
            String? receiveAddress)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Account():
        return $default(
            _that.id,
            _that.walletId,
            _that.name,
            _that.kind,
            _that.accountIndex,
            _that.isActive,
            _that.receiveAddressIndex,
            _that.changeAddressIndex,
            _that.balance,
            _that.receiveAddress);
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
            String id,
            String walletId,
            String name,
            AccountKind kind,
            int accountIndex,
            bool isActive,
            int receiveAddressIndex,
            int changeAddressIndex,
            Balance? balance,
            String? receiveAddress)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Account() when $default != null:
        return $default(
            _that.id,
            _that.walletId,
            _that.name,
            _that.kind,
            _that.accountIndex,
            _that.isActive,
            _that.receiveAddressIndex,
            _that.changeAddressIndex,
            _that.balance,
            _that.receiveAddress);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Account extends Account {
  const _Account(
      {required this.id,
      required this.walletId,
      required this.name,
      required this.kind,
      required this.accountIndex,
      this.isActive = true,
      this.receiveAddressIndex = 0,
      this.changeAddressIndex = 0,
      this.balance,
      this.receiveAddress})
      : super._();
  factory _Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  /// Unique account identifier
  @override
  final String id;

  /// Parent wallet ID
  @override
  final String walletId;

  /// Account name (user-defined)
  @override
  final String name;

  /// Account kind/type
  @override
  final AccountKind kind;

  /// Account index in derivation path
  @override
  final int accountIndex;

  /// Whether account is active/enabled
  @override
  @JsonKey()
  final bool isActive;

  /// Receive address index (for BIP-32)
  @override
  @JsonKey()
  final int receiveAddressIndex;

  /// Change address index (for BIP-32)
  @override
  @JsonKey()
  final int changeAddressIndex;

  /// Current balance (may be null if not loaded)
  @override
  final Balance? balance;

  /// Current receive address
  @override
  final String? receiveAddress;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AccountCopyWith<_Account> get copyWith =>
      __$AccountCopyWithImpl<_Account>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AccountToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Account &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.walletId, walletId) ||
                other.walletId == walletId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.accountIndex, accountIndex) ||
                other.accountIndex == accountIndex) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.receiveAddressIndex, receiveAddressIndex) ||
                other.receiveAddressIndex == receiveAddressIndex) &&
            (identical(other.changeAddressIndex, changeAddressIndex) ||
                other.changeAddressIndex == changeAddressIndex) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.receiveAddress, receiveAddress) ||
                other.receiveAddress == receiveAddress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      walletId,
      name,
      kind,
      accountIndex,
      isActive,
      receiveAddressIndex,
      changeAddressIndex,
      balance,
      receiveAddress);

  @override
  String toString() {
    return 'Account(id: $id, walletId: $walletId, name: $name, kind: $kind, accountIndex: $accountIndex, isActive: $isActive, receiveAddressIndex: $receiveAddressIndex, changeAddressIndex: $changeAddressIndex, balance: $balance, receiveAddress: $receiveAddress)';
  }
}

/// @nodoc
abstract mixin class _$AccountCopyWith<$Res> implements $AccountCopyWith<$Res> {
  factory _$AccountCopyWith(_Account value, $Res Function(_Account) _then) =
      __$AccountCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String walletId,
      String name,
      AccountKind kind,
      int accountIndex,
      bool isActive,
      int receiveAddressIndex,
      int changeAddressIndex,
      Balance? balance,
      String? receiveAddress});

  @override
  $BalanceCopyWith<$Res>? get balance;
}

/// @nodoc
class __$AccountCopyWithImpl<$Res> implements _$AccountCopyWith<$Res> {
  __$AccountCopyWithImpl(this._self, this._then);

  final _Account _self;
  final $Res Function(_Account) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? walletId = null,
    Object? name = null,
    Object? kind = null,
    Object? accountIndex = null,
    Object? isActive = null,
    Object? receiveAddressIndex = null,
    Object? changeAddressIndex = null,
    Object? balance = freezed,
    Object? receiveAddress = freezed,
  }) {
    return _then(_Account(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      walletId: null == walletId
          ? _self.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as AccountKind,
      accountIndex: null == accountIndex
          ? _self.accountIndex
          : accountIndex // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      receiveAddressIndex: null == receiveAddressIndex
          ? _self.receiveAddressIndex
          : receiveAddressIndex // ignore: cast_nullable_to_non_nullable
              as int,
      changeAddressIndex: null == changeAddressIndex
          ? _self.changeAddressIndex
          : changeAddressIndex // ignore: cast_nullable_to_non_nullable
              as int,
      balance: freezed == balance
          ? _self.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as Balance?,
      receiveAddress: freezed == receiveAddress
          ? _self.receiveAddress
          : receiveAddress // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BalanceCopyWith<$Res>? get balance {
    if (_self.balance == null) {
      return null;
    }

    return $BalanceCopyWith<$Res>(_self.balance!, (value) {
      return _then(_self.copyWith(balance: value));
    });
  }
}

/// @nodoc
mixin _$AccountDescriptor {
  String get id;
  String get walletId;
  String get name;
  AccountKind get kind;
  int get accountIndex;

  /// Create a copy of AccountDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AccountDescriptorCopyWith<AccountDescriptor> get copyWith =>
      _$AccountDescriptorCopyWithImpl<AccountDescriptor>(
          this as AccountDescriptor, _$identity);

  /// Serializes this AccountDescriptor to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AccountDescriptor &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.walletId, walletId) ||
                other.walletId == walletId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.accountIndex, accountIndex) ||
                other.accountIndex == accountIndex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, walletId, name, kind, accountIndex);

  @override
  String toString() {
    return 'AccountDescriptor(id: $id, walletId: $walletId, name: $name, kind: $kind, accountIndex: $accountIndex)';
  }
}

/// @nodoc
abstract mixin class $AccountDescriptorCopyWith<$Res> {
  factory $AccountDescriptorCopyWith(
          AccountDescriptor value, $Res Function(AccountDescriptor) _then) =
      _$AccountDescriptorCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String walletId,
      String name,
      AccountKind kind,
      int accountIndex});
}

/// @nodoc
class _$AccountDescriptorCopyWithImpl<$Res>
    implements $AccountDescriptorCopyWith<$Res> {
  _$AccountDescriptorCopyWithImpl(this._self, this._then);

  final AccountDescriptor _self;
  final $Res Function(AccountDescriptor) _then;

  /// Create a copy of AccountDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? walletId = null,
    Object? name = null,
    Object? kind = null,
    Object? accountIndex = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      walletId: null == walletId
          ? _self.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as AccountKind,
      accountIndex: null == accountIndex
          ? _self.accountIndex
          : accountIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [AccountDescriptor].
extension AccountDescriptorPatterns on AccountDescriptor {
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
    TResult Function(_AccountDescriptor value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AccountDescriptor() when $default != null:
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
    TResult Function(_AccountDescriptor value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AccountDescriptor():
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
    TResult? Function(_AccountDescriptor value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AccountDescriptor() when $default != null:
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
    TResult Function(String id, String walletId, String name, AccountKind kind,
            int accountIndex)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AccountDescriptor() when $default != null:
        return $default(_that.id, _that.walletId, _that.name, _that.kind,
            _that.accountIndex);
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
    TResult Function(String id, String walletId, String name, AccountKind kind,
            int accountIndex)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AccountDescriptor():
        return $default(_that.id, _that.walletId, _that.name, _that.kind,
            _that.accountIndex);
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
    TResult? Function(String id, String walletId, String name, AccountKind kind,
            int accountIndex)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AccountDescriptor() when $default != null:
        return $default(_that.id, _that.walletId, _that.name, _that.kind,
            _that.accountIndex);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AccountDescriptor extends AccountDescriptor {
  const _AccountDescriptor(
      {required this.id,
      required this.walletId,
      required this.name,
      required this.kind,
      required this.accountIndex})
      : super._();
  factory _AccountDescriptor.fromJson(Map<String, dynamic> json) =>
      _$AccountDescriptorFromJson(json);

  @override
  final String id;
  @override
  final String walletId;
  @override
  final String name;
  @override
  final AccountKind kind;
  @override
  final int accountIndex;

  /// Create a copy of AccountDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AccountDescriptorCopyWith<_AccountDescriptor> get copyWith =>
      __$AccountDescriptorCopyWithImpl<_AccountDescriptor>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AccountDescriptorToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AccountDescriptor &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.walletId, walletId) ||
                other.walletId == walletId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.accountIndex, accountIndex) ||
                other.accountIndex == accountIndex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, walletId, name, kind, accountIndex);

  @override
  String toString() {
    return 'AccountDescriptor(id: $id, walletId: $walletId, name: $name, kind: $kind, accountIndex: $accountIndex)';
  }
}

/// @nodoc
abstract mixin class _$AccountDescriptorCopyWith<$Res>
    implements $AccountDescriptorCopyWith<$Res> {
  factory _$AccountDescriptorCopyWith(
          _AccountDescriptor value, $Res Function(_AccountDescriptor) _then) =
      __$AccountDescriptorCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String walletId,
      String name,
      AccountKind kind,
      int accountIndex});
}

/// @nodoc
class __$AccountDescriptorCopyWithImpl<$Res>
    implements _$AccountDescriptorCopyWith<$Res> {
  __$AccountDescriptorCopyWithImpl(this._self, this._then);

  final _AccountDescriptor _self;
  final $Res Function(_AccountDescriptor) _then;

  /// Create a copy of AccountDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? walletId = null,
    Object? name = null,
    Object? kind = null,
    Object? accountIndex = null,
  }) {
    return _then(_AccountDescriptor(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      walletId: null == walletId
          ? _self.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as AccountKind,
      accountIndex: null == accountIndex
          ? _self.accountIndex
          : accountIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
