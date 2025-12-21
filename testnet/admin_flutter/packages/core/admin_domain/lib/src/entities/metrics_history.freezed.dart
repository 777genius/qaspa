// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metrics_history.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MinerMetricsPoint {

 int get timestamp; double get hashrate; int get blocksFound;
/// Create a copy of MinerMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MinerMetricsPointCopyWith<MinerMetricsPoint> get copyWith => _$MinerMetricsPointCopyWithImpl<MinerMetricsPoint>(this as MinerMetricsPoint, _$identity);

  /// Serializes this MinerMetricsPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MinerMetricsPoint&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.hashrate, hashrate) || other.hashrate == hashrate)&&(identical(other.blocksFound, blocksFound) || other.blocksFound == blocksFound));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,hashrate,blocksFound);

@override
String toString() {
  return 'MinerMetricsPoint(timestamp: $timestamp, hashrate: $hashrate, blocksFound: $blocksFound)';
}


}

/// @nodoc
abstract mixin class $MinerMetricsPointCopyWith<$Res>  {
  factory $MinerMetricsPointCopyWith(MinerMetricsPoint value, $Res Function(MinerMetricsPoint) _then) = _$MinerMetricsPointCopyWithImpl;
@useResult
$Res call({
 int timestamp, double hashrate, int blocksFound
});




}
/// @nodoc
class _$MinerMetricsPointCopyWithImpl<$Res>
    implements $MinerMetricsPointCopyWith<$Res> {
  _$MinerMetricsPointCopyWithImpl(this._self, this._then);

  final MinerMetricsPoint _self;
  final $Res Function(MinerMetricsPoint) _then;

/// Create a copy of MinerMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? hashrate = null,Object? blocksFound = null,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,hashrate: null == hashrate ? _self.hashrate : hashrate // ignore: cast_nullable_to_non_nullable
as double,blocksFound: null == blocksFound ? _self.blocksFound : blocksFound // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MinerMetricsPoint].
extension MinerMetricsPointPatterns on MinerMetricsPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MinerMetricsPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MinerMetricsPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MinerMetricsPoint value)  $default,){
final _that = this;
switch (_that) {
case _MinerMetricsPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MinerMetricsPoint value)?  $default,){
final _that = this;
switch (_that) {
case _MinerMetricsPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timestamp,  double hashrate,  int blocksFound)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MinerMetricsPoint() when $default != null:
return $default(_that.timestamp,_that.hashrate,_that.blocksFound);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timestamp,  double hashrate,  int blocksFound)  $default,) {final _that = this;
switch (_that) {
case _MinerMetricsPoint():
return $default(_that.timestamp,_that.hashrate,_that.blocksFound);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timestamp,  double hashrate,  int blocksFound)?  $default,) {final _that = this;
switch (_that) {
case _MinerMetricsPoint() when $default != null:
return $default(_that.timestamp,_that.hashrate,_that.blocksFound);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MinerMetricsPoint extends MinerMetricsPoint {
  const _MinerMetricsPoint({required this.timestamp, required this.hashrate, required this.blocksFound}): super._();
  factory _MinerMetricsPoint.fromJson(Map<String, dynamic> json) => _$MinerMetricsPointFromJson(json);

@override final  int timestamp;
@override final  double hashrate;
@override final  int blocksFound;

/// Create a copy of MinerMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MinerMetricsPointCopyWith<_MinerMetricsPoint> get copyWith => __$MinerMetricsPointCopyWithImpl<_MinerMetricsPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MinerMetricsPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MinerMetricsPoint&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.hashrate, hashrate) || other.hashrate == hashrate)&&(identical(other.blocksFound, blocksFound) || other.blocksFound == blocksFound));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,hashrate,blocksFound);

@override
String toString() {
  return 'MinerMetricsPoint(timestamp: $timestamp, hashrate: $hashrate, blocksFound: $blocksFound)';
}


}

/// @nodoc
abstract mixin class _$MinerMetricsPointCopyWith<$Res> implements $MinerMetricsPointCopyWith<$Res> {
  factory _$MinerMetricsPointCopyWith(_MinerMetricsPoint value, $Res Function(_MinerMetricsPoint) _then) = __$MinerMetricsPointCopyWithImpl;
@override @useResult
$Res call({
 int timestamp, double hashrate, int blocksFound
});




}
/// @nodoc
class __$MinerMetricsPointCopyWithImpl<$Res>
    implements _$MinerMetricsPointCopyWith<$Res> {
  __$MinerMetricsPointCopyWithImpl(this._self, this._then);

  final _MinerMetricsPoint _self;
  final $Res Function(_MinerMetricsPoint) _then;

/// Create a copy of MinerMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? hashrate = null,Object? blocksFound = null,}) {
  return _then(_MinerMetricsPoint(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,hashrate: null == hashrate ? _self.hashrate : hashrate // ignore: cast_nullable_to_non_nullable
as double,blocksFound: null == blocksFound ? _self.blocksFound : blocksFound // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$MinerMetricsHistory {

 List<MinerMetricsPoint> get data;
/// Create a copy of MinerMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MinerMetricsHistoryCopyWith<MinerMetricsHistory> get copyWith => _$MinerMetricsHistoryCopyWithImpl<MinerMetricsHistory>(this as MinerMetricsHistory, _$identity);

  /// Serializes this MinerMetricsHistory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MinerMetricsHistory&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'MinerMetricsHistory(data: $data)';
}


}

/// @nodoc
abstract mixin class $MinerMetricsHistoryCopyWith<$Res>  {
  factory $MinerMetricsHistoryCopyWith(MinerMetricsHistory value, $Res Function(MinerMetricsHistory) _then) = _$MinerMetricsHistoryCopyWithImpl;
@useResult
$Res call({
 List<MinerMetricsPoint> data
});




}
/// @nodoc
class _$MinerMetricsHistoryCopyWithImpl<$Res>
    implements $MinerMetricsHistoryCopyWith<$Res> {
  _$MinerMetricsHistoryCopyWithImpl(this._self, this._then);

  final MinerMetricsHistory _self;
  final $Res Function(MinerMetricsHistory) _then;

/// Create a copy of MinerMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<MinerMetricsPoint>,
  ));
}

}


