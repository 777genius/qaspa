// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'log_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LogEntry {

 String get message;@JsonKey(fromJson: _parseTimestamp) DateTime get timestamp; LogLevel get level; String? get containerId; String? get containerName;
/// Create a copy of LogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LogEntryCopyWith<LogEntry> get copyWith => _$LogEntryCopyWithImpl<LogEntry>(this as LogEntry, _$identity);

  /// Serializes this LogEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LogEntry&&(identical(other.message, message) || other.message == message)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.level, level) || other.level == level)&&(identical(other.containerId, containerId) || other.containerId == containerId)&&(identical(other.containerName, containerName) || other.containerName == containerName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,timestamp,level,containerId,containerName);

@override
String toString() {
  return 'LogEntry(message: $message, timestamp: $timestamp, level: $level, containerId: $containerId, containerName: $containerName)';
}


}

/// @nodoc
abstract mixin class $LogEntryCopyWith<$Res>  {
  factory $LogEntryCopyWith(LogEntry value, $Res Function(LogEntry) _then) = _$LogEntryCopyWithImpl;
@useResult
$Res call({
 String message,@JsonKey(fromJson: _parseTimestamp) DateTime timestamp, LogLevel level, String? containerId, String? containerName
});




}
/// @nodoc
class _$LogEntryCopyWithImpl<$Res>
    implements $LogEntryCopyWith<$Res> {
  _$LogEntryCopyWithImpl(this._self, this._then);

  final LogEntry _self;
  final $Res Function(LogEntry) _then;

/// Create a copy of LogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? timestamp = null,Object? level = null,Object? containerId = freezed,Object? containerName = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as LogLevel,containerId: freezed == containerId ? _self.containerId : containerId // ignore: cast_nullable_to_non_nullable
as String?,containerName: freezed == containerName ? _self.containerName : containerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LogEntry].
extension LogEntryPatterns on LogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LogEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LogEntry value)  $default,){
final _that = this;
switch (_that) {
case _LogEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _LogEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message, @JsonKey(fromJson: _parseTimestamp)  DateTime timestamp,  LogLevel level,  String? containerId,  String? containerName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LogEntry() when $default != null:
return $default(_that.message,_that.timestamp,_that.level,_that.containerId,_that.containerName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message, @JsonKey(fromJson: _parseTimestamp)  DateTime timestamp,  LogLevel level,  String? containerId,  String? containerName)  $default,) {final _that = this;
switch (_that) {
case _LogEntry():
return $default(_that.message,_that.timestamp,_that.level,_that.containerId,_that.containerName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message, @JsonKey(fromJson: _parseTimestamp)  DateTime timestamp,  LogLevel level,  String? containerId,  String? containerName)?  $default,) {final _that = this;
switch (_that) {
case _LogEntry() when $default != null:
return $default(_that.message,_that.timestamp,_that.level,_that.containerId,_that.containerName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LogEntry extends LogEntry {
  const _LogEntry({required this.message, @JsonKey(fromJson: _parseTimestamp) required this.timestamp, this.level = LogLevel.info, this.containerId, this.containerName}): super._();
  factory _LogEntry.fromJson(Map<String, dynamic> json) => _$LogEntryFromJson(json);

@override final  String message;
@override@JsonKey(fromJson: _parseTimestamp) final  DateTime timestamp;
@override@JsonKey() final  LogLevel level;
@override final  String? containerId;
@override final  String? containerName;

/// Create a copy of LogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LogEntryCopyWith<_LogEntry> get copyWith => __$LogEntryCopyWithImpl<_LogEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LogEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LogEntry&&(identical(other.message, message) || other.message == message)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.level, level) || other.level == level)&&(identical(other.containerId, containerId) || other.containerId == containerId)&&(identical(other.containerName, containerName) || other.containerName == containerName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,timestamp,level,containerId,containerName);

@override
String toString() {
  return 'LogEntry(message: $message, timestamp: $timestamp, level: $level, containerId: $containerId, containerName: $containerName)';
}


}

/// @nodoc
abstract mixin class _$LogEntryCopyWith<$Res> implements $LogEntryCopyWith<$Res> {
  factory _$LogEntryCopyWith(_LogEntry value, $Res Function(_LogEntry) _then) = __$LogEntryCopyWithImpl;
@override @useResult
$Res call({
 String message,@JsonKey(fromJson: _parseTimestamp) DateTime timestamp, LogLevel level, String? containerId, String? containerName
});




}
/// @nodoc
class __$LogEntryCopyWithImpl<$Res>
    implements _$LogEntryCopyWith<$Res> {
  __$LogEntryCopyWithImpl(this._self, this._then);

  final _LogEntry _self;
  final $Res Function(_LogEntry) _then;

/// Create a copy of LogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? timestamp = null,Object? level = null,Object? containerId = freezed,Object? containerName = freezed,}) {
  return _then(_LogEntry(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as LogLevel,containerId: freezed == containerId ? _self.containerId : containerId // ignore: cast_nullable_to_non_nullable
as String?,containerName: freezed == containerName ? _self.containerName : containerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
