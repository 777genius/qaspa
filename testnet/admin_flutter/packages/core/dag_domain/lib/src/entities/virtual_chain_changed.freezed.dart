// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virtual_chain_changed.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VirtualChainChanged {

 List<BlockHash> get removedHashes; List<BlockHash> get addedHashes;
/// Create a copy of VirtualChainChanged
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtualChainChangedCopyWith<VirtualChainChanged> get copyWith => _$VirtualChainChangedCopyWithImpl<VirtualChainChanged>(this as VirtualChainChanged, _$identity);

  /// Serializes this VirtualChainChanged to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtualChainChanged&&const DeepCollectionEquality().equals(other.removedHashes, removedHashes)&&const DeepCollectionEquality().equals(other.addedHashes, addedHashes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(removedHashes),const DeepCollectionEquality().hash(addedHashes));

@override
String toString() {
  return 'VirtualChainChanged(removedHashes: $removedHashes, addedHashes: $addedHashes)';
}


}

/// @nodoc
abstract mixin class $VirtualChainChangedCopyWith<$Res>  {
  factory $VirtualChainChangedCopyWith(VirtualChainChanged value, $Res Function(VirtualChainChanged) _then) = _$VirtualChainChangedCopyWithImpl;
@useResult
$Res call({
 List<BlockHash> removedHashes, List<BlockHash> addedHashes
});




}
/// @nodoc
class _$VirtualChainChangedCopyWithImpl<$Res>
    implements $VirtualChainChangedCopyWith<$Res> {
  _$VirtualChainChangedCopyWithImpl(this._self, this._then);

  final VirtualChainChanged _self;
  final $Res Function(VirtualChainChanged) _then;

/// Create a copy of VirtualChainChanged
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? removedHashes = null,Object? addedHashes = null,}) {
  return _then(_self.copyWith(
removedHashes: null == removedHashes ? _self.removedHashes : removedHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,addedHashes: null == addedHashes ? _self.addedHashes : addedHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtualChainChanged].
extension VirtualChainChangedPatterns on VirtualChainChanged {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtualChainChanged value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtualChainChanged() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtualChainChanged value)  $default,){
final _that = this;
switch (_that) {
case _VirtualChainChanged():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtualChainChanged value)?  $default,){
final _that = this;
switch (_that) {
case _VirtualChainChanged() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BlockHash> removedHashes,  List<BlockHash> addedHashes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtualChainChanged() when $default != null:
return $default(_that.removedHashes,_that.addedHashes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BlockHash> removedHashes,  List<BlockHash> addedHashes)  $default,) {final _that = this;
switch (_that) {
case _VirtualChainChanged():
return $default(_that.removedHashes,_that.addedHashes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BlockHash> removedHashes,  List<BlockHash> addedHashes)?  $default,) {final _that = this;
switch (_that) {
case _VirtualChainChanged() when $default != null:
return $default(_that.removedHashes,_that.addedHashes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtualChainChanged extends VirtualChainChanged {
  const _VirtualChainChanged({required final  List<BlockHash> removedHashes, required final  List<BlockHash> addedHashes}): _removedHashes = removedHashes,_addedHashes = addedHashes,super._();
  factory _VirtualChainChanged.fromJson(Map<String, dynamic> json) => _$VirtualChainChangedFromJson(json);

 final  List<BlockHash> _removedHashes;
@override List<BlockHash> get removedHashes {
  if (_removedHashes is EqualUnmodifiableListView) return _removedHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removedHashes);
}

 final  List<BlockHash> _addedHashes;
@override List<BlockHash> get addedHashes {
  if (_addedHashes is EqualUnmodifiableListView) return _addedHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_addedHashes);
}


/// Create a copy of VirtualChainChanged
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtualChainChangedCopyWith<_VirtualChainChanged> get copyWith => __$VirtualChainChangedCopyWithImpl<_VirtualChainChanged>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtualChainChangedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtualChainChanged&&const DeepCollectionEquality().equals(other._removedHashes, _removedHashes)&&const DeepCollectionEquality().equals(other._addedHashes, _addedHashes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_removedHashes),const DeepCollectionEquality().hash(_addedHashes));

@override
String toString() {
  return 'VirtualChainChanged(removedHashes: $removedHashes, addedHashes: $addedHashes)';
}


}

/// @nodoc
abstract mixin class _$VirtualChainChangedCopyWith<$Res> implements $VirtualChainChangedCopyWith<$Res> {
  factory _$VirtualChainChangedCopyWith(_VirtualChainChanged value, $Res Function(_VirtualChainChanged) _then) = __$VirtualChainChangedCopyWithImpl;
@override @useResult
$Res call({
 List<BlockHash> removedHashes, List<BlockHash> addedHashes
});




}
/// @nodoc
class __$VirtualChainChangedCopyWithImpl<$Res>
    implements _$VirtualChainChangedCopyWith<$Res> {
  __$VirtualChainChangedCopyWithImpl(this._self, this._then);

  final _VirtualChainChanged _self;
  final $Res Function(_VirtualChainChanged) _then;

/// Create a copy of VirtualChainChanged
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? removedHashes = null,Object? addedHashes = null,}) {
  return _then(_VirtualChainChanged(
removedHashes: null == removedHashes ? _self._removedHashes : removedHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,addedHashes: null == addedHashes ? _self._addedHashes : addedHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,
  ));
}


}

// dart format on
