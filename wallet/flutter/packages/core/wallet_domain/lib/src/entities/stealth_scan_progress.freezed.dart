// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stealth_scan_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StealthScanProgress {
  int get scannedBlocks;
  int get totalBlocks;
  int get foundPayments;
  bool get isComplete;
  DateTime? get startedAt;
  DateTime? get completedAt;

  /// Create a copy of StealthScanProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StealthScanProgressCopyWith<StealthScanProgress> get copyWith =>
      _$StealthScanProgressCopyWithImpl<StealthScanProgress>(
          this as StealthScanProgress, _$identity);

  /// Serializes this StealthScanProgress to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StealthScanProgress &&
            (identical(other.scannedBlocks, scannedBlocks) ||
                other.scannedBlocks == scannedBlocks) &&
            (identical(other.totalBlocks, totalBlocks) ||
                other.totalBlocks == totalBlocks) &&
            (identical(other.foundPayments, foundPayments) ||
                other.foundPayments == foundPayments) &&
            (identical(other.isComplete, isComplete) ||
                other.isComplete == isComplete) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, scannedBlocks, totalBlocks,
      foundPayments, isComplete, startedAt, completedAt);

  @override
  String toString() {
    return 'StealthScanProgress(scannedBlocks: $scannedBlocks, totalBlocks: $totalBlocks, foundPayments: $foundPayments, isComplete: $isComplete, startedAt: $startedAt, completedAt: $completedAt)';
  }
}

/// @nodoc
abstract mixin class $StealthScanProgressCopyWith<$Res> {
  factory $StealthScanProgressCopyWith(
          StealthScanProgress value, $Res Function(StealthScanProgress) _then) =
      _$StealthScanProgressCopyWithImpl;
  @useResult
  $Res call(
      {int scannedBlocks,
      int totalBlocks,
      int foundPayments,
      bool isComplete,
      DateTime? startedAt,
      DateTime? completedAt});
}

