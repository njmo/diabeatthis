import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef MealWaitStatus = ({
  int mealId,
  DateTime startedAt,
  DateTime deadline,
  bool waitingForExtendedCarbs,
});

final mealWaitStatusProvider = FutureProvider<MealWaitStatus?>(
  (ref) => readMealWaitStatus(),
);

const _mealWaitStatusKey = 'foreground_meal_wait_status_v1';

Future<MealWaitStatus?> readMealWaitStatus() async {
  if (kIsWeb || !Platform.isAndroid) return null;
  final raw = await SharedPreferencesAsync().getString(_mealWaitStatusKey);
  if (raw == null) return null;
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return (
    mealId: data['mealId'] as int,
    startedAt: DateTime.fromMillisecondsSinceEpoch(data['startedAt'] as int),
    deadline: DateTime.fromMillisecondsSinceEpoch(data['deadline'] as int),
    waitingForExtendedCarbs: data['waitingForExtendedCarbs'] == true,
  );
}

Future<void> writeMealWaitStatus(MealWaitStatus? status) async {
  if (kIsWeb || !Platform.isAndroid) return;
  final preferences = SharedPreferencesAsync();
  if (status == null) {
    await preferences.remove(_mealWaitStatusKey);
    return;
  }
  await preferences.setString(
    _mealWaitStatusKey,
    jsonEncode({
      'mealId': status.mealId,
      'startedAt': status.startedAt.millisecondsSinceEpoch,
      'deadline': status.deadline.millisecondsSinceEpoch,
      'waitingForExtendedCarbs': status.waitingForExtendedCarbs,
    }),
  );
}
