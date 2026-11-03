import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class MealCalculatorRequestStore {
  Future<List<Map<String, dynamic>>> read();
  Future<void> write(List<Map<String, dynamic>> requests);
}

class PreferencesMealCalculatorRequestStore
    implements MealCalculatorRequestStore {
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  static const key = 'meal_calculator_requests_v1';

  @override
  Future<List<Map<String, dynamic>>> read() async {
    final value = await preferences.getString(key);
    if (value == null) return const [];
    return (jsonDecode(value) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  @override
  Future<void> write(List<Map<String, dynamic>> requests) =>
      preferences.setString(key, jsonEncode(requests));
}

class MemoryMealCalculatorRequestStore implements MealCalculatorRequestStore {
  List<Map<String, dynamic>> requests = [];
  @override
  Future<List<Map<String, dynamic>>> read() async => requests;
  @override
  Future<void> write(List<Map<String, dynamic>> value) async {
    requests = value;
  }
}
