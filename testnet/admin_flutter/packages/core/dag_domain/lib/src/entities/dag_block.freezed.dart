// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dag_block.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DagBlock {

 BlockHash get hash; DaaScore get daaScore; BlueScore get blueScore; BlueWork get blueWork; List<BlockHash> get parentHashes; List<BlockHash> get childrenHashes; BlockHash? get selectedParentHash; List<BlockHash> get mergeSetBlues; List<BlockHash> get mergeSetReds; bool get isChainBlock; DateTime get timestamp; DagBlockType get blockType;
/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DagBlockCopyWith<DagBlock> get copyWith => _$DagBlockCopyWithImpl<DagBlock>(this as DagBlock, _$identity);

  /// Serializes this DagBlock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DagBlock&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.daaScore, daaScore) || other.daaScore == daaScore)&&(identical(other.blueScore, blueScore) || other.blueScore == blueScore)&&(identical(other.blueWork, blueWork) || other.blueWork == blueWork)&&const DeepCollectionEquality().equals(other.parentHashes, parentHashes)&&const DeepCollectionEquality().equals(other.childrenHashes, childrenHashes)&&(identical(other.selectedParentHash, selectedParentHash) || other.selectedParentHash == selectedParentHash)&&const DeepCollectionEquality().equals(other.mergeSetBlues, mergeSetBlues)&&const DeepCollectionEquality().equals(other.mergeSetReds, mergeSetReds)&&(identical(other.isChainBlock, isChainBlock) || other.isChainBlock == isChainBlock)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.blockType, blockType) || other.blockType == blockType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hash,daaScore,blueScore,blueWork,const DeepCollectionEquality().hash(parentHashes),const DeepCollectionEquality().hash(childrenHashes),selectedParentHash,const DeepCollectionEquality().hash(mergeSetBlues),const DeepCollectionEquality().hash(mergeSetReds),isChainBlock,timestamp,blockType);

@override
String toString() {
  return 'DagBlock(hash: $hash, daaScore: $daaScore, blueScore: $blueScore, blueWork: $blueWork, parentHashes: $parentHashes, childrenHashes: $childrenHashes, selectedParentHash: $selectedParentHash, mergeSetBlues: $mergeSetBlues, mergeSetReds: $mergeSetReds, isChainBlock: $isChainBlock, timestamp: $timestamp, blockType: $blockType)';
}


}