/// Adds pattern-matching-related methods to [MinerMetricsHistory].
extension MinerMetricsHistoryPatterns on MinerMetricsHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MinerMetricsHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MinerMetricsHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MinerMetricsHistory value)  $default,){
final _that = this;
switch (_that) {
case _MinerMetricsHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MinerMetricsHistory value)?  $default,){
final _that = this;
switch (_that) {
case _MinerMetricsHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MinerMetricsPoint> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MinerMetricsHistory() when $default != null:
return $default(_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MinerMetricsPoint> data)  $default,) {final _that = this;
switch (_that) {
case _MinerMetricsHistory():
return $default(_that.data);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MinerMetricsPoint> data)?  $default,) {final _that = this;
switch (_that) {
case _MinerMetricsHistory() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MinerMetricsHistory extends MinerMetricsHistory {
  const _MinerMetricsHistory({required final  List<MinerMetricsPoint> data}): _data = data,super._();
  factory _MinerMetricsHistory.fromJson(Map<String, dynamic> json) => _$MinerMetricsHistoryFromJson(json);

 final  List<MinerMetricsPoint> _data;
@override List<MinerMetricsPoint> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of MinerMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MinerMetricsHistoryCopyWith<_MinerMetricsHistory> get copyWith => __$MinerMetricsHistoryCopyWithImpl<_MinerMetricsHistory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MinerMetricsHistoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MinerMetricsHistory&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'MinerMetricsHistory(data: $data)';
}


}

/// @nodoc
abstract mixin class _$MinerMetricsHistoryCopyWith<$Res> implements $MinerMetricsHistoryCopyWith<$Res> {
  factory _$MinerMetricsHistoryCopyWith(_MinerMetricsHistory value, $Res Function(_MinerMetricsHistory) _then) = __$MinerMetricsHistoryCopyWithImpl;
@override @useResult
$Res call({
 List<MinerMetricsPoint> data
});




}
/// @nodoc
class __$MinerMetricsHistoryCopyWithImpl<$Res>
    implements _$MinerMetricsHistoryCopyWith<$Res> {
  __$MinerMetricsHistoryCopyWithImpl(this._self, this._then);

  final _MinerMetricsHistory _self;
  final $Res Function(_MinerMetricsHistory) _then;

/// Create a copy of MinerMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_MinerMetricsHistory(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<MinerMetricsPoint>,
  ));
}


}


