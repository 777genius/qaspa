// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dag_info_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DagInfoDto {

@JsonKey(name: 'tip_hashes') List<String> get tipHashes;@JsonKey(name: 'sink_hash') String get sinkHash;@JsonKey(name: 'pruning_point_hash') String get pruningPointHash;@JsonKey(name: 'virtual_daa_score') int get virtualDaaScore;@JsonKey(name: 'block_count') int get blockCount; double get difficulty;@JsonKey(name: 'past_median_time') int? get pastMedianTime;@JsonKey(name: 'virtual_parent_hashes') List<String> get virtualParentHashes;
/// Create a copy of DagInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DagInfoDtoCopyWith<DagInfoDto> get copyWith => _$DagInfoDtoCopyWithImpl<DagInfoDto>(this as DagInfoDto, _$identity);

  /// Serializes this DagInfoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DagInfoDto&&const DeepCollectionEquality().equals(other.tipHashes, tipHashes)&&(identical(other.sinkHash, sinkHash) || other.sinkHash == sinkHash)&&(identical(other.pruningPointHash, pruningPointHash) || other.pruningPointHash == pruningPointHash)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.blockCount, blockCount) || other.blockCount == blockCount)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&(identical(other.pastMedianTime, pastMedianTime) || other.pastMedianTime == pastMedianTime)&&const DeepCollectionEquality().equals(other.virtualParentHashes, virtualParentHashes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tipHashes),sinkHash,pruningPointHash,virtualDaaScore,blockCount,difficulty,pastMedianTime,const DeepCollectionEquality().hash(virtualParentHashes));

@override
String toString() {
  return 'DagInfoDto(tipHashes: $tipHashes, sinkHash: $sinkHash, pruningPointHash: $pruningPointHash, virtualDaaScore: $virtualDaaScore, blockCount: $blockCount, difficulty: $difficulty, pastMedianTime: $pastMedianTime, virtualParentHashes: $virtualParentHashes)';
}


}

