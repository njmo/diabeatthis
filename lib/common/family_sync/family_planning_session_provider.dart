import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/drift/providers/database_provider.dart';
import '../family/family_providers.dart';
import '../meal_advisor/meal_decision_timing.dart';
import 'family_plan_submission_store.dart';
import 'family_planning_controller.dart';

typedef FamilyPlanningSession = ({
  String? uid,
  bool home,
  int? mealId,
  bool context,
});

/// Each view owns its completeness and watermark. A partial snapshot never
/// advances the cursor of the full mirror used by planning editors.
final familyPlanningSessionProvider = Provider.autoDispose
    .family<FamilyPlanningController, FamilyPlanningSession>(
      (ref, session) => _createSession(ref, session),
    );

final familyMealHistorySessionProvider = Provider.autoDispose
    .family<FamilyPlanningController, String?>((ref, uid) {
      return _createSession(ref, (
        uid: uid,
        home: false,
        mealId: null,
        context: false,
      ), mealHistory: true);
    });

final familyMealProgressSessionProvider = Provider.autoDispose
    .family<FamilyPlanningController, ({String uid, int mealId})>((ref, key) {
      return _createSession(ref, (
        uid: key.uid,
        home: false,
        mealId: key.mealId,
        context: false,
      ), mealProgress: true);
    });

FamilyPlanningController _createSession(
  Ref ref,
  FamilyPlanningSession session, {
  bool mealHistory = false,
  bool mealProgress = false,
}) {
  final (:uid, :home, :mealId, :context) = session;
  final controller = FamilyPlanningController(
    ref.watch(authenticatedFamilyTransportProvider),
    () {
      if (uid == null || Firebase.apps.isEmpty) return null;
      final current = FirebaseAuth.instance.currentUser?.uid;
      return current == uid ? current : null;
    },
    FamilyPlanSubmissionStore.lazy(() => ref.read(databaseProvider)),
    mealHistory: mealHistory,
    view: mealHistory
        ? () => {'view': 'history'}
        : home
        ? () {
            final now = DateTime.now();
            final start = DateTime(now.year, now.month, now.day);
            final end = DateTime(now.year, now.month, now.day + 1);
            return {
              'view': 'home',
              'date': DateFormat('yyyy-MM-dd', 'en').format(start),
              'startMs': start.millisecondsSinceEpoch,
              'endMs': end.millisecondsSinceEpoch,
            };
          }
        : mealId != null
        ? () => {
            'view': mealProgress ? 'mealProgress' : 'meal',
            'mealId': mealId,
            'context': context,
          }
        : null,
  );
  ref.onDispose(controller.dispose);
  unawaited(
    Future<void>.microtask(() async {
      if (uid == null || controller.disposed) return;
      await timeMealDecision(
        home ? 'caregiver.family.home' : 'caregiver.family.load',
        () => controller.refreshAndWait(
          timing: (phase, elapsed) {
            mealDecisionTiming(
              'caregiver.family.startup.$phase',
              elapsedMs: elapsed,
            );
          },
        ),
      );
    }),
  );
  return controller;
}