/// @nodoc
mixin _$AggregateMetricsPoint {

 int get timestamp; int get totalNodes; int get runningNodes; int get syncedNodes; int get totalMiners; int get runningMiners; int get totalBlockCount; int get virtualDaaScore; double get totalHashrate;
/// Create a copy of AggregateMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AggregateMetricsPointCopyWith<AggregateMetricsPoint> get copyWith => _$AggregateMetricsPointCopyWithImpl<AggregateMetricsPoint>(this as AggregateMetricsPoint, _$identity);

  /// Serializes this AggregateMetricsPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AggregateMetricsPoint&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.totalNodes, totalNodes) || other.totalNodes == totalNodes)&&(identical(other.runningNodes, runningNodes) || other.runningNodes == runningNodes)&&(identical(other.syncedNodes, syncedNodes) || other.syncedNodes == syncedNodes)&&(identical(other.totalMiners, totalMiners) || other.totalMiners == totalMiners)&&(identical(other.runningMiners, runningMiners) || other.runningMiners == runningMiners)&&(identical(other.totalBlockCount, totalBlockCount) || other.totalBlockCount == totalBlockCount)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.totalHashrate, totalHashrate) || other.totalHashrate == totalHashrate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,totalNodes,runningNodes,syncedNodes,totalMiners,runningMiners,totalBlockCount,virtualDaaScore,totalHashrate);

@override
String toString() {
  return 'AggregateMetricsPoint(timestamp: $timestamp, totalNodes: $totalNodes, runningNodes: $runningNodes, syncedNodes: $syncedNodes, totalMiners: $totalMiners, runningMiners: $runningMiners, totalBlockCount: $totalBlockCount, virtualDaaScore: $virtualDaaScore, totalHashrate: $totalHashrate)';
}


}

