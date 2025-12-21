// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'miner_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MinerConfig {

 String? get name; String get targetNode; String get payoutAddress; int get threads; double? get targetBps;
/// Create a copy of MinerConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MinerConfigCopyWith<MinerConfig> get copyWith => _$MinerConfigCopyWithImpl<MinerConfig>(this as MinerConfig, _$identity);

  /// Serializes this MinerConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MinerConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.targetNode, targetNode) || other.targetNode == targetNode)&&(identical(other.payoutAddress, payoutAddress) || other.payoutAddress == payoutAddress)&&(identical(other.threads, threads) || other.threads == threads)&&(identical(other.targetBps, targetBps) || other.targetBps == targetBps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,targetNode,payoutAddress,threads,targetBps);

@override
String toString() {
  return 'MinerConfig(name: $name, targetNode: $targetNode, payoutAddress: $payoutAddress, threads: $threads, targetBps: $targetBps)';
}


}

/// @nodoc
abstract mixin class $MinerConfigCopyWith<$Res>  {
  factory $MinerConfigCopyWith(MinerConfig value, $Res Function(MinerConfig) _then) = _$MinerConfigCopyWithImpl;
@useResult
$Res call({
 String? name, String targetNode, String payoutAddress, int threads, double? targetBps
});




}
/// @nodoc
class _$MinerConfigCopyWithImpl<$Res>
    implements $MinerConfigCopyWith<$Res> {
  _$MinerConfigCopyWithImpl(this._self, this._then);

  final MinerConfig _self;
  final $Res Function(MinerConfig) _then;

/// Create a copy of MinerConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? targetNode = null,Object? payoutAddress = null,Object? threads = null,Object? targetBps = freezed,}) {
  return _then(_self.copyWith(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,targetNode: null == targetNode ? _self.targetNode : targetNode // ignore: cast_nullable_to_non_nullable
as String,payoutAddress: null == payoutAddress ? _self.payoutAddress : payoutAddress // ignore: cast_nullable_to_non_nullable
as String,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,targetBps: freezed == targetBps ? _self.targetBps : targetBps // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [MinerConfig].
extension MinerConfigPatterns on MinerConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MinerConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MinerConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MinerConfig value)  $default,){
final _that = this;
switch (_that) {
case _MinerConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MinerConfig value)?  $default,){
final _that = this;
switch (_that) {
case _MinerConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  String targetNode,  String payoutAddress,  int threads,  double? targetBps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MinerConfig() when $default != null:
return $default(_that.name,_that.targetNode,_that.payoutAddress,_that.threads,_that.targetBps);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  String targetNode,  String payoutAddress,  int threads,  double? targetBps)  $default,) {final _that = this;
switch (_that) {
case _MinerConfig():
return $default(_that.name,_that.targetNode,_that.payoutAddress,_that.threads,_that.targetBps);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  String targetNode,  String payoutAddress,  int threads,  double? targetBps)?  $default,) {final _that = this;
switch (_that) {
case _MinerConfig() when $default != null:
return $default(_that.name,_that.targetNode,_that.payoutAddress,_that.threads,_that.targetBps);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MinerConfig extends MinerConfig {
  const _MinerConfig({this.name, required this.targetNode, required this.payoutAddress, this.threads = 1, this.targetBps}): super._();
  factory _MinerConfig.fromJson(Map<String, dynamic> json) => _$MinerConfigFromJson(json);

@override final  String? name;
@override final  String targetNode;
@override final  String payoutAddress;
@override@JsonKey() final  int threads;
@override final  double? targetBps;

/// Create a copy of MinerConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MinerConfigCopyWith<_MinerConfig> get copyWith => __$MinerConfigCopyWithImpl<_MinerConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MinerConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MinerConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.targetNode, targetNode) || other.targetNode == targetNode)&&(identical(other.payoutAddress, payoutAddress) || other.payoutAddress == payoutAddress)&&(identical(other.threads, threads) || other.threads == threads)&&(identical(other.targetBps, targetBps) || other.targetBps == targetBps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,targetNode,payoutAddress,threads,targetBps);

@override
String toString() {
  return 'MinerConfig(name: $name, targetNode: $targetNode, payoutAddress: $payoutAddress, threads: $threads, targetBps: $targetBps)';
}


}

/// @nodoc
abstract mixin class _$MinerConfigCopyWith<$Res> implements $MinerConfigCopyWith<$Res> {
  factory _$MinerConfigCopyWith(_MinerConfig value, $Res Function(_MinerConfig) _then) = __$MinerConfigCopyWithImpl;
@override @useResult
$Res call({
 String? name, String targetNode, String payoutAddress, int threads, double? targetBps
});




}
/// @nodoc
class __$MinerConfigCopyWithImpl<$Res>
    implements _$MinerConfigCopyWith<$Res> {
  __$MinerConfigCopyWithImpl(this._self, this._then);

  final _MinerConfig _self;
  final $Res Function(_MinerConfig) _then;

/// Create a copy of MinerConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? targetNode = null,Object? payoutAddress = null,Object? threads = null,Object? targetBps = freezed,}) {
  return _then(_MinerConfig(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,targetNode: null == targetNode ? _self.targetNode : targetNode // ignore: cast_nullable_to_non_nullable
as String,payoutAddress: null == payoutAddress ? _self.payoutAddress : payoutAddress // ignore: cast_nullable_to_non_nullable
as String,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,targetBps: freezed == targetBps ? _self.targetBps : targetBps // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
