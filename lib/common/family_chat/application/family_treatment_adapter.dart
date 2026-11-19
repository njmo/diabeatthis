import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../../core/domain/model/low_treatment_context.dart';
import '../../../core/domain/model/meal.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../features/ingredients/data/drafts/ingredient_draft.dart';
import '../../../features/ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../features/low_treatment/application/save_recorded_low_treatment_use_case.dart';
import '../../../features/low_treatment/data/drafts/low_treatment_context_draft.dart';
import '../../../features/low_treatment/data/repositories/family_treatment_journal.dart';
import '../../../features/meals/data/drafts/meal_draft.dart';
import '../../../features/portions/data/drafts/portion_draft.dart';
import '../../app_mode/application_device_mode.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_notification_platform.dart';
import '../data/family_chat_remote.dart';
import '../domain/family_treatment_authorization.dart';
import '../domain/family_treatment_carbs.dart';
import 'confirm_family_treatment.dart';
import 'family_chat_background.dart';
import 'family_chat_session.dart';

final familyTreatmentExecutorProvider = Provider.autoDispose
    .family<ConfirmFamilyTreatment, FamilyChatSession>((ref, session) {
      final scope = session.scope;
      return createFamilyTreatmentExecutor(
        ref,
        chatDb: session.db,
        api: session.api,
        currentUid: () => Firebase.apps.isEmpty
            ? null
            : FirebaseAuth.instance.currentUser?.uid,
        admitted: () =>
            scope != null &&
            session.active &&
            session.enabled &&
            session.scope == scope,
      );
    });

/// Both foreground and notification isolates use their one clinical connection
/// for the journal, clinical save, handoff and upload enqueue transaction.
ConfirmFamilyTreatment createFamilyTreatmentExecutor(
  Ref ref, {
  required FamilyChatDatabase chatDb,
  required FamilyChatApi api,
  required String? Function() currentUid,
  bool Function()? admitted,
  Map<String, dynamic>? expectedGuard,
  FamilyTreatmentAuthorization? Function()? observedAuthorization,
}) {
  final medical = ref.watch(databaseProvider);
  final save = ref.watch(saveRecordedLowTreatmentUseCaseProvider);
  return ConfirmFamilyTreatment(
    chatDb: chatDb,
    journal: FamilyTreatmentJournal(medical),
    api: api,
    currentUid: currentUid,
    observedAuthorization: observedAuthorization,
    onPrepared: (id, guard) async {
      final notice = familyChatNotice(guard['scope'] as String, id);
      await chatDb.withChatGuard(
        guard,
        () => chatDb.rememberNotification(
          guard['scope'] as String,
          notice.id,
          guard['stamp'] as String,
          tag: notice.tag,
        ),
      );
      await FamilyChatNotificationPlatform.cancel(chatDb, [
        notice,
      ], keepTrying: () => false);
    },
    clinicalAuthorized: (uid) async {
      final prefs = await ref.read(sharedPrefsProvider.future);
      await prefs.reload();
      if (expectedGuard != null) {
        final guard = await chatDb.activeChat();
        if (guard['enabled'] != true ||
            [
              'uid',
              'scope',
              'stamp',
            ].any((key) => guard[key] != expectedGuard[key])) {
          return false;
        }
      }
      if (!ref.mounted ||
          admitted?.call() == false ||
          currentUid() != uid ||
          !hasInitialConfiguration(prefs) ||
          deviceModeFromPreferences(prefs) != ApplicationDeviceMode.patient) {
        return false;
      }
      final identity = await medical
          .customSelect(
            'SELECT owner_uid FROM family_sync_identity WHERE singleton=1',
          )
          .getSingleOrNull();
      return currentUid() == uid &&
          admitted?.call() != false &&
          identity?.readNullable<String>('owner_uid') == uid;
    },
    save: (snapshot, confirmedAt) async {
      if (confirmedAt == null) {
        throw StateError('Confirm the consumption time again');
      }
      final sourcePerUnit = (snapshot['carbsPerUnit'] as num).toDouble();
      final nutrition = familyTreatmentNutritionCarbs(
        (snapshot['quantity'] as num).toDouble() * sourcePerUnit,
      );
      final delivery = familyTreatmentRecordedCarbs(nutrition);
      if (snapshot['carbs'] != nutrition ||
          snapshot['deliveryCarbs'] != delivery) {
        throw StateError(
          'Server carbohydrate record does not match the frozen conversion',
        );
      }
      final result = await save(
        familyTreatmentDraft(
          snapshot,
          DateTime.fromMillisecondsSinceEpoch(confirmedAt),
        ),
        eatenAt: DateTime.fromMillisecondsSinceEpoch(confirmedAt),
        logContent: false,
        suggestMissingIcons: false,
        carbohydrateRecord: (nutrition: nutrition, delivery: delivery),
      );
      return result.context.mealId;
    },
  );
}

LowTreatmentContextDraft familyTreatmentDraft(
  Map<String, dynamic> snapshot,
  DateTime confirmedAt,
) {
  final reference = snapshot['unit'] == 'portion';
  final carbs = (snapshot[reference ? 'carbsPerUnit' : 'carbsPer100g'] as num)
      .toDouble();
  final amount = (snapshot[reference ? 'quantity' : 'grams'] as num).toDouble();
  if (!carbs.isFinite ||
      carbs <= 0 ||
      carbs > 100 ||
      !amount.isFinite ||
      amount <= 0) {
    throw StateError('Invalid frozen treatment conversion');
  }
  return LowTreatmentContextDraft(
    source: LowTreatmentContextSource.familyChat,
    reason: LowTreatmentReason.manual,
    meal: MealDraft(
      name: '',
      plannedAt: confirmedAt,
      purpose: MealPurpose.lowTreatment,
      status: 'confirmed',
      mealIngredients: [
        MealIngredientsDraft(
          ingredient: IngredientDraft.draft(
            name: snapshot['foodName'] as String,
            carbsPer100g: carbs,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
            isReference: reference,
          ),
          ingredientPortion: const IngredientPortionDraft(
            portion: PortionSelection.empty(),
            amount: 1,
          ),
          amount: amount,
          quantityConfidence: 1,
          entryType: 'planned',
          consumedAmount: null,
          consumedConfidence: null,
        ),
      ],
    ),
  );
}
