// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blue_score.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BlueScore {

 int get value;
/// Create a copy of BlueScore
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlueScoreCopyWith<BlueScore> get copyWith => _$BlueScoreCopyWithImpl<BlueScore>(this as BlueScore, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlueScore&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'BlueScore(value: $value)';
}


}

/// @nodoc
abstract mixin class $BlueScoreCopyWith<$Res>  {
  factory $BlueScoreCopyWith(BlueScore value, $Res Function(BlueScore) _then) = _$BlueScoreCopyWithImpl;
@useResult
$Res call({
 int value
});




}
/// @nodoc
class _$BlueScoreCopyWithImpl<$Res>
    implements $BlueScoreCopyWith<$Res> {
  _$BlueScoreCopyWithImpl(this._self, this._then);

  final BlueScore _self;
  final $Res Function(BlueScore) _then;

/// Create a copy of BlueScore
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BlueScore].
extension BlueScorePatterns on BlueScore {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlueScore value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlueScore() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlueScore value)  $default,){
final _that = this;
switch (_that) {
case _BlueScore():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlueScore value)?  $default,){
final _that = this;
switch (_that) {
case _BlueScore() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlueScore() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int value)  $default,) {final _that = this;
switch (_that) {
case _BlueScore():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int value)?  $default,) {final _that = this;
switch (_that) {
case _BlueScore() when $default != null:
return $default(_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _BlueScore extends BlueScore {
  const _BlueScore(this.value): super._();
  

@override final  int value;

/// Create a copy of BlueScore
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlueScoreCopyWith<_BlueScore> get copyWith => __$BlueScoreCopyWithImpl<_BlueScore>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlueScore&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'BlueScore(value: $value)';
}


}

/// @nodoc
abstract mixin class _$BlueScoreCopyWith<$Res> implements $BlueScoreCopyWith<$Res> {
  factory _$BlueScoreCopyWith(_BlueScore value, $Res Function(_BlueScore) _then) = __$BlueScoreCopyWithImpl;
@override @useResult
$Res call({
 int value
});




}
/// @nodoc
class __$BlueScoreCopyWithImpl<$Res>
    implements _$BlueScoreCopyWith<$Res> {
  __$BlueScoreCopyWithImpl(this._self, this._then);

  final _BlueScore _self;
  final $Res Function(_BlueScore) _then;

/// Create a copy of BlueScore
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(_BlueScore(
null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
