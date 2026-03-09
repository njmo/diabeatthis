import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../features/meals/data/providers/meal_database_provider.dart';

part 'notification_action_handler_provider.g.dart';

@Riverpod(keepAlive: true)
class NotificationActionHandler extends _$NotificationActionHandler {
  @override
  void build() {}

  Future<void> handle(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;

    if (payload == null) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;

    final mealId = data['mealId'];
    if (mealId == null) return;

    if (kDebugMode) {
      print(
      "RECEIVED NOTIFICATION DATA: Meal ID: $mealId action_id ${actionId ?? 'null'}",
    );
    }
    if (actionId == 'meal_yes') {
      ref.read(updateMealByIdProvider(mealId, 'eating'));
    }
  }

  Future<void> handleBackground(NotificationResponse response) async {
    handle(response);
  }
}
