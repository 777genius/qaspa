// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dag_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DagState {

 List<BlockHash> get tipHashes; BlockHash get sinkHash; BlockHash get pruningPointHash; DaaScore get virtualDaaScore; int get blockCount; double get difficulty; Map<String, DagBlock> get blocks; DagBlock? get virtualBlock; bool get isConnected; bool get isLoading; String? get error;
/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DagStateCopyWith<DagState> get copyWith => _$DagStateCopyWithImpl<DagState>(this as DagState, _$identity);

  /// Serializes this DagState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DagState&&const DeepCollectionEquality().equals(other.tipHashes, tipHashes)&&(identical(other.sinkHash, sinkHash) || other.sinkHash == sinkHash)&&(identical(other.pruningPointHash, pruningPointHash) || other.pruningPointHash == pruningPointHash)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.blockCount, blockCount) || other.blockCount == blockCount)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&(identical(other.virtualBlock, virtualBlock) || other.virtualBlock == virtualBlock)&&(identical(other.isConnected, isConnected) || other.isConnected == isConnected)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tipHashes),sinkHash,pruningPointHash,virtualDaaScore,blockCount,difficulty,const DeepCollectionEquality().hash(blocks),virtualBlock,isConnected,isLoading,error);

@override
String toString() {
  return 'DagState(tipHashes: $tipHashes, sinkHash: $sinkHash, pruningPointHash: $pruningPointHash, virtualDaaScore: $virtualDaaScore, blockCount: $blockCount, difficulty: $difficulty, blocks: $blocks, virtualBlock: $virtualBlock, isConnected: $isConnected, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class $DagStateCopyWith<$Res>  {
  factory $DagStateCopyWith(DagState value, $Res Function(DagState) _then) = _$DagStateCopyWithImpl;
@useResult
$Res call({
 List<BlockHash> tipHashes, BlockHash sinkHash, BlockHash pruningPointHash, DaaScore virtualDaaScore, int blockCount, double difficulty, Map<String, DagBlock> blocks, DagBlock? virtualBlock, bool isConnected, bool isLoading, String? error
});


$BlockHashCopyWith<$Res> get sinkHash;$BlockHashCopyWith<$Res> get pruningPointHash;$DaaScoreCopyWith<$Res> get virtualDaaScore;$DagBlockCopyWith<$Res>? get virtualBlock;

}
/// @nodoc
class _$DagStateCopyWithImpl<$Res>
    implements $DagStateCopyWith<$Res> {
  _$DagStateCopyWithImpl(this._self, this._then);

  final DagState _self;
  final $Res Function(DagState) _then;

/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tipHashes = null,Object? sinkHash = null,Object? pruningPointHash = null,Object? virtualDaaScore = null,Object? blockCount = null,Object? difficulty = null,Object? blocks = null,Object? virtualBlock = freezed,Object? isConnected = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
tipHashes: null == tipHashes ? _self.tipHashes : tipHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,sinkHash: null == sinkHash ? _self.sinkHash : sinkHash // ignore: cast_nullable_to_non_nullable
as BlockHash,pruningPointHash: null == pruningPointHash ? _self.pruningPointHash : pruningPointHash // ignore: cast_nullable_to_non_nullable
as BlockHash,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as DaaScore,blockCount: null == blockCount ? _self.blockCount : blockCount // ignore: cast_nullable_to_non_nullable
as int,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as Map<String, DagBlock>,virtualBlock: freezed == virtualBlock ? _self.virtualBlock : virtualBlock // ignore: cast_nullable_to_non_nullable
as DagBlock?,isConnected: null == isConnected ? _self.isConnected : isConnected // ignore: cast_nullable_to_non_nullable
as bool,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res> get sinkHash {
  
  return $BlockHashCopyWith<$Res>(_self.sinkHash, (value) {
    return _then(_self.copyWith(sinkHash: value));
  });
}/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res> get pruningPointHash {
  
  return $BlockHashCopyWith<$Res>(_self.pruningPointHash, (value) {
    return _then(_self.copyWith(pruningPointHash: value));
  });
}/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DaaScoreCopyWith<$Res> get virtualDaaScore {
  
  return $DaaScoreCopyWith<$Res>(_self.virtualDaaScore, (value) {
    return _then(_self.copyWith(virtualDaaScore: value));
  });
}/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DagBlockCopyWith<$Res>? get virtualBlock {
    if (_self.virtualBlock == null) {
    return null;
  }

  return $DagBlockCopyWith<$Res>(_self.virtualBlock!, (value) {
    return _then(_self.copyWith(virtualBlock: value));
  });
}
}


