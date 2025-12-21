// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'node_instance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NodeMetrics {

 int get blockCount; int get headerCount; int get virtualDaaScore; int get peerCount; int get mempoolSize; bool get isSynced;
/// Create a copy of NodeMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeMetricsCopyWith<NodeMetrics> get copyWith => _$NodeMetricsCopyWithImpl<NodeMetrics>(this as NodeMetrics, _$identity);

  /// Serializes this NodeMetrics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeMetrics&&(identical(other.blockCount, blockCount) || other.blockCount == blockCount)&&(identical(other.headerCount, headerCount) || other.headerCount == headerCount)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.peerCount, peerCount) || other.peerCount == peerCount)&&(identical(other.mempoolSize, mempoolSize) || other.mempoolSize == mempoolSize)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,blockCount,headerCount,virtualDaaScore,peerCount,mempoolSize,isSynced);

@override
String toString() {
  return 'NodeMetrics(blockCount: $blockCount, headerCount: $headerCount, virtualDaaScore: $virtualDaaScore, peerCount: $peerCount, mempoolSize: $mempoolSize, isSynced: $isSynced)';
}


}

/// @nodoc
abstract mixin class $NodeMetricsCopyWith<$Res>  {
  factory $NodeMetricsCopyWith(NodeMetrics value, $Res Function(NodeMetrics) _then) = _$NodeMetricsCopyWithImpl;
@useResult
$Res call({
 int blockCount, int headerCount, int virtualDaaScore, int peerCount, int mempoolSize, bool isSynced
});




}
/// @nodoc
class _$NodeMetricsCopyWithImpl<$Res>
    implements $NodeMetricsCopyWith<$Res> {
  _$NodeMetricsCopyWithImpl(this._self, this._then);

  final NodeMetrics _self;
  final $Res Function(NodeMetrics) _then;

/// Create a copy of NodeMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? blockCount = null,Object? headerCount = null,Object? virtualDaaScore = null,Object? peerCount = null,Object? mempoolSize = null,Object? isSynced = null,}) {
  return _then(_self.copyWith(
blockCount: null == blockCount ? _self.blockCount : blockCount // ignore: cast_nullable_to_non_nullable
as int,headerCount: null == headerCount ? _self.headerCount : headerCount // ignore: cast_nullable_to_non_nullable
as int,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,peerCount: null == peerCount ? _self.peerCount : peerCount // ignore: cast_nullable_to_non_nullable
as int,mempoolSize: null == mempoolSize ? _self.mempoolSize : mempoolSize // ignore: cast_nullable_to_non_nullable
as int,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NodeMetrics].
extension NodeMetricsPatterns on NodeMetrics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NodeMetrics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NodeMetrics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NodeMetrics value)  $default,){
final _that = this;
switch (_that) {
case _NodeMetrics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NodeMetrics value)?  $default,){
final _that = this;
switch (_that) {
case _NodeMetrics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int blockCount,  int headerCount,  int virtualDaaScore,  int peerCount,  int mempoolSize,  bool isSynced)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NodeMetrics() when $default != null:
return $default(_that.blockCount,_that.headerCount,_that.virtualDaaScore,_that.peerCount,_that.mempoolSize,_that.isSynced);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int blockCount,  int headerCount,  int virtualDaaScore,  int peerCount,  int mempoolSize,  bool isSynced)  $default,) {final _that = this;
switch (_that) {
case _NodeMetrics():
return $default(_that.blockCount,_that.headerCount,_that.virtualDaaScore,_that.peerCount,_that.mempoolSize,_that.isSynced);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int blockCount,  int headerCount,  int virtualDaaScore,  int peerCount,  int mempoolSize,  bool isSynced)?  $default,) {final _that = this;
switch (_that) {
case _NodeMetrics() when $default != null:
return $default(_that.blockCount,_that.headerCount,_that.virtualDaaScore,_that.peerCount,_that.mempoolSize,_that.isSynced);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NodeMetrics extends NodeMetrics {
  const _NodeMetrics({required this.blockCount, required this.headerCount, required this.virtualDaaScore, required this.peerCount, required this.mempoolSize, required this.isSynced}): super._();
  factory _NodeMetrics.fromJson(Map<String, dynamic> json) => _$NodeMetricsFromJson(json);

@override final  int blockCount;
@override final  int headerCount;
@override final  int virtualDaaScore;
@override final  int peerCount;
@override final  int mempoolSize;
@override final  bool isSynced;

/// Create a copy of NodeMetrics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NodeMetricsCopyWith<_NodeMetrics> get copyWith => __$NodeMetricsCopyWithImpl<_NodeMetrics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NodeMetricsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NodeMetrics&&(identical(other.blockCount, blockCount) || other.blockCount == blockCount)&&(identical(other.headerCount, headerCount) || other.headerCount == headerCount)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.peerCount, peerCount) || other.peerCount == peerCount)&&(identical(other.mempoolSize, mempoolSize) || other.mempoolSize == mempoolSize)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,blockCount,headerCount,virtualDaaScore,peerCount,mempoolSize,isSynced);

@override
String toString() {
  return 'NodeMetrics(blockCount: $blockCount, headerCount: $headerCount, virtualDaaScore: $virtualDaaScore, peerCount: $peerCount, mempoolSize: $mempoolSize, isSynced: $isSynced)';
}


}

/// @nodoc
abstract mixin class _$NodeMetricsCopyWith<$Res> implements $NodeMetricsCopyWith<$Res> {
  factory _$NodeMetricsCopyWith(_NodeMetrics value, $Res Function(_NodeMetrics) _then) = __$NodeMetricsCopyWithImpl;
@override @useResult
$Res call({
 int blockCount, int headerCount, int virtualDaaScore, int peerCount, int mempoolSize, bool isSynced
});




}
/// @nodoc
class __$NodeMetricsCopyWithImpl<$Res>
    implements _$NodeMetricsCopyWith<$Res> {
  __$NodeMetricsCopyWithImpl(this._self, this._then);

  final _NodeMetrics _self;
  final $Res Function(_NodeMetrics) _then;

/// Create a copy of NodeMetrics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? blockCount = null,Object? headerCount = null,Object? virtualDaaScore = null,Object? peerCount = null,Object? mempoolSize = null,Object? isSynced = null,}) {
  return _then(_NodeMetrics(
blockCount: null == blockCount ? _self.blockCount : blockCount // ignore: cast_nullable_to_non_nullable
as int,headerCount: null == headerCount ? _self.headerCount : headerCount // ignore: cast_nullable_to_non_nullable
as int,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,peerCount: null == peerCount ? _self.peerCount : peerCount // ignore: cast_nullable_to_non_nullable
as int,mempoolSize: null == mempoolSize ? _self.mempoolSize : mempoolSize // ignore: cast_nullable_to_non_nullable
as int,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$NodeInstance {

 String get id; String get name; String get role; String get status; int get p2pPort; int get grpcPort; NodeMetrics? get metrics;
/// Create a copy of NodeInstance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeInstanceCopyWith<NodeInstance> get copyWith => _$NodeInstanceCopyWithImpl<NodeInstance>(this as NodeInstance, _$identity);

  /// Serializes this NodeInstance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.p2pPort, p2pPort) || other.p2pPort == p2pPort)&&(identical(other.grpcPort, grpcPort) || other.grpcPort == grpcPort)&&(identical(other.metrics, metrics) || other.metrics == metrics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,role,status,p2pPort,grpcPort,metrics);

@override
String toString() {
  return 'NodeInstance(id: $id, name: $name, role: $role, status: $status, p2pPort: $p2pPort, grpcPort: $grpcPort, metrics: $metrics)';
}


}

/// @nodoc
abstract mixin class $NodeInstanceCopyWith<$Res>  {
  factory $NodeInstanceCopyWith(NodeInstance value, $Res Function(NodeInstance) _then) = _$NodeInstanceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String role, String status, int p2pPort, int grpcPort, NodeMetrics? metrics
});


$NodeMetricsCopyWith<$Res>? get metrics;

}
/// @nodoc
class _$NodeInstanceCopyWithImpl<$Res>
    implements $NodeInstanceCopyWith<$Res> {
  _$NodeInstanceCopyWithImpl(this._self, this._then);

  final NodeInstance _self;
  final $Res Function(NodeInstance) _then;

/// Create a copy of NodeInstance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? role = null,Object? status = null,Object? p2pPort = null,Object? grpcPort = null,Object? metrics = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,p2pPort: null == p2pPort ? _self.p2pPort : p2pPort // ignore: cast_nullable_to_non_nullable
as int,grpcPort: null == grpcPort ? _self.grpcPort : grpcPort // ignore: cast_nullable_to_non_nullable
as int,metrics: freezed == metrics ? _self.metrics : metrics // ignore: cast_nullable_to_non_nullable
as NodeMetrics?,
  ));
}
/// Create a copy of NodeInstance
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NodeMetricsCopyWith<$Res>? get metrics {
    if (_self.metrics == null) {
    return null;
  }

  return $NodeMetricsCopyWith<$Res>(_self.metrics!, (value) {
    return _then(_self.copyWith(metrics: value));
  });
}
}