/// @nodoc
abstract mixin class $AggregateMetricsPointCopyWith<$Res>  {
  factory $AggregateMetricsPointCopyWith(AggregateMetricsPoint value, $Res Function(AggregateMetricsPoint) _then) = _$AggregateMetricsPointCopyWithImpl;
@useResult
$Res call({
 int timestamp, int totalNodes, int runningNodes, int syncedNodes, int totalMiners, int runningMiners, int totalBlockCount, int virtualDaaScore, double totalHashrate
});




}
/// @nodoc
class _$AggregateMetricsPointCopyWithImpl<$Res>
    implements $AggregateMetricsPointCopyWith<$Res> {
  _$AggregateMetricsPointCopyWithImpl(this._self, this._then);

  final AggregateMetricsPoint _self;
  final $Res Function(AggregateMetricsPoint) _then;

/// Create a copy of AggregateMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? totalNodes = null,Object? runningNodes = null,Object? syncedNodes = null,Object? totalMiners = null,Object? runningMiners = null,Object? totalBlockCount = null,Object? virtualDaaScore = null,Object? totalHashrate = null,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,totalNodes: null == totalNodes ? _self.totalNodes : totalNodes // ignore: cast_nullable_to_non_nullable
as int,runningNodes: null == runningNodes ? _self.runningNodes : runningNodes // ignore: cast_nullable_to_non_nullable
as int,syncedNodes: null == syncedNodes ? _self.syncedNodes : syncedNodes // ignore: cast_nullable_to_non_nullable
as int,totalMiners: null == totalMiners ? _self.totalMiners : totalMiners // ignore: cast_nullable_to_non_nullable
as int,runningMiners: null == runningMiners ? _self.runningMiners : runningMiners // ignore: cast_nullable_to_non_nullable
as int,totalBlockCount: null == totalBlockCount ? _self.totalBlockCount : totalBlockCount // ignore: cast_nullable_to_non_nullable
as int,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,totalHashrate: null == totalHashrate ? _self.totalHashrate : totalHashrate // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AggregateMetricsPoint].
extension AggregateMetricsPointPatterns on AggregateMetricsPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AggregateMetricsPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AggregateMetricsPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AggregateMetricsPoint value)  $default,){
final _that = this;
switch (_that) {
case _AggregateMetricsPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AggregateMetricsPoint value)?  $default,){
final _that = this;
switch (_that) {
case _AggregateMetricsPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timestamp,  int totalNodes,  int runningNodes,  int syncedNodes,  int totalMiners,  int runningMiners,  int totalBlockCount,  int virtualDaaScore,  double totalHashrate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AggregateMetricsPoint() when $default != null:
return $default(_that.timestamp,_that.totalNodes,_that.runningNodes,_that.syncedNodes,_that.totalMiners,_that.runningMiners,_that.totalBlockCount,_that.virtualDaaScore,_that.totalHashrate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timestamp,  int totalNodes,  int runningNodes,  int syncedNodes,  int totalMiners,  int runningMiners,  int totalBlockCount,  int virtualDaaScore,  double totalHashrate)  $default,) {final _that = this;
switch (_that) {
case _AggregateMetricsPoint():
return $default(_that.timestamp,_that.totalNodes,_that.runningNodes,_that.syncedNodes,_that.totalMiners,_that.runningMiners,_that.totalBlockCount,_that.virtualDaaScore,_that.totalHashrate);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timestamp,  int totalNodes,  int runningNodes,  int syncedNodes,  int totalMiners,  int runningMiners,  int totalBlockCount,  int virtualDaaScore,  double totalHashrate)?  $default,) {final _that = this;
switch (_that) {
case _AggregateMetricsPoint() when $default != null:
return $default(_that.timestamp,_that.totalNodes,_that.runningNodes,_that.syncedNodes,_that.totalMiners,_that.runningMiners,_that.totalBlockCount,_that.virtualDaaScore,_that.totalHashrate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AggregateMetricsPoint extends AggregateMetricsPoint {
  const _AggregateMetricsPoint({required this.timestamp, required this.totalNodes, required this.runningNodes, required this.syncedNodes, required this.totalMiners, required this.runningMiners, required this.totalBlockCount, required this.virtualDaaScore, required this.totalHashrate}): super._();
  factory _AggregateMetricsPoint.fromJson(Map<String, dynamic> json) => _$AggregateMetricsPointFromJson(json);

@override final  int timestamp;
@override final  int totalNodes;
@override final  int runningNodes;
@override final  int syncedNodes;
@override final  int totalMiners;
@override final  int runningMiners;
@override final  int totalBlockCount;
@override final  int virtualDaaScore;
@override final  double totalHashrate;

/// Create a copy of AggregateMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AggregateMetricsPointCopyWith<_AggregateMetricsPoint> get copyWith => __$AggregateMetricsPointCopyWithImpl<_AggregateMetricsPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AggregateMetricsPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AggregateMetricsPoint&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.totalNodes, totalNodes) || other.totalNodes == totalNodes)&&(identical(other.runningNodes, runningNodes) || other.runningNodes == runningNodes)&&(identical(other.syncedNodes, syncedNodes) || other.syncedNodes == syncedNodes)&&(identical(other.totalMiners, totalMiners) || other.totalMiners == totalMiners)&&(identical(other.runningMiners, runningMiners) || other.runningMiners == runningMiners)&&(identical(other.totalBlockCount, totalBlockCount) || other.totalBlockCount == totalBlockCount)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.totalHashrate, totalHashrate) || other.totalHashrate == totalHashrate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,totalNodes,runningNodes,syncedNodes,totalMiners,runningMiners,totalBlockCount,virtualDaaScore,totalHashrate);

@override
String toString() {
  return 'AggregateMetricsPoint(timestamp: $timestamp, totalNodes: $totalNodes, runningNodes: $runningNodes, syncedNodes: $syncedNodes, totalMiners: $totalMiners, runningMiners: $runningMiners, totalBlockCount: $totalBlockCount, virtualDaaScore: $virtualDaaScore, totalHashrate: $totalHashrate)';
}


}

/// @nodoc
abstract mixin class _$AggregateMetricsPointCopyWith<$Res> implements $AggregateMetricsPointCopyWith<$Res> {
  factory _$AggregateMetricsPointCopyWith(_AggregateMetricsPoint value, $Res Function(_AggregateMetricsPoint) _then) = __$AggregateMetricsPointCopyWithImpl;
@override @useResult
$Res call({
 int timestamp, int totalNodes, int runningNodes, int syncedNodes, int totalMiners, int runningMiners, int totalBlockCount, int virtualDaaScore, double totalHashrate
});




}
/// @nodoc
class __$AggregateMetricsPointCopyWithImpl<$Res>
    implements _$AggregateMetricsPointCopyWith<$Res> {
  __$AggregateMetricsPointCopyWithImpl(this._self, this._then);

  final _AggregateMetricsPoint _self;
  final $Res Function(_AggregateMetricsPoint) _then;

/// Create a copy of AggregateMetricsPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? totalNodes = null,Object? runningNodes = null,Object? syncedNodes = null,Object? totalMiners = null,Object? runningMiners = null,Object? totalBlockCount = null,Object? virtualDaaScore = null,Object? totalHashrate = null,}) {
  return _then(_AggregateMetricsPoint(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,totalNodes: null == totalNodes ? _self.totalNodes : totalNodes // ignore: cast_nullable_to_non_nullable
as int,runningNodes: null == runningNodes ? _self.runningNodes : runningNodes // ignore: cast_nullable_to_non_nullable
as int,syncedNodes: null == syncedNodes ? _self.syncedNodes : syncedNodes // ignore: cast_nullable_to_non_nullable
as int,totalMiners: null == totalMiners ? _self.totalMiners : totalMiners // ignore: cast_nullable_to_non_nullable
as int,runningMiners: null == runningMiners ? _self.runningMiners : runningMiners // ignore: cast_nullable_to_non_nullable
as int,totalBlockCount: null == totalBlockCount ? _self.totalBlockCount : totalBlockCount // ignore: cast_nullable_to_non_nullable
as int,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,totalHashrate: null == totalHashrate ? _self.totalHashrate : totalHashrate // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$AggregateMetricsHistory {

 List<AggregateMetricsPoint> get data;
/// Create a copy of AggregateMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AggregateMetricsHistoryCopyWith<AggregateMetricsHistory> get copyWith => _$AggregateMetricsHistoryCopyWithImpl<AggregateMetricsHistory>(this as AggregateMetricsHistory, _$identity);

  /// Serializes this AggregateMetricsHistory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AggregateMetricsHistory&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'AggregateMetricsHistory(data: $data)';
}


}

/// @nodoc
abstract mixin class $AggregateMetricsHistoryCopyWith<$Res>  {
  factory $AggregateMetricsHistoryCopyWith(AggregateMetricsHistory value, $Res Function(AggregateMetricsHistory) _then) = _$AggregateMetricsHistoryCopyWithImpl;
@useResult
$Res call({
 List<AggregateMetricsPoint> data
});




}
/// @nodoc
class _$AggregateMetricsHistoryCopyWithImpl<$Res>
    implements $AggregateMetricsHistoryCopyWith<$Res> {
  _$AggregateMetricsHistoryCopyWithImpl(this._self, this._then);

  final AggregateMetricsHistory _self;
  final $Res Function(AggregateMetricsHistory) _then;

/// Create a copy of AggregateMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<AggregateMetricsPoint>,
  ));
}

}


/// Adds pattern-matching-related methods to [AggregateMetricsHistory].
extension AggregateMetricsHistoryPatterns on AggregateMetricsHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AggregateMetricsHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AggregateMetricsHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AggregateMetricsHistory value)  $default,){
final _that = this;
switch (_that) {
case _AggregateMetricsHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AggregateMetricsHistory value)?  $default,){
final _that = this;
switch (_that) {
case _AggregateMetricsHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AggregateMetricsPoint> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AggregateMetricsHistory() when $default != null:
return $default(_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AggregateMetricsPoint> data)  $default,) {final _that = this;
switch (_that) {
case _AggregateMetricsHistory():
return $default(_that.data);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AggregateMetricsPoint> data)?  $default,) {final _that = this;
switch (_that) {
case _AggregateMetricsHistory() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AggregateMetricsHistory extends AggregateMetricsHistory {
  const _AggregateMetricsHistory({required final  List<AggregateMetricsPoint> data}): _data = data,super._();
  factory _AggregateMetricsHistory.fromJson(Map<String, dynamic> json) => _$AggregateMetricsHistoryFromJson(json);

 final  List<AggregateMetricsPoint> _data;
@override List<AggregateMetricsPoint> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of AggregateMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AggregateMetricsHistoryCopyWith<_AggregateMetricsHistory> get copyWith => __$AggregateMetricsHistoryCopyWithImpl<_AggregateMetricsHistory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AggregateMetricsHistoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AggregateMetricsHistory&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'AggregateMetricsHistory(data: $data)';
}


}

/// @nodoc
abstract mixin class _$AggregateMetricsHistoryCopyWith<$Res> implements $AggregateMetricsHistoryCopyWith<$Res> {
  factory _$AggregateMetricsHistoryCopyWith(_AggregateMetricsHistory value, $Res Function(_AggregateMetricsHistory) _then) = __$AggregateMetricsHistoryCopyWithImpl;
@override @useResult
$Res call({
 List<AggregateMetricsPoint> data
});




}
/// @nodoc
class __$AggregateMetricsHistoryCopyWithImpl<$Res>
    implements _$AggregateMetricsHistoryCopyWith<$Res> {
  __$AggregateMetricsHistoryCopyWithImpl(this._self, this._then);

  final _AggregateMetricsHistory _self;
  final $Res Function(_AggregateMetricsHistory) _then;

/// Create a copy of AggregateMetricsHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_AggregateMetricsHistory(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<AggregateMetricsPoint>,
  ));
}


}

// dart format on
