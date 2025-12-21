// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dag_block_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DagBlockDto {

 String get hash;@JsonKey(name: 'daa_score') int get daaScore;@JsonKey(name: 'blue_score') int get blueScore;@JsonKey(name: 'blue_work') String get blueWork;@JsonKey(name: 'parent_hashes') List<String> get parentHashes;@JsonKey(name: 'children_hashes') List<String> get childrenHashes;@JsonKey(name: 'selected_parent_hash') String? get selectedParentHash;@JsonKey(name: 'merge_set_blues') List<String> get mergeSetBlues;@JsonKey(name: 'merge_set_reds') List<String> get mergeSetReds;@JsonKey(name: 'is_chain_block') bool get isChainBlock;@JsonKey(name: 'timestamp') int get timestampMs;@JsonKey(name: 'block_type') String get blockType;
/// Create a copy of DagBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DagBlockDtoCopyWith<DagBlockDto> get copyWith => _$DagBlockDtoCopyWithImpl<DagBlockDto>(this as DagBlockDto, _$identity);

  /// Serializes this DagBlockDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DagBlockDto&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.daaScore, daaScore) || other.daaScore == daaScore)&&(identical(other.blueScore, blueScore) || other.blueScore == blueScore)&&(identical(other.blueWork, blueWork) || other.blueWork == blueWork)&&const DeepCollectionEquality().equals(other.parentHashes, parentHashes)&&const DeepCollectionEquality().equals(other.childrenHashes, childrenHashes)&&(identical(other.selectedParentHash, selectedParentHash) || other.selectedParentHash == selectedParentHash)&&const DeepCollectionEquality().equals(other.mergeSetBlues, mergeSetBlues)&&const DeepCollectionEquality().equals(other.mergeSetReds, mergeSetReds)&&(identical(other.isChainBlock, isChainBlock) || other.isChainBlock == isChainBlock)&&(identical(other.timestampMs, timestampMs) || other.timestampMs == timestampMs)&&(identical(other.blockType, blockType) || other.blockType == blockType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hash,daaScore,blueScore,blueWork,const DeepCollectionEquality().hash(parentHashes),const DeepCollectionEquality().hash(childrenHashes),selectedParentHash,const DeepCollectionEquality().hash(mergeSetBlues),const DeepCollectionEquality().hash(mergeSetReds),isChainBlock,timestampMs,blockType);

@override
String toString() {
  return 'DagBlockDto(hash: $hash, daaScore: $daaScore, blueScore: $blueScore, blueWork: $blueWork, parentHashes: $parentHashes, childrenHashes: $childrenHashes, selectedParentHash: $selectedParentHash, mergeSetBlues: $mergeSetBlues, mergeSetReds: $mergeSetReds, isChainBlock: $isChainBlock, timestampMs: $timestampMs, blockType: $blockType)';
}


}