/// Adds pattern-matching-related methods to [NodeInstance].
extension NodeInstancePatterns on NodeInstance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NodeInstance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NodeInstance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NodeInstance value)  $default,){
final _that = this;
switch (_that) {
case _NodeInstance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NodeInstance value)?  $default,){
final _that = this;
switch (_that) {
case _NodeInstance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String role,  String status,  int p2pPort,  int grpcPort,  NodeMetrics? metrics)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NodeInstance() when $default != null:
return $default(_that.id,_that.name,_that.role,_that.status,_that.p2pPort,_that.grpcPort,_that.metrics);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String role,  String status,  int p2pPort,  int grpcPort,  NodeMetrics? metrics)  $default,) {final _that = this;
switch (_that) {
case _NodeInstance():
return $default(_that.id,_that.name,_that.role,_that.status,_that.p2pPort,_that.grpcPort,_that.metrics);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String role,  String status,  int p2pPort,  int grpcPort,  NodeMetrics? metrics)?  $default,) {final _that = this;
switch (_that) {
case _NodeInstance() when $default != null:
return $default(_that.id,_that.name,_that.role,_that.status,_that.p2pPort,_that.grpcPort,_that.metrics);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NodeInstance extends NodeInstance {
  const _NodeInstance({required this.id, required this.name, required this.role, required this.status, required this.p2pPort, required this.grpcPort, this.metrics}): super._();
  factory _NodeInstance.fromJson(Map<String, dynamic> json) => _$NodeInstanceFromJson(json);

@override final  String id;
@override final  String name;
@override final  String role;
@override final  String status;
@override final  int p2pPort;
@override final  int grpcPort;
@override final  NodeMetrics? metrics;

/// Create a copy of NodeInstance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NodeInstanceCopyWith<_NodeInstance> get copyWith => __$NodeInstanceCopyWithImpl<_NodeInstance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NodeInstanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NodeInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.p2pPort, p2pPort) || other.p2pPort == p2pPort)&&(identical(other.grpcPort, grpcPort) || other.grpcPort == grpcPort)&&(identical(other.metrics, metrics) || other.metrics == metrics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,role,status,p2pPort,grpcPort,metrics);

@override
String toString() {
  return 'NodeInstance(id: $id, name: $name, role: $role, status: $status, p2pPort: $p2pPort, grpcPort: $grpcPort, metrics: $metrics)';
}


}

/// @nodoc
abstract mixin class _$NodeInstanceCopyWith<$Res> implements $NodeInstanceCopyWith<$Res> {
  factory _$NodeInstanceCopyWith(_NodeInstance value, $Res Function(_NodeInstance) _then) = __$NodeInstanceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String role, String status, int p2pPort, int grpcPort, NodeMetrics? metrics
});


@override $NodeMetricsCopyWith<$Res>? get metrics;

}
/// @nodoc
class __$NodeInstanceCopyWithImpl<$Res>
    implements _$NodeInstanceCopyWith<$Res> {
  __$NodeInstanceCopyWithImpl(this._self, this._then);

  final _NodeInstance _self;
  final $Res Function(_NodeInstance) _then;

/// Create a copy of NodeInstance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? role = null,Object? status = null,Object? p2pPort = null,Object? grpcPort = null,Object? metrics = freezed,}) {
  return _then(_NodeInstance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,p2pPort: null == p2pPort ? _self.p2pPort : p2pPort // ignore: cast_nullable_to_non_nullable
as int,grpcPort: null == grpcPort ? _self.grpcPort : grpcPort // ignore: cast_nullable_to_non_nullable
as int,metrics: freezed == metrics ? _self.metrics : metrics // ignore: cast_nullable_to_non_nullable
as NodeMetrics?,
  ));
}

/// Create a copy of NodeInstance
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NodeMetricsCopyWith<$Res>? get metrics {
    if (_self.metrics == null) {
    return null;
  }

  return $NodeMetricsCopyWith<$Res>(_self.metrics!, (value) {
    return _then(_self.copyWith(metrics: value));
  });
}
}

// dart format on
