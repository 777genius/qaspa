// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'node_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NodeConfig {

 String? get name; String get role; String? get connectTo; bool get utxoindex;
/// Create a copy of NodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeConfigCopyWith<NodeConfig> get copyWith => _$NodeConfigCopyWithImpl<NodeConfig>(this as NodeConfig, _$identity);

  /// Serializes this NodeConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role)&&(identical(other.connectTo, connectTo) || other.connectTo == connectTo)&&(identical(other.utxoindex, utxoindex) || other.utxoindex == utxoindex));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,role,connectTo,utxoindex);

@override
String toString() {
  return 'NodeConfig(name: $name, role: $role, connectTo: $connectTo, utxoindex: $utxoindex)';
}


}

/// @nodoc
abstract mixin class $NodeConfigCopyWith<$Res>  {
  factory $NodeConfigCopyWith(NodeConfig value, $Res Function(NodeConfig) _then) = _$NodeConfigCopyWithImpl;
@useResult
$Res call({
 String? name, String role, String? connectTo, bool utxoindex
});




}
/// @nodoc
class _$NodeConfigCopyWithImpl<$Res>
    implements $NodeConfigCopyWith<$Res> {
  _$NodeConfigCopyWithImpl(this._self, this._then);

  final NodeConfig _self;
  final $Res Function(NodeConfig) _then;

/// Create a copy of NodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? role = null,Object? connectTo = freezed,Object? utxoindex = null,}) {
  return _then(_self.copyWith(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,connectTo: freezed == connectTo ? _self.connectTo : connectTo // ignore: cast_nullable_to_non_nullable
as String?,utxoindex: null == utxoindex ? _self.utxoindex : utxoindex // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NodeConfig].
extension NodeConfigPatterns on NodeConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NodeConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NodeConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NodeConfig value)  $default,){
final _that = this;
switch (_that) {
case _NodeConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NodeConfig value)?  $default,){
final _that = this;
switch (_that) {
case _NodeConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  String role,  String? connectTo,  bool utxoindex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NodeConfig() when $default != null:
return $default(_that.name,_that.role,_that.connectTo,_that.utxoindex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  String role,  String? connectTo,  bool utxoindex)  $default,) {final _that = this;
switch (_that) {
case _NodeConfig():
return $default(_that.name,_that.role,_that.connectTo,_that.utxoindex);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  String role,  String? connectTo,  bool utxoindex)?  $default,) {final _that = this;
switch (_that) {
case _NodeConfig() when $default != null:
return $default(_that.name,_that.role,_that.connectTo,_that.utxoindex);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NodeConfig extends NodeConfig {
  const _NodeConfig({this.name, this.role = 'peer', this.connectTo, this.utxoindex = false}): super._();
  factory _NodeConfig.fromJson(Map<String, dynamic> json) => _$NodeConfigFromJson(json);

@override final  String? name;
@override@JsonKey() final  String role;
@override final  String? connectTo;
@override@JsonKey() final  bool utxoindex;

/// Create a copy of NodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NodeConfigCopyWith<_NodeConfig> get copyWith => __$NodeConfigCopyWithImpl<_NodeConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NodeConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NodeConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role)&&(identical(other.connectTo, connectTo) || other.connectTo == connectTo)&&(identical(other.utxoindex, utxoindex) || other.utxoindex == utxoindex));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,role,connectTo,utxoindex);

@override
String toString() {
  return 'NodeConfig(name: $name, role: $role, connectTo: $connectTo, utxoindex: $utxoindex)';
}


}

/// @nodoc
abstract mixin class _$NodeConfigCopyWith<$Res> implements $NodeConfigCopyWith<$Res> {
  factory _$NodeConfigCopyWith(_NodeConfig value, $Res Function(_NodeConfig) _then) = __$NodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String? name, String role, String? connectTo, bool utxoindex
});




}
/// @nodoc
class __$NodeConfigCopyWithImpl<$Res>
    implements _$NodeConfigCopyWith<$Res> {
  __$NodeConfigCopyWithImpl(this._self, this._then);

  final _NodeConfig _self;
  final $Res Function(_NodeConfig) _then;

/// Create a copy of NodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? role = null,Object? connectTo = freezed,Object? utxoindex = null,}) {
  return _then(_NodeConfig(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,connectTo: freezed == connectTo ? _self.connectTo : connectTo // ignore: cast_nullable_to_non_nullable
as String?,utxoindex: null == utxoindex ? _self.utxoindex : utxoindex // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
