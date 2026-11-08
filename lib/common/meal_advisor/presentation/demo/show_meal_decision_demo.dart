import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family_sync/family_access_scope.dart';
import '../../../family_sync/presentation/family_scope_guard.dart';
import '../../../l10n/language.dart';
import '../../demo/meal_decision_demo_controller.dart';
import 'caregiver_meal_decision_demo_sheet.dart';
import 'child_meal_decision_demo_sheet.dart';

Future<void> showChildMealDecisionDemo(
  BuildContext context, {
  required String requestKey,
  required String mealName,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  enableDrag: false,
  isDismissible: false,
  backgroundColor: Colors.transparent,
  builder: (_) =>
      ChildMealDecisionDemoSheet(requestKey: requestKey, mealName: mealName),
);

Future<void> showCaregiverMealDecisionDemo(
  BuildContext context, {
  required String requestKey,
  required String requestId,
  required String caregiverName,
  String caregiverId = 'demo-caregiver',
  FamilyAccessScope? familyScope,
}) async {
  final controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(mealDecisionDemoControllerProvider.notifier);
  final request = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(mealDecisionDemoControllerProvider)[requestKey];
  if (familyScope != null &&
      request?.mealId != null &&
      !request!.matchesFamily(familyScope.owner, familyScope.source)) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(context.lang.mealDecisionDemoStale),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).closeButtonLabel,
            ),
          ),
        ],
      ),
    );
    return;
  }
  controller.expireRequest(requestKey, requestId);
  try {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final sheet = CaregiverMealDecisionDemoSheet(
          requestKey: requestKey,
          requestId: requestId,
          caregiverName: caregiverName,
          caregiverId: caregiverId,
          familyScope: familyScope,
        );
        return familyScope == null
            ? sheet
            : FamilyScopeGuard(scope: familyScope, child: sheet);
      },
    );
  } finally {
    controller.updateCaregiverContext(
      requestKey,
      requestId,
      caregiverId,
      present: false,
    );
  }
}
