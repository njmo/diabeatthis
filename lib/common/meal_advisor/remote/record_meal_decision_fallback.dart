import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/database_impl.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../meal_decision_answer.dart';
import 'accept_remote_meal_decision.dart';
import 'meal_decision_remote_request.dart';

final recordMealDecisionFallbackProvider = Provider(
  (ref) => (MealDecisionRemoteRequest request, MealAdvice advice) async {
    final uid = ref.read(googleAccountProvider).asData?.value?.uid;
    if (uid != request.ownerUid ||
        ref.read(applicationDeviceModeProvider).asData?.value !=
            ApplicationDeviceMode.patient ||
        advice.decision == null) {
      return;
    }
    await storeMealDecisionFallback(
      ref.read(databaseProvider),
      uid!,
      request,
      advice,
    );
    await reconcileMealDecisionReceipts(ref);
  },
);

Future<void> storeMealDecisionFallback(
  DatabaseImpl db,
  String uid,
  MealDecisionRemoteRequest request,
  MealAdvice advice, {
  String? acceptanceToken,
}) async {
  final answer = MealDecisionAnswer.values
      .where((a) => a.decision == advice.decision)
      .first;
  await db.customStatement(
    'INSERT OR IGNORE INTO family_meal_decision_receipts(request_id,owner_uid,source_id,meal_id,acceptance_token,outcome_json,created_at) VALUES(?,?,?,?,?,?,?)',
    [
      request.id,
      uid,
      request.sourceId,
      request.mealId,
      acceptanceToken ?? '',
      jsonEncode({
        'source': advice.source == 'manual' ? 'manual' : 'mealAdvisor',
        'decision': answer.name,
        'minutes': answer.requiresMinutes
            ? advice.wait?.recommendedMinutes
            : null,
        'caregiverUid': null,
      }),
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
}