/// Adds pattern-matching-related methods to [DagState].
extension DagStatePatterns on DagState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DagState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DagState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DagState value)  $default,){
final _that = this;
switch (_that) {
case _DagState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DagState value)?  $default,){
final _that = this;
switch (_that) {
case _DagState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BlockHash> tipHashes,  BlockHash sinkHash,  BlockHash pruningPointHash,  DaaScore virtualDaaScore,  int blockCount,  double difficulty,  Map<String, DagBlock> blocks,  DagBlock? virtualBlock,  bool isConnected,  bool isLoading,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DagState() when $default != null:
return $default(_that.tipHashes,_that.sinkHash,_that.pruningPointHash,_that.virtualDaaScore,_that.blockCount,_that.difficulty,_that.blocks,_that.virtualBlock,_that.isConnected,_that.isLoading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BlockHash> tipHashes,  BlockHash sinkHash,  BlockHash pruningPointHash,  DaaScore virtualDaaScore,  int blockCount,  double difficulty,  Map<String, DagBlock> blocks,  DagBlock? virtualBlock,  bool isConnected,  bool isLoading,  String? error)  $default,) {final _that = this;
switch (_that) {
case _DagState():
return $default(_that.tipHashes,_that.sinkHash,_that.pruningPointHash,_that.virtualDaaScore,_that.blockCount,_that.difficulty,_that.blocks,_that.virtualBlock,_that.isConnected,_that.isLoading,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BlockHash> tipHashes,  BlockHash sinkHash,  BlockHash pruningPointHash,  DaaScore virtualDaaScore,  int blockCount,  double difficulty,  Map<String, DagBlock> blocks,  DagBlock? virtualBlock,  bool isConnected,  bool isLoading,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _DagState() when $default != null:
return $default(_that.tipHashes,_that.sinkHash,_that.pruningPointHash,_that.virtualDaaScore,_that.blockCount,_that.difficulty,_that.blocks,_that.virtualBlock,_that.isConnected,_that.isLoading,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DagState extends DagState {
  const _DagState({required final  List<BlockHash> tipHashes, required this.sinkHash, required this.pruningPointHash, required this.virtualDaaScore, required this.blockCount, required this.difficulty, final  Map<String, DagBlock> blocks = const {}, this.virtualBlock, this.isConnected = false, this.isLoading = false, this.error}): _tipHashes = tipHashes,_blocks = blocks,super._();
  factory _DagState.fromJson(Map<String, dynamic> json) => _$DagStateFromJson(json);

 final  List<BlockHash> _tipHashes;
@override List<BlockHash> get tipHashes {
  if (_tipHashes is EqualUnmodifiableListView) return _tipHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tipHashes);
}

@override final  BlockHash sinkHash;
@override final  BlockHash pruningPointHash;
@override final  DaaScore virtualDaaScore;
@override final  int blockCount;
@override final  double difficulty;
 final  Map<String, DagBlock> _blocks;
@override@JsonKey() Map<String, DagBlock> get blocks {
  if (_blocks is EqualUnmodifiableMapView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_blocks);
}

@override final  DagBlock? virtualBlock;
@override@JsonKey() final  bool isConnected;
@override@JsonKey() final  bool isLoading;
@override final  String? error;

/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DagStateCopyWith<_DagState> get copyWith => __$DagStateCopyWithImpl<_DagState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DagStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DagState&&const DeepCollectionEquality().equals(other._tipHashes, _tipHashes)&&(identical(other.sinkHash, sinkHash) || other.sinkHash == sinkHash)&&(identical(other.pruningPointHash, pruningPointHash) || other.pruningPointHash == pruningPointHash)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.blockCount, blockCount) || other.blockCount == blockCount)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&(identical(other.virtualBlock, virtualBlock) || other.virtualBlock == virtualBlock)&&(identical(other.isConnected, isConnected) || other.isConnected == isConnected)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tipHashes),sinkHash,pruningPointHash,virtualDaaScore,blockCount,difficulty,const DeepCollectionEquality().hash(_blocks),virtualBlock,isConnected,isLoading,error);

@override
String toString() {
  return 'DagState(tipHashes: $tipHashes, sinkHash: $sinkHash, pruningPointHash: $pruningPointHash, virtualDaaScore: $virtualDaaScore, blockCount: $blockCount, difficulty: $difficulty, blocks: $blocks, virtualBlock: $virtualBlock, isConnected: $isConnected, isLoading: $isLoading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$DagStateCopyWith<$Res> implements $DagStateCopyWith<$Res> {
  factory _$DagStateCopyWith(_DagState value, $Res Function(_DagState) _then) = __$DagStateCopyWithImpl;
@override @useResult
$Res call({
 List<BlockHash> tipHashes, BlockHash sinkHash, BlockHash pruningPointHash, DaaScore virtualDaaScore, int blockCount, double difficulty, Map<String, DagBlock> blocks, DagBlock? virtualBlock, bool isConnected, bool isLoading, String? error
});


@override $BlockHashCopyWith<$Res> get sinkHash;@override $BlockHashCopyWith<$Res> get pruningPointHash;@override $DaaScoreCopyWith<$Res> get virtualDaaScore;@override $DagBlockCopyWith<$Res>? get virtualBlock;

}
/// @nodoc
class __$DagStateCopyWithImpl<$Res>
    implements _$DagStateCopyWith<$Res> {
  __$DagStateCopyWithImpl(this._self, this._then);

  final _DagState _self;
  final $Res Function(_DagState) _then;

/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tipHashes = null,Object? sinkHash = null,Object? pruningPointHash = null,Object? virtualDaaScore = null,Object? blockCount = null,Object? difficulty = null,Object? blocks = null,Object? virtualBlock = freezed,Object? isConnected = null,Object? isLoading = null,Object? error = freezed,}) {
  return _then(_DagState(
tipHashes: null == tipHashes ? _self._tipHashes : tipHashes // ignore: cast_nullable_to_non_nullable
as List<BlockHash>,sinkHash: null == sinkHash ? _self.sinkHash : sinkHash // ignore: cast_nullable_to_non_nullable
as BlockHash,pruningPointHash: null == pruningPointHash ? _self.pruningPointHash : pruningPointHash // ignore: cast_nullable_to_non_nullable
as BlockHash,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as DaaScore,blockCount: null == blockCount ? _self.blockCount : blockCount // ignore: cast_nullable_to_non_nullable
as int,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as Map<String, DagBlock>,virtualBlock: freezed == virtualBlock ? _self.virtualBlock : virtualBlock // ignore: cast_nullable_to_non_nullable
as DagBlock?,isConnected: null == isConnected ? _self.isConnected : isConnected // ignore: cast_nullable_to_non_nullable
as bool,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res> get sinkHash {
  
  return $BlockHashCopyWith<$Res>(_self.sinkHash, (value) {
    return _then(_self.copyWith(sinkHash: value));
  });
}/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockHashCopyWith<$Res> get pruningPointHash {
  
  return $BlockHashCopyWith<$Res>(_self.pruningPointHash, (value) {
    return _then(_self.copyWith(pruningPointHash: value));
  });
}/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DaaScoreCopyWith<$Res> get virtualDaaScore {
  
  return $DaaScoreCopyWith<$Res>(_self.virtualDaaScore, (value) {
    return _then(_self.copyWith(virtualDaaScore: value));
  });
}/// Create a copy of DagState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DagBlockCopyWith<$Res>? get virtualBlock {
    if (_self.virtualBlock == null) {
    return null;
  }

  return $DagBlockCopyWith<$Res>(_self.virtualBlock!, (value) {
    return _then(_self.copyWith(virtualBlock: value));
  });
}
}

// dart format on