/// @nodoc
class _$StealthScanProgressCopyWithImpl<$Res>
    implements $StealthScanProgressCopyWith<$Res> {
  _$StealthScanProgressCopyWithImpl(this._self, this._then);

  final StealthScanProgress _self;
  final $Res Function(StealthScanProgress) _then;

  /// Create a copy of StealthScanProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scannedBlocks = null,
    Object? totalBlocks = null,
    Object? foundPayments = null,
    Object? isComplete = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(_self.copyWith(
      scannedBlocks: null == scannedBlocks
          ? _self.scannedBlocks
          : scannedBlocks // ignore: cast_nullable_to_non_nullable
              as int,
      totalBlocks: null == totalBlocks
          ? _self.totalBlocks
          : totalBlocks // ignore: cast_nullable_to_non_nullable
              as int,
      foundPayments: null == foundPayments
          ? _self.foundPayments
          : foundPayments // ignore: cast_nullable_to_non_nullable
              as int,
      isComplete: null == isComplete
          ? _self.isComplete
          : isComplete // ignore: cast_nullable_to_non_nullable
              as bool,
      startedAt: freezed == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [StealthScanProgress].
extension StealthScanProgressPatterns on StealthScanProgress {
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
    TResult Function(_StealthScanProgress value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StealthScanProgress() when $default != null:
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
    TResult Function(_StealthScanProgress value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StealthScanProgress():
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
    TResult? Function(_StealthScanProgress value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StealthScanProgress() when $default != null:
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
    TResult Function(int scannedBlocks, int totalBlocks, int foundPayments,
            bool isComplete, DateTime? startedAt, DateTime? completedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StealthScanProgress() when $default != null:
        return $default(
            _that.scannedBlocks,
            _that.totalBlocks,
            _that.foundPayments,
            _that.isComplete,
            _that.startedAt,
            _that.completedAt);
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
    TResult Function(int scannedBlocks, int totalBlocks, int foundPayments,
            bool isComplete, DateTime? startedAt, DateTime? completedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StealthScanProgress():
        return $default(
            _that.scannedBlocks,
            _that.totalBlocks,
            _that.foundPayments,
            _that.isComplete,
            _that.startedAt,
            _that.completedAt);
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
    TResult? Function(int scannedBlocks, int totalBlocks, int foundPayments,
            bool isComplete, DateTime? startedAt, DateTime? completedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StealthScanProgress() when $default != null:
        return $default(
            _that.scannedBlocks,
            _that.totalBlocks,
            _that.foundPayments,
            _that.isComplete,
            _that.startedAt,
            _that.completedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _StealthScanProgress extends StealthScanProgress {
  const _StealthScanProgress(
      {required this.scannedBlocks,
      required this.totalBlocks,
      required this.foundPayments,
      required this.isComplete,
      this.startedAt,
      this.completedAt})
      : super._();
  factory _StealthScanProgress.fromJson(Map<String, dynamic> json) =>
      _$StealthScanProgressFromJson(json);

  @override
  final int scannedBlocks;
  @override
  final int totalBlocks;
  @override
  final int foundPayments;
  @override
  final bool isComplete;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? completedAt;

  /// Create a copy of StealthScanProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StealthScanProgressCopyWith<_StealthScanProgress> get copyWith =>
      __$StealthScanProgressCopyWithImpl<_StealthScanProgress>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$StealthScanProgressToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _StealthScanProgress &&
            (identical(other.scannedBlocks, scannedBlocks) ||
                other.scannedBlocks == scannedBlocks) &&
            (identical(other.totalBlocks, totalBlocks) ||
                other.totalBlocks == totalBlocks) &&
            (identical(other.foundPayments, foundPayments) ||
                other.foundPayments == foundPayments) &&
            (identical(other.isComplete, isComplete) ||
                other.isComplete == isComplete) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, scannedBlocks, totalBlocks,
      foundPayments, isComplete, startedAt, completedAt);

  @override
  String toString() {
    return 'StealthScanProgress(scannedBlocks: $scannedBlocks, totalBlocks: $totalBlocks, foundPayments: $foundPayments, isComplete: $isComplete, startedAt: $startedAt, completedAt: $completedAt)';
  }
}

/// @nodoc
abstract mixin class _$StealthScanProgressCopyWith<$Res>
    implements $StealthScanProgressCopyWith<$Res> {
  factory _$StealthScanProgressCopyWith(_StealthScanProgress value,
          $Res Function(_StealthScanProgress) _then) =
      __$StealthScanProgressCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int scannedBlocks,
      int totalBlocks,
      int foundPayments,
      bool isComplete,
      DateTime? startedAt,
      DateTime? completedAt});
}

/// @nodoc
class __$StealthScanProgressCopyWithImpl<$Res>
    implements _$StealthScanProgressCopyWith<$Res> {
  __$StealthScanProgressCopyWithImpl(this._self, this._then);

  final _StealthScanProgress _self;
  final $Res Function(_StealthScanProgress) _then;

  /// Create a copy of StealthScanProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? scannedBlocks = null,
    Object? totalBlocks = null,
    Object? foundPayments = null,
    Object? isComplete = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(_StealthScanProgress(
      scannedBlocks: null == scannedBlocks
          ? _self.scannedBlocks
          : scannedBlocks // ignore: cast_nullable_to_non_nullable
              as int,
      totalBlocks: null == totalBlocks
          ? _self.totalBlocks
          : totalBlocks // ignore: cast_nullable_to_non_nullable
              as int,
      foundPayments: null == foundPayments
          ? _self.foundPayments
          : foundPayments // ignore: cast_nullable_to_non_nullable
              as int,
      isComplete: null == isComplete
          ? _self.isComplete
          : isComplete // ignore: cast_nullable_to_non_nullable
              as bool,
      startedAt: freezed == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
