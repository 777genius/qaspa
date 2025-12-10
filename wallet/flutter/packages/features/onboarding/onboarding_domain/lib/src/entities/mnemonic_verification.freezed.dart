// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mnemonic_verification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VerificationChallenge {

/// The position of the word in the mnemonic (1-based)
 int get wordIndex;/// The correct word that should be selected
 String get correctWord;/// The list of options to choose from (includes correctWord)
 List<String> get options;
/// Create a copy of VerificationChallenge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerificationChallengeCopyWith<VerificationChallenge> get copyWith => _$VerificationChallengeCopyWithImpl<VerificationChallenge>(this as VerificationChallenge, _$identity);

  /// Serializes this VerificationChallenge to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerificationChallenge&&(identical(other.wordIndex, wordIndex) || other.wordIndex == wordIndex)&&(identical(other.correctWord, correctWord) || other.correctWord == correctWord)&&const DeepCollectionEquality().equals(other.options, options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,wordIndex,correctWord,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'VerificationChallenge(wordIndex: $wordIndex, correctWord: $correctWord, options: $options)';
}


}

/// @nodoc
abstract mixin class $VerificationChallengeCopyWith<$Res>  {
  factory $VerificationChallengeCopyWith(VerificationChallenge value, $Res Function(VerificationChallenge) _then) = _$VerificationChallengeCopyWithImpl;
@useResult
$Res call({
 int wordIndex, String correctWord, List<String> options
});




}
/// @nodoc
class _$VerificationChallengeCopyWithImpl<$Res>
    implements $VerificationChallengeCopyWith<$Res> {
  _$VerificationChallengeCopyWithImpl(this._self, this._then);

  final VerificationChallenge _self;
  final $Res Function(VerificationChallenge) _then;

/// Create a copy of VerificationChallenge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? wordIndex = null,Object? correctWord = null,Object? options = null,}) {
  return _then(_self.copyWith(
wordIndex: null == wordIndex ? _self.wordIndex : wordIndex // ignore: cast_nullable_to_non_nullable
as int,correctWord: null == correctWord ? _self.correctWord : correctWord // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [VerificationChallenge].
extension VerificationChallengePatterns on VerificationChallenge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerificationChallenge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerificationChallenge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerificationChallenge value)  $default,){
final _that = this;
switch (_that) {
case _VerificationChallenge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerificationChallenge value)?  $default,){
final _that = this;
switch (_that) {
case _VerificationChallenge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int wordIndex,  String correctWord,  List<String> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerificationChallenge() when $default != null:
return $default(_that.wordIndex,_that.correctWord,_that.options);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int wordIndex,  String correctWord,  List<String> options)  $default,) {final _that = this;
switch (_that) {
case _VerificationChallenge():
return $default(_that.wordIndex,_that.correctWord,_that.options);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int wordIndex,  String correctWord,  List<String> options)?  $default,) {final _that = this;
switch (_that) {
case _VerificationChallenge() when $default != null:
return $default(_that.wordIndex,_that.correctWord,_that.options);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VerificationChallenge extends VerificationChallenge {
  const _VerificationChallenge({required this.wordIndex, required this.correctWord, required final  List<String> options}): _options = options,super._();
  factory _VerificationChallenge.fromJson(Map<String, dynamic> json) => _$VerificationChallengeFromJson(json);

/// The position of the word in the mnemonic (1-based)
@override final  int wordIndex;
/// The correct word that should be selected
@override final  String correctWord;
/// The list of options to choose from (includes correctWord)
 final  List<String> _options;
/// The list of options to choose from (includes correctWord)
@override List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of VerificationChallenge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerificationChallengeCopyWith<_VerificationChallenge> get copyWith => __$VerificationChallengeCopyWithImpl<_VerificationChallenge>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerificationChallengeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerificationChallenge&&(identical(other.wordIndex, wordIndex) || other.wordIndex == wordIndex)&&(identical(other.correctWord, correctWord) || other.correctWord == correctWord)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,wordIndex,correctWord,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'VerificationChallenge(wordIndex: $wordIndex, correctWord: $correctWord, options: $options)';
}


}

/// @nodoc
abstract mixin class _$VerificationChallengeCopyWith<$Res> implements $VerificationChallengeCopyWith<$Res> {
  factory _$VerificationChallengeCopyWith(_VerificationChallenge value, $Res Function(_VerificationChallenge) _then) = __$VerificationChallengeCopyWithImpl;
@override @useResult
$Res call({
 int wordIndex, String correctWord, List<String> options
});




}
/// @nodoc
class __$VerificationChallengeCopyWithImpl<$Res>
    implements _$VerificationChallengeCopyWith<$Res> {
  __$VerificationChallengeCopyWithImpl(this._self, this._then);

  final _VerificationChallenge _self;
  final $Res Function(_VerificationChallenge) _then;

/// Create a copy of VerificationChallenge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? wordIndex = null,Object? correctWord = null,Object? options = null,}) {
  return _then(_VerificationChallenge(
wordIndex: null == wordIndex ? _self.wordIndex : wordIndex // ignore: cast_nullable_to_non_nullable
as int,correctWord: null == correctWord ? _self.correctWord : correctWord // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$MnemonicVerification {

/// List of verification challenges (typically 3)
 List<VerificationChallenge> get challenges;/// Index of the current challenge (0-based)
 int get currentChallengeIndex;/// List of user's answers (null if not answered yet)
 List<String?> get userAnswers;
/// Create a copy of MnemonicVerification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MnemonicVerificationCopyWith<MnemonicVerification> get copyWith => _$MnemonicVerificationCopyWithImpl<MnemonicVerification>(this as MnemonicVerification, _$identity);

  /// Serializes this MnemonicVerification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MnemonicVerification&&const DeepCollectionEquality().equals(other.challenges, challenges)&&(identical(other.currentChallengeIndex, currentChallengeIndex) || other.currentChallengeIndex == currentChallengeIndex)&&const DeepCollectionEquality().equals(other.userAnswers, userAnswers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(challenges),currentChallengeIndex,const DeepCollectionEquality().hash(userAnswers));

@override
String toString() {
  return 'MnemonicVerification(challenges: $challenges, currentChallengeIndex: $currentChallengeIndex, userAnswers: $userAnswers)';
}


}

/// @nodoc
abstract mixin class $MnemonicVerificationCopyWith<$Res>  {
  factory $MnemonicVerificationCopyWith(MnemonicVerification value, $Res Function(MnemonicVerification) _then) = _$MnemonicVerificationCopyWithImpl;
@useResult
$Res call({
 List<VerificationChallenge> challenges, int currentChallengeIndex, List<String?> userAnswers
});




}
/// @nodoc
class _$MnemonicVerificationCopyWithImpl<$Res>
    implements $MnemonicVerificationCopyWith<$Res> {
  _$MnemonicVerificationCopyWithImpl(this._self, this._then);

  final MnemonicVerification _self;
  final $Res Function(MnemonicVerification) _then;

/// Create a copy of MnemonicVerification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? challenges = null,Object? currentChallengeIndex = null,Object? userAnswers = null,}) {
  return _then(_self.copyWith(
challenges: null == challenges ? _self.challenges : challenges // ignore: cast_nullable_to_non_nullable
as List<VerificationChallenge>,currentChallengeIndex: null == currentChallengeIndex ? _self.currentChallengeIndex : currentChallengeIndex // ignore: cast_nullable_to_non_nullable
as int,userAnswers: null == userAnswers ? _self.userAnswers : userAnswers // ignore: cast_nullable_to_non_nullable
as List<String?>,
  ));
}

}


/// Adds pattern-matching-related methods to [MnemonicVerification].
extension MnemonicVerificationPatterns on MnemonicVerification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MnemonicVerification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MnemonicVerification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MnemonicVerification value)  $default,){
final _that = this;
switch (_that) {
case _MnemonicVerification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MnemonicVerification value)?  $default,){
final _that = this;
switch (_that) {
case _MnemonicVerification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VerificationChallenge> challenges,  int currentChallengeIndex,  List<String?> userAnswers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MnemonicVerification() when $default != null:
return $default(_that.challenges,_that.currentChallengeIndex,_that.userAnswers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VerificationChallenge> challenges,  int currentChallengeIndex,  List<String?> userAnswers)  $default,) {final _that = this;
switch (_that) {
case _MnemonicVerification():
return $default(_that.challenges,_that.currentChallengeIndex,_that.userAnswers);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VerificationChallenge> challenges,  int currentChallengeIndex,  List<String?> userAnswers)?  $default,) {final _that = this;
switch (_that) {
case _MnemonicVerification() when $default != null:
return $default(_that.challenges,_that.currentChallengeIndex,_that.userAnswers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MnemonicVerification extends MnemonicVerification {
  const _MnemonicVerification({required final  List<VerificationChallenge> challenges, this.currentChallengeIndex = 0, final  List<String?> userAnswers = const []}): _challenges = challenges,_userAnswers = userAnswers,super._();
  factory _MnemonicVerification.fromJson(Map<String, dynamic> json) => _$MnemonicVerificationFromJson(json);

/// List of verification challenges (typically 3)
 final  List<VerificationChallenge> _challenges;
/// List of verification challenges (typically 3)
@override List<VerificationChallenge> get challenges {
  if (_challenges is EqualUnmodifiableListView) return _challenges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_challenges);
}

/// Index of the current challenge (0-based)
@override@JsonKey() final  int currentChallengeIndex;
/// List of user's answers (null if not answered yet)
 final  List<String?> _userAnswers;
/// List of user's answers (null if not answered yet)
@override@JsonKey() List<String?> get userAnswers {
  if (_userAnswers is EqualUnmodifiableListView) return _userAnswers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_userAnswers);
}


/// Create a copy of MnemonicVerification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MnemonicVerificationCopyWith<_MnemonicVerification> get copyWith => __$MnemonicVerificationCopyWithImpl<_MnemonicVerification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MnemonicVerificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MnemonicVerification&&const DeepCollectionEquality().equals(other._challenges, _challenges)&&(identical(other.currentChallengeIndex, currentChallengeIndex) || other.currentChallengeIndex == currentChallengeIndex)&&const DeepCollectionEquality().equals(other._userAnswers, _userAnswers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_challenges),currentChallengeIndex,const DeepCollectionEquality().hash(_userAnswers));

@override
String toString() {
  return 'MnemonicVerification(challenges: $challenges, currentChallengeIndex: $currentChallengeIndex, userAnswers: $userAnswers)';
}


}

/// @nodoc
abstract mixin class _$MnemonicVerificationCopyWith<$Res> implements $MnemonicVerificationCopyWith<$Res> {
  factory _$MnemonicVerificationCopyWith(_MnemonicVerification value, $Res Function(_MnemonicVerification) _then) = __$MnemonicVerificationCopyWithImpl;
@override @useResult
$Res call({
 List<VerificationChallenge> challenges, int currentChallengeIndex, List<String?> userAnswers
});




}
/// @nodoc
class __$MnemonicVerificationCopyWithImpl<$Res>
    implements _$MnemonicVerificationCopyWith<$Res> {
  __$MnemonicVerificationCopyWithImpl(this._self, this._then);

  final _MnemonicVerification _self;
  final $Res Function(_MnemonicVerification) _then;

/// Create a copy of MnemonicVerification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? challenges = null,Object? currentChallengeIndex = null,Object? userAnswers = null,}) {
  return _then(_MnemonicVerification(
challenges: null == challenges ? _self._challenges : challenges // ignore: cast_nullable_to_non_nullable
as List<VerificationChallenge>,currentChallengeIndex: null == currentChallengeIndex ? _self.currentChallengeIndex : currentChallengeIndex // ignore: cast_nullable_to_non_nullable
as int,userAnswers: null == userAnswers ? _self._userAnswers : userAnswers // ignore: cast_nullable_to_non_nullable
as List<String?>,
  ));
}


}

// dart format on
