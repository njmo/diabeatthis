import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unimplemented reads fail through Fake instead of returning permissive defaults.
class ControlledPreferences extends Fake implements SharedPreferences {
  final Map<String, Object> values;
  final writes = <({String key, Object value})>[];
  bool acceptWrites = true;
  Object? writeError;
  ControlledPreferences([Map<String, Object>? values]) : values = {...?values};

  @override
  String? getString(String key) => values[key] as String?;
  @override
  int? getInt(String key) => values[key] as int?;
  @override
  bool? getBool(String key) => values[key] as bool?;

  Future<bool> store(String key, Object value) async {
    writes.add((key: key, value: value));
    if (writeError != null) throw writeError!;
    if (acceptWrites) values[key] = value;
    return acceptWrites;
  }

  @override
  Future<bool> setString(String key, String value) => store(key, value);
  @override
  Future<bool> setInt(String key, int value) => store(key, value);
  @override
  Future<bool> setBool(String key, bool value) => store(key, value);
}