/// @nodoc
abstract mixin class $DagBlockDtoCopyWith<$Res>  {
  factory $DagBlockDtoCopyWith(DagBlockDto value, $Res Function(DagBlockDto) _then) = _$DagBlockDtoCopyWithImpl;
@useResult
$Res call({
 String hash,@JsonKey(name: 'daa_score') int daaScore,@JsonKey(name: 'blue_score') int blueScore,@JsonKey(name: 'blue_work') String blueWork,@JsonKey(name: 'parent_hashes') List<String> parentHashes,@JsonKey(name: 'children_hashes') List<String> childrenHashes,@JsonKey(name: 'selected_parent_hash') String? selectedParentHash,@JsonKey(name: 'merge_set_blues') List<String> mergeSetBlues,@JsonKey(name: 'merge_set_reds') List<String> mergeSetReds,@JsonKey(name: 'is_chain_block') bool isChainBlock,@JsonKey(name: 'timestamp') int timestampMs,@JsonKey(name: 'block_type') String blockType
});




}
/// @nodoc
class _$DagBlockDtoCopyWithImpl<$Res>
    implements $DagBlockDtoCopyWith<$Res> {
  _$DagBlockDtoCopyWithImpl(this._self, this._then);

  final DagBlockDto _self;
  final $Res Function(DagBlockDto) _then;

/// Create a copy of DagBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hash = null,Object? daaScore = null,Object? blueScore = null,Object? blueWork = null,Object? parentHashes = null,Object? childrenHashes = null,Object? selectedParentHash = freezed,Object? mergeSetBlues = null,Object? mergeSetReds = null,Object? isChainBlock = null,Object? timestampMs = null,Object? blockType = null,}) {
  return _then(_self.copyWith(
hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,daaScore: null == daaScore ? _self.daaScore : daaScore // ignore: cast_nullable_to_non_nullable
as int,blueScore: null == blueScore ? _self.blueScore : blueScore // ignore: cast_nullable_to_non_nullable
as int,blueWork: null == blueWork ? _self.blueWork : blueWork // ignore: cast_nullable_to_non_nullable
as String,parentHashes: null == parentHashes ? _self.parentHashes : parentHashes // ignore: cast_nullable_to_non_nullable
as List<String>,childrenHashes: null == childrenHashes ? _self.childrenHashes : childrenHashes // ignore: cast_nullable_to_non_nullable
as List<String>,selectedParentHash: freezed == selectedParentHash ? _self.selectedParentHash : selectedParentHash // ignore: cast_nullable_to_non_nullable
as String?,mergeSetBlues: null == mergeSetBlues ? _self.mergeSetBlues : mergeSetBlues // ignore: cast_nullable_to_non_nullable
as List<String>,mergeSetReds: null == mergeSetReds ? _self.mergeSetReds : mergeSetReds // ignore: cast_nullable_to_non_nullable
as List<String>,isChainBlock: null == isChainBlock ? _self.isChainBlock : isChainBlock // ignore: cast_nullable_to_non_nullable
as bool,timestampMs: null == timestampMs ? _self.timestampMs : timestampMs // ignore: cast_nullable_to_non_nullable
as int,blockType: null == blockType ? _self.blockType : blockType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DagBlockDto].
extension DagBlockDtoPatterns on DagBlockDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DagBlockDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DagBlockDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DagBlockDto value)  $default,){
final _that = this;
switch (_that) {
case _DagBlockDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DagBlockDto value)?  $default,){
final _that = this;
switch (_that) {
case _DagBlockDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hash, @JsonKey(name: 'daa_score')  int daaScore, @JsonKey(name: 'blue_score')  int blueScore, @JsonKey(name: 'blue_work')  String blueWork, @JsonKey(name: 'parent_hashes')  List<String> parentHashes, @JsonKey(name: 'children_hashes')  List<String> childrenHashes, @JsonKey(name: 'selected_parent_hash')  String? selectedParentHash, @JsonKey(name: 'merge_set_blues')  List<String> mergeSetBlues, @JsonKey(name: 'merge_set_reds')  List<String> mergeSetReds, @JsonKey(name: 'is_chain_block')  bool isChainBlock, @JsonKey(name: 'timestamp')  int timestampMs, @JsonKey(name: 'block_type')  String blockType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DagBlockDto() when $default != null:
return $default(_that.hash,_that.daaScore,_that.blueScore,_that.blueWork,_that.parentHashes,_that.childrenHashes,_that.selectedParentHash,_that.mergeSetBlues,_that.mergeSetReds,_that.isChainBlock,_that.timestampMs,_that.blockType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hash, @JsonKey(name: 'daa_score')  int daaScore, @JsonKey(name: 'blue_score')  int blueScore, @JsonKey(name: 'blue_work')  String blueWork, @JsonKey(name: 'parent_hashes')  List<String> parentHashes, @JsonKey(name: 'children_hashes')  List<String> childrenHashes, @JsonKey(name: 'selected_parent_hash')  String? selectedParentHash, @JsonKey(name: 'merge_set_blues')  List<String> mergeSetBlues, @JsonKey(name: 'merge_set_reds')  List<String> mergeSetReds, @JsonKey(name: 'is_chain_block')  bool isChainBlock, @JsonKey(name: 'timestamp')  int timestampMs, @JsonKey(name: 'block_type')  String blockType)  $default,) {final _that = this;
switch (_that) {
case _DagBlockDto():
return $default(_that.hash,_that.daaScore,_that.blueScore,_that.blueWork,_that.parentHashes,_that.childrenHashes,_that.selectedParentHash,_that.mergeSetBlues,_that.mergeSetReds,_that.isChainBlock,_that.timestampMs,_that.blockType);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hash, @JsonKey(name: 'daa_score')  int daaScore, @JsonKey(name: 'blue_score')  int blueScore, @JsonKey(name: 'blue_work')  String blueWork, @JsonKey(name: 'parent_hashes')  List<String> parentHashes, @JsonKey(name: 'children_hashes')  List<String> childrenHashes, @JsonKey(name: 'selected_parent_hash')  String? selectedParentHash, @JsonKey(name: 'merge_set_blues')  List<String> mergeSetBlues, @JsonKey(name: 'merge_set_reds')  List<String> mergeSetReds, @JsonKey(name: 'is_chain_block')  bool isChainBlock, @JsonKey(name: 'timestamp')  int timestampMs, @JsonKey(name: 'block_type')  String blockType)?  $default,) {final _that = this;
switch (_that) {
case _DagBlockDto() when $default != null:
return $default(_that.hash,_that.daaScore,_that.blueScore,_that.blueWork,_that.parentHashes,_that.childrenHashes,_that.selectedParentHash,_that.mergeSetBlues,_that.mergeSetReds,_that.isChainBlock,_that.timestampMs,_that.blockType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DagBlockDto extends DagBlockDto {
  const _DagBlockDto({required this.hash, @JsonKey(name: 'daa_score') required this.daaScore, @JsonKey(name: 'blue_score') required this.blueScore, @JsonKey(name: 'blue_work') required this.blueWork, @JsonKey(name: 'parent_hashes') required final  List<String> parentHashes, @JsonKey(name: 'children_hashes') final  List<String> childrenHashes = const [], @JsonKey(name: 'selected_parent_hash') this.selectedParentHash, @JsonKey(name: 'merge_set_blues') final  List<String> mergeSetBlues = const [], @JsonKey(name: 'merge_set_reds') final  List<String> mergeSetReds = const [], @JsonKey(name: 'is_chain_block') this.isChainBlock = false, @JsonKey(name: 'timestamp') required this.timestampMs, @JsonKey(name: 'block_type') this.blockType = 'regular'}): _parentHashes = parentHashes,_childrenHashes = childrenHashes,_mergeSetBlues = mergeSetBlues,_mergeSetReds = mergeSetReds,super._();
  factory _DagBlockDto.fromJson(Map<String, dynamic> json) => _$DagBlockDtoFromJson(json);

@override final  String hash;
@override@JsonKey(name: 'daa_score') final  int daaScore;
@override@JsonKey(name: 'blue_score') final  int blueScore;
@override@JsonKey(name: 'blue_work') final  String blueWork;
 final  List<String> _parentHashes;
@override@JsonKey(name: 'parent_hashes') List<String> get parentHashes {
  if (_parentHashes is EqualUnmodifiableListView) return _parentHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parentHashes);
}

 final  List<String> _childrenHashes;
@override@JsonKey(name: 'children_hashes') List<String> get childrenHashes {
  if (_childrenHashes is EqualUnmodifiableListView) return _childrenHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_childrenHashes);
}

@override@JsonKey(name: 'selected_parent_hash') final  String? selectedParentHash;
 final  List<String> _mergeSetBlues;
@override@JsonKey(name: 'merge_set_blues') List<String> get mergeSetBlues {
  if (_mergeSetBlues is EqualUnmodifiableListView) return _mergeSetBlues;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mergeSetBlues);
}

 final  List<String> _mergeSetReds;
@override@JsonKey(name: 'merge_set_reds') List<String> get mergeSetReds {
  if (_mergeSetReds is EqualUnmodifiableListView) return _mergeSetReds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mergeSetReds);
}

@override@JsonKey(name: 'is_chain_block') final  bool isChainBlock;
@override@JsonKey(name: 'timestamp') final  int timestampMs;
@override@JsonKey(name: 'block_type') final  String blockType;

/// Create a copy of DagBlockDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DagBlockDtoCopyWith<_DagBlockDto> get copyWith => __$DagBlockDtoCopyWithImpl<_DagBlockDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DagBlockDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DagBlockDto&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.daaScore, daaScore) || other.daaScore == daaScore)&&(identical(other.blueScore, blueScore) || other.blueScore == blueScore)&&(identical(other.blueWork, blueWork) || other.blueWork == blueWork)&&const DeepCollectionEquality().equals(other._parentHashes, _parentHashes)&&const DeepCollectionEquality().equals(other._childrenHashes, _childrenHashes)&&(identical(other.selectedParentHash, selectedParentHash) || other.selectedParentHash == selectedParentHash)&&const DeepCollectionEquality().equals(other._mergeSetBlues, _mergeSetBlues)&&const DeepCollectionEquality().equals(other._mergeSetReds, _mergeSetReds)&&(identical(other.isChainBlock, isChainBlock) || other.isChainBlock == isChainBlock)&&(identical(other.timestampMs, timestampMs) || other.timestampMs == timestampMs)&&(identical(other.blockType, blockType) || other.blockType == blockType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hash,daaScore,blueScore,blueWork,const DeepCollectionEquality().hash(_parentHashes),const DeepCollectionEquality().hash(_childrenHashes),selectedParentHash,const DeepCollectionEquality().hash(_mergeSetBlues),const DeepCollectionEquality().hash(_mergeSetReds),isChainBlock,timestampMs,blockType);

@override
String toString() {
  return 'DagBlockDto(hash: $hash, daaScore: $daaScore, blueScore: $blueScore, blueWork: $blueWork, parentHashes: $parentHashes, childrenHashes: $childrenHashes, selectedParentHash: $selectedParentHash, mergeSetBlues: $mergeSetBlues, mergeSetReds: $mergeSetReds, isChainBlock: $isChainBlock, timestampMs: $timestampMs, blockType: $blockType)';
}


}

