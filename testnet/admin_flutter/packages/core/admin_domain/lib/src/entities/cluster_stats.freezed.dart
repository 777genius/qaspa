// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cluster_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClusterStats {

 int get totalNodes; int get runningNodes; int get syncedNodes; int get totalMiners; int get runningMiners; int get totalBlockCount; int get virtualDaaScore; int get totalPeers; int get totalMempoolSize; double get totalHashrate; DateTime get timestamp;
/// Create a copy of ClusterStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClusterStatsCopyWith<ClusterStats> get copyWith => _$ClusterStatsCopyWithImpl<ClusterStats>(this as ClusterStats, _$identity);

  /// Serializes this ClusterStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClusterStats&&(identical(other.totalNodes, totalNodes) || other.totalNodes == totalNodes)&&(identical(other.runningNodes, runningNodes) || other.runningNodes == runningNodes)&&(identical(other.syncedNodes, syncedNodes) || other.syncedNodes == syncedNodes)&&(identical(other.totalMiners, totalMiners) || other.totalMiners == totalMiners)&&(identical(other.runningMiners, runningMiners) || other.runningMiners == runningMiners)&&(identical(other.totalBlockCount, totalBlockCount) || other.totalBlockCount == totalBlockCount)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.totalPeers, totalPeers) || other.totalPeers == totalPeers)&&(identical(other.totalMempoolSize, totalMempoolSize) || other.totalMempoolSize == totalMempoolSize)&&(identical(other.totalHashrate, totalHashrate) || other.totalHashrate == totalHashrate)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalNodes,runningNodes,syncedNodes,totalMiners,runningMiners,totalBlockCount,virtualDaaScore,totalPeers,totalMempoolSize,totalHashrate,timestamp);

