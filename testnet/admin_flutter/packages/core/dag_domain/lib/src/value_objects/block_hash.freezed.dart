// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'block_hash.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BlockHash {

 String get value;
/// Create a copy of BlockHash
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlockHashCopyWith<BlockHash> get copyWith => _$BlockHashCopyWithImpl<BlockHash>(this as BlockHash, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlockHash&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'BlockHash(value: $value)';
}


}

/// @nodoc
abstract mixin class $BlockHashCopyWith<$Res>  {
  factory $BlockHashCopyWith(BlockHash value, $Res Function(BlockHash) _then) = _$BlockHashCopyWithImpl;
@useResult
$Res call({
 String value
});




}
/// @nodoc
class _$BlockHashCopyWithImpl<$Res>
    implements $BlockHashCopyWith<$Res> {
  _$BlockHashCopyWithImpl(this._self, this._then);

  final BlockHash _self;
  final $Res Function(BlockHash) _then;

/// Create a copy of BlockHash
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BlockHash].
extension BlockHashPatterns on BlockHash {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlockHash value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlockHash() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlockHash value)  $default,){
final _that = this;
switch (_that) {
case _BlockHash():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlockHash value)?  $default,){
final _that = this;
switch (_that) {
case _BlockHash() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlockHash() when $default != null:
return $default(_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value)  $default,) {final _that = this;
switch (_that) {
case _BlockHash():
return $default(_that.value);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value)?  $default,) {final _that = this;
switch (_that) {
case _BlockHash() when $default != null:
return $default(_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _BlockHash extends BlockHash {
  const _BlockHash(this.value): super._();
  

@override final  String value;

/// Create a copy of BlockHash
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlockHashCopyWith<_BlockHash> get copyWith => __$BlockHashCopyWithImpl<_BlockHash>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlockHash&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'BlockHash(value: $value)';
}


}

/// @nodoc
abstract mixin class _$BlockHashCopyWith<$Res> implements $BlockHashCopyWith<$Res> {
  factory _$BlockHashCopyWith(_BlockHash value, $Res Function(_BlockHash) _then) = __$BlockHashCopyWithImpl;
@override @useResult
$Res call({
 String value
});




}
/// @nodoc
class __$BlockHashCopyWithImpl<$Res>
    implements _$BlockHashCopyWith<$Res> {
  __$BlockHashCopyWithImpl(this._self, this._then);

  final _BlockHash _self;
  final $Res Function(_BlockHash) _then;

/// Create a copy of BlockHash
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(_BlockHash(
null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