/// @nodoc
abstract mixin class _$DagBlockDtoCopyWith<$Res> implements $DagBlockDtoCopyWith<$Res> {
  factory _$DagBlockDtoCopyWith(_DagBlockDto value, $Res Function(_DagBlockDto) _then) = __$DagBlockDtoCopyWithImpl;
@override @useResult
$Res call({
 String hash,@JsonKey(name: 'daa_score') int daaScore,@JsonKey(name: 'blue_score') int blueScore,@JsonKey(name: 'blue_work') String blueWork,@JsonKey(name: 'parent_hashes') List<String> parentHashes,@JsonKey(name: 'children_hashes') List<String> childrenHashes,@JsonKey(name: 'selected_parent_hash') String? selectedParentHash,@JsonKey(name: 'merge_set_blues') List<String> mergeSetBlues,@JsonKey(name: 'merge_set_reds') List<String> mergeSetReds,@JsonKey(name: 'is_chain_block') bool isChainBlock,@JsonKey(name: 'timestamp') int timestampMs,@JsonKey(name: 'block_type') String blockType
});




}
/// @nodoc
class __$DagBlockDtoCopyWithImpl<$Res>
    implements _$DagBlockDtoCopyWith<$Res> {
  __$DagBlockDtoCopyWithImpl(this._self, this._then);

  final _DagBlockDto _self;
  final $Res Function(_DagBlockDto) _then;

/// Create a copy of DagBlockDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hash = null,Object? daaScore = null,Object? blueScore = null,Object? blueWork = null,Object? parentHashes = null,Object? childrenHashes = null,Object? selectedParentHash = freezed,Object? mergeSetBlues = null,Object? mergeSetReds = null,Object? isChainBlock = null,Object? timestampMs = null,Object? blockType = null,}) {
  return _then(_DagBlockDto(
hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,daaScore: null == daaScore ? _self.daaScore : daaScore // ignore: cast_nullable_to_non_nullable
as int,blueScore: null == blueScore ? _self.blueScore : blueScore // ignore: cast_nullable_to_non_nullable
as int,blueWork: null == blueWork ? _self.blueWork : blueWork // ignore: cast_nullable_to_non_nullable
as String,parentHashes: null == parentHashes ? _self._parentHashes : parentHashes // ignore: cast_nullable_to_non_nullable
as List<String>,childrenHashes: null == childrenHashes ? _self._childrenHashes : childrenHashes // ignore: cast_nullable_to_non_nullable
as List<String>,selectedParentHash: freezed == selectedParentHash ? _self.selectedParentHash : selectedParentHash // ignore: cast_nullable_to_non_nullable
as String?,mergeSetBlues: null == mergeSetBlues ? _self._mergeSetBlues : mergeSetBlues // ignore: cast_nullable_to_non_nullable
as List<String>,mergeSetReds: null == mergeSetReds ? _self._mergeSetReds : mergeSetReds // ignore: cast_nullable_to_non_nullable
as List<String>,isChainBlock: null == isChainBlock ? _self.isChainBlock : isChainBlock // ignore: cast_nullable_to_non_nullable
as bool,timestampMs: null == timestampMs ? _self.timestampMs : timestampMs // ignore: cast_nullable_to_non_nullable
as int,blockType: null == blockType ? _self.blockType : blockType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