@override
String toString() {
  return 'ClusterStats(totalNodes: $totalNodes, runningNodes: $runningNodes, syncedNodes: $syncedNodes, totalMiners: $totalMiners, runningMiners: $runningMiners, totalBlockCount: $totalBlockCount, virtualDaaScore: $virtualDaaScore, totalPeers: $totalPeers, totalMempoolSize: $totalMempoolSize, totalHashrate: $totalHashrate, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $ClusterStatsCopyWith<$Res>  {
  factory $ClusterStatsCopyWith(ClusterStats value, $Res Function(ClusterStats) _then) = _$ClusterStatsCopyWithImpl;
@useResult
$Res call({
 int totalNodes, int runningNodes, int syncedNodes, int totalMiners, int runningMiners, int totalBlockCount, int virtualDaaScore, int totalPeers, int totalMempoolSize, double totalHashrate, DateTime timestamp
});




}
/// @nodoc
class _$ClusterStatsCopyWithImpl<$Res>
    implements $ClusterStatsCopyWith<$Res> {
  _$ClusterStatsCopyWithImpl(this._self, this._then);

  final ClusterStats _self;
  final $Res Function(ClusterStats) _then;

/// Create a copy of ClusterStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalNodes = null,Object? runningNodes = null,Object? syncedNodes = null,Object? totalMiners = null,Object? runningMiners = null,Object? totalBlockCount = null,Object? virtualDaaScore = null,Object? totalPeers = null,Object? totalMempoolSize = null,Object? totalHashrate = null,Object? timestamp = null,}) {
  return _then(_self.copyWith(
totalNodes: null == totalNodes ? _self.totalNodes : totalNodes // ignore: cast_nullable_to_non_nullable
as int,runningNodes: null == runningNodes ? _self.runningNodes : runningNodes // ignore: cast_nullable_to_non_nullable
as int,syncedNodes: null == syncedNodes ? _self.syncedNodes : syncedNodes // ignore: cast_nullable_to_non_nullable
as int,totalMiners: null == totalMiners ? _self.totalMiners : totalMiners // ignore: cast_nullable_to_non_nullable
as int,runningMiners: null == runningMiners ? _self.runningMiners : runningMiners // ignore: cast_nullable_to_non_nullable
as int,totalBlockCount: null == totalBlockCount ? _self.totalBlockCount : totalBlockCount // ignore: cast_nullable_to_non_nullable
as int,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,totalPeers: null == totalPeers ? _self.totalPeers : totalPeers // ignore: cast_nullable_to_non_nullable
as int,totalMempoolSize: null == totalMempoolSize ? _self.totalMempoolSize : totalMempoolSize // ignore: cast_nullable_to_non_nullable
as int,totalHashrate: null == totalHashrate ? _self.totalHashrate : totalHashrate // ignore: cast_nullable_to_non_nullable
as double,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ClusterStats].
extension ClusterStatsPatterns on ClusterStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClusterStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClusterStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClusterStats value)  $default,){
final _that = this;
switch (_that) {
case _ClusterStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClusterStats value)?  $default,){
final _that = this;
switch (_that) {
case _ClusterStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalNodes,  int runningNodes,  int syncedNodes,  int totalMiners,  int runningMiners,  int totalBlockCount,  int virtualDaaScore,  int totalPeers,  int totalMempoolSize,  double totalHashrate,  DateTime timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClusterStats() when $default != null:
return $default(_that.totalNodes,_that.runningNodes,_that.syncedNodes,_that.totalMiners,_that.runningMiners,_that.totalBlockCount,_that.virtualDaaScore,_that.totalPeers,_that.totalMempoolSize,_that.totalHashrate,_that.timestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalNodes,  int runningNodes,  int syncedNodes,  int totalMiners,  int runningMiners,  int totalBlockCount,  int virtualDaaScore,  int totalPeers,  int totalMempoolSize,  double totalHashrate,  DateTime timestamp)  $default,) {final _that = this;
switch (_that) {
case _ClusterStats():
return $default(_that.totalNodes,_that.runningNodes,_that.syncedNodes,_that.totalMiners,_that.runningMiners,_that.totalBlockCount,_that.virtualDaaScore,_that.totalPeers,_that.totalMempoolSize,_that.totalHashrate,_that.timestamp);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalNodes,  int runningNodes,  int syncedNodes,  int totalMiners,  int runningMiners,  int totalBlockCount,  int virtualDaaScore,  int totalPeers,  int totalMempoolSize,  double totalHashrate,  DateTime timestamp)?  $default,) {final _that = this;
switch (_that) {
case _ClusterStats() when $default != null:
return $default(_that.totalNodes,_that.runningNodes,_that.syncedNodes,_that.totalMiners,_that.runningMiners,_that.totalBlockCount,_that.virtualDaaScore,_that.totalPeers,_that.totalMempoolSize,_that.totalHashrate,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClusterStats extends ClusterStats {
  const _ClusterStats({required this.totalNodes, required this.runningNodes, required this.syncedNodes, required this.totalMiners, required this.runningMiners, required this.totalBlockCount, required this.virtualDaaScore, required this.totalPeers, required this.totalMempoolSize, required this.totalHashrate, required this.timestamp}): super._();
  factory _ClusterStats.fromJson(Map<String, dynamic> json) => _$ClusterStatsFromJson(json);

@override final  int totalNodes;
@override final  int runningNodes;
@override final  int syncedNodes;
@override final  int totalMiners;
@override final  int runningMiners;
@override final  int totalBlockCount;
@override final  int virtualDaaScore;
@override final  int totalPeers;
@override final  int totalMempoolSize;
@override final  double totalHashrate;
@override final  DateTime timestamp;

/// Create a copy of ClusterStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClusterStatsCopyWith<_ClusterStats> get copyWith => __$ClusterStatsCopyWithImpl<_ClusterStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClusterStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClusterStats&&(identical(other.totalNodes, totalNodes) || other.totalNodes == totalNodes)&&(identical(other.runningNodes, runningNodes) || other.runningNodes == runningNodes)&&(identical(other.syncedNodes, syncedNodes) || other.syncedNodes == syncedNodes)&&(identical(other.totalMiners, totalMiners) || other.totalMiners == totalMiners)&&(identical(other.runningMiners, runningMiners) || other.runningMiners == runningMiners)&&(identical(other.totalBlockCount, totalBlockCount) || other.totalBlockCount == totalBlockCount)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.totalPeers, totalPeers) || other.totalPeers == totalPeers)&&(identical(other.totalMempoolSize, totalMempoolSize) || other.totalMempoolSize == totalMempoolSize)&&(identical(other.totalHashrate, totalHashrate) || other.totalHashrate == totalHashrate)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalNodes,runningNodes,syncedNodes,totalMiners,runningMiners,totalBlockCount,virtualDaaScore,totalPeers,totalMempoolSize,totalHashrate,timestamp);

@override
String toString() {
  return 'ClusterStats(totalNodes: $totalNodes, runningNodes: $runningNodes, syncedNodes: $syncedNodes, totalMiners: $totalMiners, runningMiners: $runningMiners, totalBlockCount: $totalBlockCount, virtualDaaScore: $virtualDaaScore, totalPeers: $totalPeers, totalMempoolSize: $totalMempoolSize, totalHashrate: $totalHashrate, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$ClusterStatsCopyWith<$Res> implements $ClusterStatsCopyWith<$Res> {
  factory _$ClusterStatsCopyWith(_ClusterStats value, $Res Function(_ClusterStats) _then) = __$ClusterStatsCopyWithImpl;
@override @useResult
$Res call({
 int totalNodes, int runningNodes, int syncedNodes, int totalMiners, int runningMiners, int totalBlockCount, int virtualDaaScore, int totalPeers, int totalMempoolSize, double totalHashrate, DateTime timestamp
});




}
/// @nodoc
class __$ClusterStatsCopyWithImpl<$Res>
    implements _$ClusterStatsCopyWith<$Res> {
  __$ClusterStatsCopyWithImpl(this._self, this._then);

  final _ClusterStats _self;
  final $Res Function(_ClusterStats) _then;

/// Create a copy of ClusterStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalNodes = null,Object? runningNodes = null,Object? syncedNodes = null,Object? totalMiners = null,Object? runningMiners = null,Object? totalBlockCount = null,Object? virtualDaaScore = null,Object? totalPeers = null,Object? totalMempoolSize = null,Object? totalHashrate = null,Object? timestamp = null,}) {
  return _then(_ClusterStats(
totalNodes: null == totalNodes ? _self.totalNodes : totalNodes // ignore: cast_nullable_to_non_nullable
as int,runningNodes: null == runningNodes ? _self.runningNodes : runningNodes // ignore: cast_nullable_to_non_nullable
as int,syncedNodes: null == syncedNodes ? _self.syncedNodes : syncedNodes // ignore: cast_nullable_to_non_nullable
as int,totalMiners: null == totalMiners ? _self.totalMiners : totalMiners // ignore: cast_nullable_to_non_nullable
as int,runningMiners: null == runningMiners ? _self.runningMiners : runningMiners // ignore: cast_nullable_to_non_nullable
as int,totalBlockCount: null == totalBlockCount ? _self.totalBlockCount : totalBlockCount // ignore: cast_nullable_to_non_nullable
as int,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,totalPeers: null == totalPeers ? _self.totalPeers : totalPeers // ignore: cast_nullable_to_non_nullable
as int,totalMempoolSize: null == totalMempoolSize ? _self.totalMempoolSize : totalMempoolSize // ignore: cast_nullable_to_non_nullable
as int,totalHashrate: null == totalHashrate ? _self.totalHashrate : totalHashrate // ignore: cast_nullable_to_non_nullable
as double,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
