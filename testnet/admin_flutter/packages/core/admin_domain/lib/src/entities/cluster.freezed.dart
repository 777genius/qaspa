// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cluster.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Cluster {

 ClusterStatus get status; int get nodeCount; int get minerCount; bool get txgenRunning; DateTime get lastUpdated;
/// Create a copy of Cluster
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClusterCopyWith<Cluster> get copyWith => _$ClusterCopyWithImpl<Cluster>(this as Cluster, _$identity);

  /// Serializes this Cluster to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Cluster&&(identical(other.status, status) || other.status == status)&&(identical(other.nodeCount, nodeCount) || other.nodeCount == nodeCount)&&(identical(other.minerCount, minerCount) || other.minerCount == minerCount)&&(identical(other.txgenRunning, txgenRunning) || other.txgenRunning == txgenRunning)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,nodeCount,minerCount,txgenRunning,lastUpdated);

@override
String toString() {
  return 'Cluster(status: $status, nodeCount: $nodeCount, minerCount: $minerCount, txgenRunning: $txgenRunning, lastUpdated: $lastUpdated)';
}


}

/// @nodoc
abstract mixin class $ClusterCopyWith<$Res>  {
  factory $ClusterCopyWith(Cluster value, $Res Function(Cluster) _then) = _$ClusterCopyWithImpl;
@useResult
$Res call({
 ClusterStatus status, int nodeCount, int minerCount, bool txgenRunning, DateTime lastUpdated
});




}
/// @nodoc
class _$ClusterCopyWithImpl<$Res>
    implements $ClusterCopyWith<$Res> {
  _$ClusterCopyWithImpl(this._self, this._then);

  final Cluster _self;
  final $Res Function(Cluster) _then;

/// Create a copy of Cluster
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? nodeCount = null,Object? minerCount = null,Object? txgenRunning = null,Object? lastUpdated = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ClusterStatus,nodeCount: null == nodeCount ? _self.nodeCount : nodeCount // ignore: cast_nullable_to_non_nullable
as int,minerCount: null == minerCount ? _self.minerCount : minerCount // ignore: cast_nullable_to_non_nullable
as int,txgenRunning: null == txgenRunning ? _self.txgenRunning : txgenRunning // ignore: cast_nullable_to_non_nullable
as bool,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Cluster].
extension ClusterPatterns on Cluster {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Cluster value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Cluster() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Cluster value)  $default,){
final _that = this;
switch (_that) {
case _Cluster():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Cluster value)?  $default,){
final _that = this;
switch (_that) {
case _Cluster() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ClusterStatus status,  int nodeCount,  int minerCount,  bool txgenRunning,  DateTime lastUpdated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Cluster() when $default != null:
return $default(_that.status,_that.nodeCount,_that.minerCount,_that.txgenRunning,_that.lastUpdated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ClusterStatus status,  int nodeCount,  int minerCount,  bool txgenRunning,  DateTime lastUpdated)  $default,) {final _that = this;
switch (_that) {
case _Cluster():
return $default(_that.status,_that.nodeCount,_that.minerCount,_that.txgenRunning,_that.lastUpdated);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ClusterStatus status,  int nodeCount,  int minerCount,  bool txgenRunning,  DateTime lastUpdated)?  $default,) {final _that = this;
switch (_that) {
case _Cluster() when $default != null:
return $default(_that.status,_that.nodeCount,_that.minerCount,_that.txgenRunning,_that.lastUpdated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Cluster extends Cluster {
  const _Cluster({required this.status, required this.nodeCount, required this.minerCount, required this.txgenRunning, required this.lastUpdated}): super._();
  factory _Cluster.fromJson(Map<String, dynamic> json) => _$ClusterFromJson(json);

@override final  ClusterStatus status;
@override final  int nodeCount;
@override final  int minerCount;
@override final  bool txgenRunning;
@override final  DateTime lastUpdated;

/// Create a copy of Cluster
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClusterCopyWith<_Cluster> get copyWith => __$ClusterCopyWithImpl<_Cluster>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClusterToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cluster&&(identical(other.status, status) || other.status == status)&&(identical(other.nodeCount, nodeCount) || other.nodeCount == nodeCount)&&(identical(other.minerCount, minerCount) || other.minerCount == minerCount)&&(identical(other.txgenRunning, txgenRunning) || other.txgenRunning == txgenRunning)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,nodeCount,minerCount,txgenRunning,lastUpdated);

@override
String toString() {
  return 'Cluster(status: $status, nodeCount: $nodeCount, minerCount: $minerCount, txgenRunning: $txgenRunning, lastUpdated: $lastUpdated)';
}


}

/// @nodoc
abstract mixin class _$ClusterCopyWith<$Res> implements $ClusterCopyWith<$Res> {
  factory _$ClusterCopyWith(_Cluster value, $Res Function(_Cluster) _then) = __$ClusterCopyWithImpl;
@override @useResult
$Res call({
 ClusterStatus status, int nodeCount, int minerCount, bool txgenRunning, DateTime lastUpdated
});




}
/// @nodoc
class __$ClusterCopyWithImpl<$Res>
    implements _$ClusterCopyWith<$Res> {
  __$ClusterCopyWithImpl(this._self, this._then);

  final _Cluster _self;
  final $Res Function(_Cluster) _then;

/// Create a copy of Cluster
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? nodeCount = null,Object? minerCount = null,Object? txgenRunning = null,Object? lastUpdated = null,}) {
  return _then(_Cluster(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ClusterStatus,nodeCount: null == nodeCount ? _self.nodeCount : nodeCount // ignore: cast_nullable_to_non_nullable
as int,minerCount: null == minerCount ? _self.minerCount : minerCount // ignore: cast_nullable_to_non_nullable
as int,txgenRunning: null == txgenRunning ? _self.txgenRunning : txgenRunning // ignore: cast_nullable_to_non_nullable
as bool,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