/// @nodoc
abstract mixin class $DagBlockCopyWith<$Res>  {
  factory $DagBlockCopyWith(DagBlock value, $Res Function(DagBlock) _then) = _$DagBlockCopyWithImpl;
@useResult
$Res call({
 BlockHash hash, DaaScore daaScore, BlueScore blueScore, BlueWork blueWork, List<BlockHash> parentHashes, List<BlockHash> childrenHashes, BlockHash? selectedParentHash, List<BlockHash> mergeSetBlues, List<BlockHash> mergeSetReds, bool isChainBlock, DateTime timestamp, DagBlockType blockType
});


$BlockHashCopyWith<$Res> get hash;$DaaScoreCopyWith<$Res> get daaScore;$BlueScoreCopyWith<$Res> get blueScore;$BlueWorkCopyWith<$Res> get blueWork;$BlockHashCopyWith<$Res>? get selectedParentHash;

}
/// @nodoc
class _$DagBlockCopyWithImpl<$Res>
    implements $DagBlockCopyWith<$Res> {
  _$DagBlockCopyWithImpl(this._self, this._then);

  final DagBlock _self;
  final $Res Function(DagBlock) _then;

/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hash = null,Object? daaScore = null,Object? blueScore = null,Object? blueWork = null,Object? parentHashes = null,Object? childrenHashes = null,Object? selectedParentHash = freezed,Object? mergeSetBlues = null,Object? mergeSetReds = null,Object? isChainBlock = null,Object? timestamp = null,Object? blockType = null,}) {
  return _then(_self.copyWith(
hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as BlockHash,daaScore: null == daaScore ? _self.daaScore : daaScore // ignore: cast_nullable_to_non_nullable
as DaaScore,blueScore: null == blueScore ? _self.blueScore : blueScore // ignore: cast_nullable_to_non_nullable
as BlueScore,blueWork: null == blueWork ? _self.blueWork : blueWork // ignore: cast_nullable_to_non_nullable
as BlueWork,parentHashes: null == parentHashes ? _self.parentHashes : parentHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,childrenHashes: null == childrenHashes ? _self.childrenHashes : childrenHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,selectedParentHash: freezed == selectedParentHash ? _self.selectedParentHash : selectedParentHash // ignore: cast_nullable_to_non_nullable
as BlockHash?,mergeSetBlues: null == mergeSetBlues ? _self.mergeSetBlues : mergeSetBlues // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,mergeSetReds: null == mergeSetReds ? _self.mergeSetReds : mergeSetReds // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,isChainBlock: null == isChainBlock ? _self.isChainBlock : isChainBlock // ignore: cast_nullable_to_non_nullable
as bool,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,blockType: null == blockType ? _self.blockType : blockType // ignore: cast_nullable_to_non_nullable
as DagBlockType,
  ));
}
/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res> get hash {
  
  return $BlockHashCopyWith<$Res>(_self.hash, (value) {
    return _then(_self.copyWith(hash: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DaaScoreCopyWith<$Res> get daaScore {
  
  return $DaaScoreCopyWith<$Res>(_self.daaScore, (value) {
    return _then(_self.copyWith(daaScore: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlueScoreCopyWith<$Res> get blueScore {
  
  return $BlueScoreCopyWith<$Res>(_self.blueScore, (value) {
    return _then(_self.copyWith(blueScore: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlueWorkCopyWith<$Res> get blueWork {
  
  return $BlueWorkCopyWith<$Res>(_self.blueWork, (value) {
    return _then(_self.copyWith(blueWork: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res>? get selectedParentHash {
    if (_self.selectedParentHash == null) {
    return null;
  }

  return $BlockHashCopyWith<$Res>(_self.selectedParentHash!, (value) {
    return _then(_self.copyWith(selectedParentHash: value));
  });
}
}


/// Adds pattern-matching-related methods to [DagBlock].
extension DagBlockPatterns on DagBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DagBlock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DagBlock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DagBlock value)  $default,){
final _that = this;
switch (_that) {
case _DagBlock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DagBlock value)?  $default,){
final _that = this;
switch (_that) {
case _DagBlock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BlockHash hash,  DaaScore daaScore,  BlueScore blueScore,  BlueWork blueWork,  List<BlockHash> parentHashes,  List<BlockHash> childrenHashes,  BlockHash? selectedParentHash,  List<BlockHash> mergeSetBlues,  List<BlockHash> mergeSetReds,  bool isChainBlock,  DateTime timestamp,  DagBlockType blockType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DagBlock() when $default != null:
return $default(_that.hash,_that.daaScore,_that.blueScore,_that.blueWork,_that.parentHashes,_that.childrenHashes,_that.selectedParentHash,_that.mergeSetBlues,_that.mergeSetReds,_that.isChainBlock,_that.timestamp,_that.blockType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BlockHash hash,  DaaScore daaScore,  BlueScore blueScore,  BlueWork blueWork,  List<BlockHash> parentHashes,  List<BlockHash> childrenHashes,  BlockHash? selectedParentHash,  List<BlockHash> mergeSetBlues,  List<BlockHash> mergeSetReds,  bool isChainBlock,  DateTime timestamp,  DagBlockType blockType)  $default,) {final _that = this;
switch (_that) {
case _DagBlock():
return $default(_that.hash,_that.daaScore,_that.blueScore,_that.blueWork,_that.parentHashes,_that.childrenHashes,_that.selectedParentHash,_that.mergeSetBlues,_that.mergeSetReds,_that.isChainBlock,_that.timestamp,_that.blockType);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BlockHash hash,  DaaScore daaScore,  BlueScore blueScore,  BlueWork blueWork,  List<BlockHash> parentHashes,  List<BlockHash> childrenHashes,  BlockHash? selectedParentHash,  List<BlockHash> mergeSetBlues,  List<BlockHash> mergeSetReds,  bool isChainBlock,  DateTime timestamp,  DagBlockType blockType)?  $default,) {final _that = this;
switch (_that) {
case _DagBlock() when $default != null:
return $default(_that.hash,_that.daaScore,_that.blueScore,_that.blueWork,_that.parentHashes,_that.childrenHashes,_that.selectedParentHash,_that.mergeSetBlues,_that.mergeSetReds,_that.isChainBlock,_that.timestamp,_that.blockType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DagBlock extends DagBlock {
  const _DagBlock({required this.hash, required this.daaScore, required this.blueScore, required this.blueWork, required final  List<BlockHash> parentHashes, final  List<BlockHash> childrenHashes = const [], this.selectedParentHash, final  List<BlockHash> mergeSetBlues = const [], final  List<BlockHash> mergeSetReds = const [], this.isChainBlock = false, required this.timestamp, this.blockType = DagBlockType.regular}): _parentHashes = parentHashes,_childrenHashes = childrenHashes,_mergeSetBlues = mergeSetBlues,_mergeSetReds = mergeSetReds,super._();
  factory _DagBlock.fromJson(Map<String, dynamic> json) => _$DagBlockFromJson(json);

@override final  BlockHash hash;
@override final  DaaScore daaScore;
@override final  BlueScore blueScore;
@override final  BlueWork blueWork;
 final  List<BlockHash> _parentHashes;
@override List<BlockHash> get parentHashes {
  if (_parentHashes is EqualUnmodifiableListView) return _parentHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parentHashes);
}

 final  List<BlockHash> _childrenHashes;
@override@JsonKey() List<BlockHash> get childrenHashes {
  if (_childrenHashes is EqualUnmodifiableListView) return _childrenHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_childrenHashes);
}

@override final  BlockHash? selectedParentHash;
 final  List<BlockHash> _mergeSetBlues;
@override@JsonKey() List<BlockHash> get mergeSetBlues {
  if (_mergeSetBlues is EqualUnmodifiableListView) return _mergeSetBlues;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mergeSetBlues);
}

 final  List<BlockHash> _mergeSetReds;
@override@JsonKey() List<BlockHash> get mergeSetReds {
  if (_mergeSetReds is EqualUnmodifiableListView) return _mergeSetReds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mergeSetReds);
}

@override@JsonKey() final  bool isChainBlock;
@override final  DateTime timestamp;
@override@JsonKey() final  DagBlockType blockType;

/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DagBlockCopyWith<_DagBlock> get copyWith => __$DagBlockCopyWithImpl<_DagBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DagBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DagBlock&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.daaScore, daaScore) || other.daaScore == daaScore)&&(identical(other.blueScore, blueScore) || other.blueScore == blueScore)&&(identical(other.blueWork, blueWork) || other.blueWork == blueWork)&&const DeepCollectionEquality().equals(other._parentHashes, _parentHashes)&&const DeepCollectionEquality().equals(other._childrenHashes, _childrenHashes)&&(identical(other.selectedParentHash, selectedParentHash) || other.selectedParentHash == selectedParentHash)&&const DeepCollectionEquality().equals(other._mergeSetBlues, _mergeSetBlues)&&const DeepCollectionEquality().equals(other._mergeSetReds, _mergeSetReds)&&(identical(other.isChainBlock, isChainBlock) || other.isChainBlock == isChainBlock)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.blockType, blockType) || other.blockType == blockType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hash,daaScore,blueScore,blueWork,const DeepCollectionEquality().hash(_parentHashes),const DeepCollectionEquality().hash(_childrenHashes),selectedParentHash,const DeepCollectionEquality().hash(_mergeSetBlues),const DeepCollectionEquality().hash(_mergeSetReds),isChainBlock,timestamp,blockType);

@override
String toString() {
  return 'DagBlock(hash: $hash, daaScore: $daaScore, blueScore: $blueScore, blueWork: $blueWork, parentHashes: $parentHashes, childrenHashes: $childrenHashes, selectedParentHash: $selectedParentHash, mergeSetBlues: $mergeSetBlues, mergeSetReds: $mergeSetReds, isChainBlock: $isChainBlock, timestamp: $timestamp, blockType: $blockType)';
}


}

/// @nodoc
abstract mixin class _$DagBlockCopyWith<$Res> implements $DagBlockCopyWith<$Res> {
  factory _$DagBlockCopyWith(_DagBlock value, $Res Function(_DagBlock) _then) = __$DagBlockCopyWithImpl;
@override @useResult
$Res call({
 BlockHash hash, DaaScore daaScore, BlueScore blueScore, BlueWork blueWork, List<BlockHash> parentHashes, List<BlockHash> childrenHashes, BlockHash? selectedParentHash, List<BlockHash> mergeSetBlues, List<BlockHash> mergeSetReds, bool isChainBlock, DateTime timestamp, DagBlockType blockType
});


@override $BlockHashCopyWith<$Res> get hash;@override $DaaScoreCopyWith<$Res> get daaScore;@override $BlueScoreCopyWith<$Res> get blueScore;@override $BlueWorkCopyWith<$Res> get blueWork;@override $BlockHashCopyWith<$Res>? get selectedParentHash;

}
/// @nodoc
class __$DagBlockCopyWithImpl<$Res>
    implements _$DagBlockCopyWith<$Res> {
  __$DagBlockCopyWithImpl(this._self, this._then);

  final _DagBlock _self;
  final $Res Function(_DagBlock) _then;

/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hash = null,Object? daaScore = null,Object? blueScore = null,Object? blueWork = null,Object? parentHashes = null,Object? childrenHashes = null,Object? selectedParentHash = freezed,Object? mergeSetBlues = null,Object? mergeSetReds = null,Object? isChainBlock = null,Object? timestamp = null,Object? blockType = null,}) {
  return _then(_DagBlock(
hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as BlockHash,daaScore: null == daaScore ? _self.daaScore : daaScore // ignore: cast_nullable_to_non_nullable
as DaaScore,blueScore: null == blueScore ? _self.blueScore : blueScore // ignore: cast_nullable_to_non_nullable
as BlueScore,blueWork: null == blueWork ? _self.blueWork : blueWork // ignore: cast_nullable_to_non_nullable
as BlueWork,parentHashes: null == parentHashes ? _self._parentHashes : parentHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,childrenHashes: null == childrenHashes ? _self._childrenHashes : childrenHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,selectedParentHash: freezed == selectedParentHash ? _self.selectedParentHash : selectedParentHash // ignore: cast_nullable_to_non_nullable
as BlockHash?,mergeSetBlues: null == mergeSetBlues ? _self._mergeSetBlues : mergeSetBlues // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,mergeSetReds: null == mergeSetReds ? _self._mergeSetReds : mergeSetReds // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,isChainBlock: null == isChainBlock ? _self.isChainBlock : isChainBlock // ignore: cast_nullable_to_non_nullable
as bool,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,blockType: null == blockType ? _self.blockType : blockType // ignore: cast_nullable_to_non_nullable
as DagBlockType,
  ));
}

/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res> get hash {
  
  return $BlockHashCopyWith<$Res>(_self.hash, (value) {
    return _then(_self.copyWith(hash: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DaaScoreCopyWith<$Res> get daaScore {
  
  return $DaaScoreCopyWith<$Res>(_self.daaScore, (value) {
    return _then(_self.copyWith(daaScore: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlueScoreCopyWith<$Res> get blueScore {
  
  return $BlueScoreCopyWith<$Res>(_self.blueScore, (value) {
    return _then(_self.copyWith(blueScore: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlueWorkCopyWith<$Res> get blueWork {
  
  return $BlueWorkCopyWith<$Res>(_self.blueWork, (value) {
    return _then(_self.copyWith(blueWork: value));
  });
}/// Create a copy of DagBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res>? get selectedParentHash {
    if (_self.selectedParentHash == null) {
    return null;
  }

  return $BlockHashCopyWith<$Res>(_self.selectedParentHash!, (value) {
    return _then(_self.copyWith(selectedParentHash: value));
  });
}
}

// dart format on