/// @nodoc
abstract mixin class $DagInfoDtoCopyWith<$Res>  {
  factory $DagInfoDtoCopyWith(DagInfoDto value, $Res Function(DagInfoDto) _then) = _$DagInfoDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'tip_hashes') List<String> tipHashes,@JsonKey(name: 'sink_hash') String sinkHash,@JsonKey(name: 'pruning_point_hash') String pruningPointHash,@JsonKey(name: 'virtual_daa_score') int virtualDaaScore,@JsonKey(name: 'block_count') int blockCount, double difficulty,@JsonKey(name: 'past_median_time') int? pastMedianTime,@JsonKey(name: 'virtual_parent_hashes') List<String> virtualParentHashes
});




}
/// @nodoc
class _$DagInfoDtoCopyWithImpl<$Res>
    implements $DagInfoDtoCopyWith<$Res> {
  _$DagInfoDtoCopyWithImpl(this._self, this._then);

  final DagInfoDto _self;
  final $Res Function(DagInfoDto) _then;

/// Create a copy of DagInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tipHashes = null,Object? sinkHash = null,Object? pruningPointHash = null,Object? virtualDaaScore = null,Object? blockCount = null,Object? difficulty = null,Object? pastMedianTime = freezed,Object? virtualParentHashes = null,}) {
  return _then(_self.copyWith(
tipHashes: null == tipHashes ? _self.tipHashes : tipHashes // ignore: cast_nullable_to_non_nullable
as List<String>,sinkHash: null == sinkHash ? _self.sinkHash : sinkHash // ignore: cast_nullable_to_non_nullable
as String,pruningPointHash: null == pruningPointHash ? _self.pruningPointHash : pruningPointHash // ignore: cast_nullable_to_non_nullable
as String,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,blockCount: null == blockCount ? _self.blockCount : blockCount // ignore: cast_nullable_to_non_nullable
as int,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,pastMedianTime: freezed == pastMedianTime ? _self.pastMedianTime : pastMedianTime // ignore: cast_nullable_to_non_nullable
as int?,virtualParentHashes: null == virtualParentHashes ? _self.virtualParentHashes : virtualParentHashes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [DagInfoDto].
extension DagInfoDtoPatterns on DagInfoDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DagInfoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DagInfoDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DagInfoDto value)  $default,){
final _that = this;
switch (_that) {
case _DagInfoDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DagInfoDto value)?  $default,){
final _that = this;
switch (_that) {
case _DagInfoDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'tip_hashes')  List<String> tipHashes, @JsonKey(name: 'sink_hash')  String sinkHash, @JsonKey(name: 'pruning_point_hash')  String pruningPointHash, @JsonKey(name: 'virtual_daa_score')  int virtualDaaScore, @JsonKey(name: 'block_count')  int blockCount,  double difficulty, @JsonKey(name: 'past_median_time')  int? pastMedianTime, @JsonKey(name: 'virtual_parent_hashes')  List<String> virtualParentHashes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DagInfoDto() when $default != null:
return $default(_that.tipHashes,_that.sinkHash,_that.pruningPointHash,_that.virtualDaaScore,_that.blockCount,_that.difficulty,_that.pastMedianTime,_that.virtualParentHashes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'tip_hashes')  List<String> tipHashes, @JsonKey(name: 'sink_hash')  String sinkHash, @JsonKey(name: 'pruning_point_hash')  String pruningPointHash, @JsonKey(name: 'virtual_daa_score')  int virtualDaaScore, @JsonKey(name: 'block_count')  int blockCount,  double difficulty, @JsonKey(name: 'past_median_time')  int? pastMedianTime, @JsonKey(name: 'virtual_parent_hashes')  List<String> virtualParentHashes)  $default,) {final _that = this;
switch (_that) {
case _DagInfoDto():
return $default(_that.tipHashes,_that.sinkHash,_that.pruningPointHash,_that.virtualDaaScore,_that.blockCount,_that.difficulty,_that.pastMedianTime,_that.virtualParentHashes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'tip_hashes')  List<String> tipHashes, @JsonKey(name: 'sink_hash')  String sinkHash, @JsonKey(name: 'pruning_point_hash')  String pruningPointHash, @JsonKey(name: 'virtual_daa_score')  int virtualDaaScore, @JsonKey(name: 'block_count')  int blockCount,  double difficulty, @JsonKey(name: 'past_median_time')  int? pastMedianTime, @JsonKey(name: 'virtual_parent_hashes')  List<String> virtualParentHashes)?  $default,) {final _that = this;
switch (_that) {
case _DagInfoDto() when $default != null:
return $default(_that.tipHashes,_that.sinkHash,_that.pruningPointHash,_that.virtualDaaScore,_that.blockCount,_that.difficulty,_that.pastMedianTime,_that.virtualParentHashes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DagInfoDto extends DagInfoDto {
  const _DagInfoDto({@JsonKey(name: 'tip_hashes') required final  List<String> tipHashes, @JsonKey(name: 'sink_hash') required this.sinkHash, @JsonKey(name: 'pruning_point_hash') required this.pruningPointHash, @JsonKey(name: 'virtual_daa_score') required this.virtualDaaScore, @JsonKey(name: 'block_count') required this.blockCount, required this.difficulty, @JsonKey(name: 'past_median_time') this.pastMedianTime, @JsonKey(name: 'virtual_parent_hashes') final  List<String> virtualParentHashes = const []}): _tipHashes = tipHashes,_virtualParentHashes = virtualParentHashes,super._();
  factory _DagInfoDto.fromJson(Map<String, dynamic> json) => _$DagInfoDtoFromJson(json);

 final  List<String> _tipHashes;
@override@JsonKey(name: 'tip_hashes') List<String> get tipHashes {
  if (_tipHashes is EqualUnmodifiableListView) return _tipHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tipHashes);
}

@override@JsonKey(name: 'sink_hash') final  String sinkHash;
@override@JsonKey(name: 'pruning_point_hash') final  String pruningPointHash;
@override@JsonKey(name: 'virtual_daa_score') final  int virtualDaaScore;
@override@JsonKey(name: 'block_count') final  int blockCount;
@override final  double difficulty;
@override@JsonKey(name: 'past_median_time') final  int? pastMedianTime;
 final  List<String> _virtualParentHashes;
@override@JsonKey(name: 'virtual_parent_hashes') List<String> get virtualParentHashes {
  if (_virtualParentHashes is EqualUnmodifiableListView) return _virtualParentHashes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_virtualParentHashes);
}


/// Create a copy of DagInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DagInfoDtoCopyWith<_DagInfoDto> get copyWith => __$DagInfoDtoCopyWithImpl<_DagInfoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DagInfoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DagInfoDto&&const DeepCollectionEquality().equals(other._tipHashes, _tipHashes)&&(identical(other.sinkHash, sinkHash) || other.sinkHash == sinkHash)&&(identical(other.pruningPointHash, pruningPointHash) || other.pruningPointHash == pruningPointHash)&&(identical(other.virtualDaaScore, virtualDaaScore) || other.virtualDaaScore == virtualDaaScore)&&(identical(other.blockCount, blockCount) || other.blockCount == blockCount)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&(identical(other.pastMedianTime, pastMedianTime) || other.pastMedianTime == pastMedianTime)&&const DeepCollectionEquality().equals(other._virtualParentHashes, _virtualParentHashes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_tipHashes),sinkHash,pruningPointHash,virtualDaaScore,blockCount,difficulty,pastMedianTime,const DeepCollectionEquality().hash(_virtualParentHashes));

@override
String toString() {
  return 'DagInfoDto(tipHashes: $tipHashes, sinkHash: $sinkHash, pruningPointHash: $pruningPointHash, virtualDaaScore: $virtualDaaScore, blockCount: $blockCount, difficulty: $difficulty, pastMedianTime: $pastMedianTime, virtualParentHashes: $virtualParentHashes)';
}


}

/// @nodoc
abstract mixin class _$DagInfoDtoCopyWith<$Res> implements $DagInfoDtoCopyWith<$Res> {
  factory _$DagInfoDtoCopyWith(_DagInfoDto value, $Res Function(_DagInfoDto) _then) = __$DagInfoDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'tip_hashes') List<String> tipHashes,@JsonKey(name: 'sink_hash') String sinkHash,@JsonKey(name: 'pruning_point_hash') String pruningPointHash,@JsonKey(name: 'virtual_daa_score') int virtualDaaScore,@JsonKey(name: 'block_count') int blockCount, double difficulty,@JsonKey(name: 'past_median_time') int? pastMedianTime,@JsonKey(name: 'virtual_parent_hashes') List<String> virtualParentHashes
});




}
/// @nodoc
class __$DagInfoDtoCopyWithImpl<$Res>
    implements _$DagInfoDtoCopyWith<$Res> {
  __$DagInfoDtoCopyWithImpl(this._self, this._then);

  final _DagInfoDto _self;
  final $Res Function(_DagInfoDto) _then;

/// Create a copy of DagInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tipHashes = null,Object? sinkHash = null,Object? pruningPointHash = null,Object? virtualDaaScore = null,Object? blockCount = null,Object? difficulty = null,Object? pastMedianTime = freezed,Object? virtualParentHashes = null,}) {
  return _then(_DagInfoDto(
tipHashes: null == tipHashes ? _self._tipHashes : tipHashes // ignore: cast_nullable_to_non_nullable
as List<String>,sinkHash: null == sinkHash ? _self.sinkHash : sinkHash // ignore: cast_nullable_to_non_nullable
as String,pruningPointHash: null == pruningPointHash ? _self.pruningPointHash : pruningPointHash // ignore: cast_nullable_to_non_nullable
as String,virtualDaaScore: null == virtualDaaScore ? _self.virtualDaaScore : virtualDaaScore // ignore: cast_nullable_to_non_nullable
as int,blockCount: null == blockCount ? _self.blockCount : blockCount // ignore: cast_nullable_to_non_nullable
as int,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,pastMedianTime: freezed == pastMedianTime ? _self.pastMedianTime : pastMedianTime // ignore: cast_nullable_to_non_nullable
as int?,virtualParentHashes: null == virtualParentHashes ? _self._virtualParentHashes : virtualParentHashes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
