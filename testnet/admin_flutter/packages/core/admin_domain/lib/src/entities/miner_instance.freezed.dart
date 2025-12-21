// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'miner_instance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MinerInstance {

 String get id; String get name; String get status; String get targetNode; double get hashrate; int get blocksFound;
/// Create a copy of MinerInstance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MinerInstanceCopyWith<MinerInstance> get copyWith => _$MinerInstanceCopyWithImpl<MinerInstance>(this as MinerInstance, _$identity);

  /// Serializes this MinerInstance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MinerInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.targetNode, targetNode) || other.targetNode == targetNode)&&(identical(other.hashrate, hashrate) || other.hashrate == hashrate)&&(identical(other.blocksFound, blocksFound) || other.blocksFound == blocksFound));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,status,targetNode,hashrate,blocksFound);

@override
String toString() {
  return 'MinerInstance(id: $id, name: $name, status: $status, targetNode: $targetNode, hashrate: $hashrate, blocksFound: $blocksFound)';
}


}

/// @nodoc
abstract mixin class $MinerInstanceCopyWith<$Res>  {
  factory $MinerInstanceCopyWith(MinerInstance value, $Res Function(MinerInstance) _then) = _$MinerInstanceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String status, String targetNode, double hashrate, int blocksFound
});




}
/// @nodoc
class _$MinerInstanceCopyWithImpl<$Res>
    implements $MinerInstanceCopyWith<$Res> {
  _$MinerInstanceCopyWithImpl(this._self, this._then);

  final MinerInstance _self;
  final $Res Function(MinerInstance) _then;

/// Create a copy of MinerInstance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? status = null,Object? targetNode = null,Object? hashrate = null,Object? blocksFound = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,targetNode: null == targetNode ? _self.targetNode : targetNode // ignore: cast_nullable_to_non_nullable
as String,hashrate: null == hashrate ? _self.hashrate : hashrate // ignore: cast_nullable_to_non_nullable
as double,blocksFound: null == blocksFound ? _self.blocksFound : blocksFound // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MinerInstance].
extension MinerInstancePatterns on MinerInstance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MinerInstance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MinerInstance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MinerInstance value)  $default,){
final _that = this;
switch (_that) {
case _MinerInstance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MinerInstance value)?  $default,){
final _that = this;
switch (_that) {
case _MinerInstance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String status,  String targetNode,  double hashrate,  int blocksFound)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MinerInstance() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.targetNode,_that.hashrate,_that.blocksFound);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String status,  String targetNode,  double hashrate,  int blocksFound)  $default,) {final _that = this;
switch (_that) {
case _MinerInstance():
return $default(_that.id,_that.name,_that.status,_that.targetNode,_that.hashrate,_that.blocksFound);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String status,  String targetNode,  double hashrate,  int blocksFound)?  $default,) {final _that = this;
switch (_that) {
case _MinerInstance() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.targetNode,_that.hashrate,_that.blocksFound);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MinerInstance extends MinerInstance {
  const _MinerInstance({required this.id, required this.name, required this.status, required this.targetNode, required this.hashrate, required this.blocksFound}): super._();
  factory _MinerInstance.fromJson(Map<String, dynamic> json) => _$MinerInstanceFromJson(json);

@override final  String id;
@override final  String name;
@override final  String status;
@override final  String targetNode;
@override final  double hashrate;
@override final  int blocksFound;

/// Create a copy of MinerInstance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MinerInstanceCopyWith<_MinerInstance> get copyWith => __$MinerInstanceCopyWithImpl<_MinerInstance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MinerInstanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MinerInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.targetNode, targetNode) || other.targetNode == targetNode)&&(identical(other.hashrate, hashrate) || other.hashrate == hashrate)&&(identical(other.blocksFound, blocksFound) || other.blocksFound == blocksFound));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,status,targetNode,hashrate,blocksFound);

@override
String toString() {
  return 'MinerInstance(id: $id, name: $name, status: $status, targetNode: $targetNode, hashrate: $hashrate, blocksFound: $blocksFound)';
}


}

/// @nodoc
abstract mixin class _$MinerInstanceCopyWith<$Res> implements $MinerInstanceCopyWith<$Res> {
  factory _$MinerInstanceCopyWith(_MinerInstance value, $Res Function(_MinerInstance) _then) = __$MinerInstanceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String status, String targetNode, double hashrate, int blocksFound
});




}
/// @nodoc
class __$MinerInstanceCopyWithImpl<$Res>
    implements _$MinerInstanceCopyWith<$Res> {
  __$MinerInstanceCopyWithImpl(this._self, this._then);

  final _MinerInstance _self;
  final $Res Function(_MinerInstance) _then;

/// Create a copy of MinerInstance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? status = null,Object? targetNode = null,Object? hashrate = null,Object? blocksFound = null,}) {
  return _then(_MinerInstance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,targetNode: null == targetNode ? _self.targetNode : targetNode // ignore: cast_nullable_to_non_nullable
as String,hashrate: null == hashrate ? _self.hashrate : hashrate // ignore: cast_nullable_to_non_nullable
as double,blocksFound: null == blocksFound ? _self.blocksFound : blocksFound // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
