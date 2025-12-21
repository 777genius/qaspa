// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daa_score.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DaaScore {

 int get value;
/// Create a copy of DaaScore
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DaaScoreCopyWith<DaaScore> get copyWith => _$DaaScoreCopyWithImpl<DaaScore>(this as DaaScore, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DaaScore&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'DaaScore(value: $value)';
}


}

/// @nodoc
abstract mixin class $DaaScoreCopyWith<$Res>  {
  factory $DaaScoreCopyWith(DaaScore value, $Res Function(DaaScore) _then) = _$DaaScoreCopyWithImpl;
@useResult
$Res call({
 int value
});




}
/// @nodoc
class _$DaaScoreCopyWithImpl<$Res>
    implements $DaaScoreCopyWith<$Res> {
  _$DaaScoreCopyWithImpl(this._self, this._then);

  final DaaScore _self;
  final $Res Function(DaaScore) _then;

/// Create a copy of DaaScore
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DaaScore].
extension DaaScorePatterns on DaaScore {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DaaScore value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DaaScore() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DaaScore value)  $default,){
final _that = this;
switch (_that) {
case _DaaScore():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DaaScore value)?  $default,){
final _that = this;
switch (_that) {
case _DaaScore() when $default != null:
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
case _DaaScore() when $default != null:
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
case _DaaScore():
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
case _DaaScore() when $default != null:
return $default(_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _DaaScore extends DaaScore {
  const _DaaScore(this.value): super._();
  

@override final  int value;

/// Create a copy of DaaScore
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DaaScoreCopyWith<_DaaScore> get copyWith => __$DaaScoreCopyWithImpl<_DaaScore>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DaaScore&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'DaaScore(value: $value)';
}


}

/// @nodoc
abstract mixin class _$DaaScoreCopyWith<$Res> implements $DaaScoreCopyWith<$Res> {
  factory _$DaaScoreCopyWith(_DaaScore value, $Res Function(_DaaScore) _then) = __$DaaScoreCopyWithImpl;
@override @useResult
$Res call({
 int value
});




}
/// @nodoc
class __$DaaScoreCopyWithImpl<$Res>
    implements _$DaaScoreCopyWith<$Res> {
  __$DaaScoreCopyWithImpl(this._self, this._then);

  final _DaaScore _self;
  final $Res Function(_DaaScore) _then;

/// Create a copy of DaaScore
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(_DaaScore(
null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
