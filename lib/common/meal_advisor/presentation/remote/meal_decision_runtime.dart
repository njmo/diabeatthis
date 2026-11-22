import 'dart:async';

import 'package:clock/clock.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/providers/app_router_provider.dart';
import '../../../../core/data/provider/initial_configuration_provider.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../core/notifications/handlers/notification_response_handler.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../features/caregiver/data/caregiver_visible_state_provider.dart';
import '../../../../features/dashboard/data/providers/device_status_ui_provider.dart';
import '../../../../features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../../features/dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../../../features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import '../../../../features/meal_summary/domain/utils/meal_completion_amounts.dart';
import '../../../../features/meal_summary/presentation/controllers/meal_completion_controller.dart';
import '../../../../features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import '../../../../features/meal_summary/presentation/utils/meal_add_on_draft.dart';
import '../../../../features/meal_summary/presentation/utils/meal_completion_aaps_carbs.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../features/meals/presentation/widgets/meal_details/meal_detail_formatters.dart';
import '../../../app_mode/application_device_mode.dart';
import '../../../auth/google_authentication_providers.dart';
import '../../../family_sync/family_access_scope.dart';
import '../../../family_sync/family_planning_session_provider.dart';
import '../../../family_sync/presentation/models/family_meal_details.dart';
import '../../../family_sync/request_family_mirror_sync.dart';
import '../../../history/nightscout_history_repositories.dart';
import '../../../l10n/language.dart';
import '../../../meal/calculator/meal_calculator_request.dart';
import '../../../meal/calculator/meal_calculator_request_store.dart';
import '../../../meal/manual_meal_decision.dart';
import '../../../meal/meal_add_on_bolus_context.dart';
import '../../../meal/meal_display_name.dart';
import '../../../meal/meal_extended_carbs.dart';
import '../../../meal/meal_treatment_surplus.dart';
import '../../../monitoring/meal_wait_status.dart';
import '../../../meal/open_meal_completion.dart';
import '../../../meal/stored_meal_decision.dart';
import '../../../notifications/meal_notification_cancellation.dart';
import '../../../nutrition/stable_macro_ceil.dart';
import '../../context/caregiver_meal_context_history.dart';
import '../../context/meal_decision_activity_context.dart';
import '../../manual_meal_choice.dart';
import '../../meal_decision_answer.dart';
import '../../meal_decision_preferences.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../meal_decision_timing.dart';
import '../../notifications/meal_decision_notification_intent.dart';
import '../../notifications/meal_decision_notifications_runtime.dart';
import '../../notifications/meal_decision_push.dart';
import '../../remote/accept_remote_meal_decision.dart';
import '../../remote/capture_meal_advisor_suggestion.dart';
import '../../remote/caregiver_meal_decision_eligibility.dart';
import '../../remote/meal_decision_remote_controller.dart';
import '../../remote/meal_decision_remote_request.dart';
import '../../remote/meal_decision_request_creation.dart';
import '../../remote/scheduled_meal_decision_journal.dart';
import '../../remote/start_accepted_caregiver_meal.dart';
import '../../watch/caregiver_watch_meals.dart';
import '../../watch/meal_decision_watch_context.dart';
import '../../watch/meal_decision_watch_protocol.dart';
import '../../watch/watch_meal_progress.dart';
import '../meal_decision_default_minutes.dart';
import 'caregiver_meal_decision_sheet.dart';
import 'meal_decision_presentation_registry.dart';

/// UI lifecycle/push routing only; caregivers never need the patient foreground service.
class MealDecisionRuntime extends ConsumerStatefulWidget {
  const MealDecisionRuntime({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<MealDecisionRuntime> createState() =>
      MealDecisionRuntimeState();
}

class MealDecisionRuntimeState extends ConsumerState<MealDecisionRuntime>
    with WidgetsBindingObserver {
  static const _watchChannel = MethodChannel(
    MealDecisionWatchProtocol.channelName,
  );
  StreamSubscription<void>? intentSubscription;
  StreamSubscription<void>? presentationSubscription;
  Timer? receiptRetry;
  bool cleaningTimeouts = false;
  bool routing = false, replaying = false;
  bool drainAgain = false;
  final _notifiedChildAnswers = <(String, String)>{};
  final _presentedScheduledAnswers = <(String, String)>{};
  final presentedRequests = <String>{};
  final _watchClaims = <(String, String)>{};
  final _watchClaimEnds = <(String, String), int>{};
  ({String uid, DateTime at})? _lastWatchOverviewRefresh;
  bool _openingWatchMealSummary = false;
  final _watchMealCompletions = <int>{};
  String? presentedAccount;

  List<Object>? _watchInboxState(MealDecisionRemoteInbox? inbox) => inbox
      ?.requests
      .map(
        (request) => (
          request.id,
          request.mealName,
          request.status,
          request.stage,
          request.deadline,
          request.claimedByUid,
          request.claimedByName,
          request.data['claimUntil'],
          request.data['claimAvailable'],
          caregiverMealDecisionMemberStatus(request, inbox.accountUid),
        ),
      )
      .toList();

  Future<void> _notifyWatchInboxChanged({
    Set<String> added = const {},
    Set<String> removed = const {},
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _watchChannel.invokeMethod<void>('inboxChanged', {
        'added': added.toList(),
        'removed': removed.toList(),
      });
    } on MissingPluginException {
      // The Android adapter may not be attached yet.
    } on PlatformException {
      // Opening the watch app will read the inbox again.
    }
  }

  Set<String> _watchInvitationIds(MealDecisionRemoteInbox? inbox, String? uid) {
    if (inbox == null || inbox.accountUid != uid) return const {};
    return {
      for (final request in inbox.requests)
        if (request.claimAvailable &&
            caregiverCanOpenMealDecision(request, uid))
          request.id,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchChannel.setMethodCallHandler(_handleWatchCall);
    presentationSubscription = MealDecisionPresentationRegistry.changes.stream
        .listen((_) => unawaited(drain()));
    intentSubscription = MealDecisionNotificationIntentStore.changes.stream
        .listen((_) => unawaited(drain()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(drain());
      unawaited(cleanTimeoutNotifications());
      unawaited(_resumeWatchMealSummary());
    });
    receiptRetry = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(cleanTimeoutNotifications());
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(replayReceipts());
      }
    });
  }

  Future<void> cleanTimeoutNotifications() async {
    if (!mounted || cleaningTimeouts || Firebase.apps.isEmpty) return;
    final account = ref.read(googleAccountProvider).asData;
    final prefsReady = ref.read(sharedPrefsProvider).asData != null;
    if (account == null || !prefsReady) return;
    final preferences = ref.read(mealDecisionPreferencesProvider);
    cleaningTimeouts = true;
    try {
      await ScheduledMealDecisionJournal(
        ref.read(databaseProvider),
      ).cleanNotifications(
        uid: preferences.method == MealDecisionMethod.caregiver
            ? account.value?.uid
            : null,
        keepManualNotices:
            preferences.timeoutFallback == MealDecisionTimeoutFallback.manual &&
            preferences.allowManualDecision,
        now: clock.now(),
        cancel: (id) =>
            cancelScheduledMealDecisionFallback(id, throwOnFailure: true),
      );
    } catch (_) {
      // A failed Android cancellation stays in the journal for the next pass.
    } finally {
      cleaningTimeouts = false;
    }
  }

  bool get configured =>
      Firebase.apps.isNotEmpty &&
      ref.read(initialConfigurationDoneProvider).asData?.value == true &&
      ref.read(googleAccountProvider).asData?.value != null;

  MealDecisionWatchSession? _watchSession() {
    if (!mounted || !configured) return null;
    final mode = ref.read(applicationDeviceModeProvider).asData?.value;
    final uid = ref.read(googleAccountProvider).asData?.value?.uid;
    if (mode == null || uid == null) return null;
    return (
      uid: uid,
      mode: switch (mode) {
        ApplicationDeviceMode.patient => MealDecisionWatchMode.child,
        ApplicationDeviceMode.caregiver => MealDecisionWatchMode.caregiver,
      },
    );
  }

  Future<Object?> _handleWatchCall(MethodCall call) {
    if (call.method == 'phoneMealSummaryOpened') {
      unawaited(_resumeWatchMealSummary());
      return Future.value();
    }
    if (call.method != MealDecisionWatchProtocol.methodName) {
      throw MissingPluginException();
    }
    return MealDecisionWatchProtocol(
      session: _watchSession,
      loadPreview: _loadWatchPreview,
      claim: _claimFromWatch,
      claimOnPhone: _claimOnPhoneFromWatch,
      decline: _declineFromWatch,
      respond: _respondFromWatch,
      renewPresence: _renewWatchPresence,
      ownsClaim: _watchOwnsClaim,
      loadChildPlans: _loadChildWatchPlans,
      loadChildMealDetails: _loadChildWatchMealDetails,
      loadCaregiverMeals: _loadCaregiverWatchMeals,
      requestChildDecision: _requestChildWatchDecision,
      completeChildMeal: _completeChildWatchMeal,
      startChildMealAddOn: _startChildWatchMealAddOn,
      openPhoneMealSummary: _openChildWatchSummaryOnPhone,
      startMealOnPhone: (session, mealId) =>
          _openChildWatchSummaryOnPhone(session, mealId, start: true),
      startEatingAfterWait: (session, mealId) async {
        final meal = await ref
            .read(databaseProvider)
            .mealDao
            .getMealById(mealId);
        if (!mounted ||
            _watchSession() != session ||
            meal?.status != 'bolused-waiting') {
          return 'unavailable';
        }
        final wait = await readMealWaitStatus();
        if (_watchSession() != session ||
            (wait?.mealId == mealId && wait?.waitingForExtendedCarbs == true)) {
          return 'unavailable';
        }
        return await requestMealStartEating(mealId) ? 'ok' : 'unavailable';
      },
      skipChildMeal: _skipChildWatchMeal,
      startAcceptedMeal: (session, mealId) async {
        try {
          final started = await ref.read(startAcceptedCaregiverMealProvider)(
            session.uid,
            mealId,
            isCancelled: () => !mounted || _watchSession() != session,
          );
          return started ? 'ok' : 'unavailable';
        } catch (_) {
          return 'unavailable';
        }
      },
      rejectChildDecision: (session, request) async {
        if (_watchSession() != session ||
            !ref.read(mealDecisionPreferencesProvider).allowManualDecision) {
          return false;
        }
        try {
          await ref.read(acceptRemoteMealDecisionProvider).reject(request);
          unawaited(_notifyWatchInboxChanged());
          return _watchSession() == session;
        } catch (_) {
          return false;
        }
      },
      acceptChildDecision: (session, request) async {
        if (_watchSession() != session) return false;
        try {
          await ref.read(acceptRemoteMealDecisionProvider)(
            request,
            isCancelled: () => !mounted || _watchSession() != session,
          );
          unawaited(_notifyWatchInboxChanged());
          return _watchSession() == session;
        } catch (_) {
          return false;
        }
      },
      languageTag: () => mounted ? context.lang.localeName : 'en',
      readInbox: () => ref.read(mealDecisionRemoteControllerProvider),
      refreshInbox: () async {
        final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
        if (!remote.backgroundEnabled) return const MealDecisionRemoteInbox();
        await remote.refresh();
        if (_watchSession() == null || !remote.backgroundEnabled) {
          return const MealDecisionRemoteInbox();
        }
        return ref.read(mealDecisionRemoteControllerProvider);
      },
    ).exchange(call.arguments);
  }

  List<Map<String, Object?>>? _loadCaregiverWatchMeals(
    MealDecisionWatchSession session,
  ) {
    if (_watchSession() != session) return null;
    final meals = ref.read(caregiverWatchMealsProvider(session.uid));
    final now = clock.now();
    final previous = _lastWatchOverviewRefresh;
    if (previous == null ||
        previous.uid != session.uid ||
        now.difference(previous.at) >= const Duration(seconds: 15)) {
      _lastWatchOverviewRefresh = (uid: session.uid, at: now);
      final family = ref.read(
        familyPlanningSessionProvider((
          uid: session.uid,
          home: true,
          mealId: null,
          context: false,
        )),
      );
      unawaited(family.refreshAndWait(mirrorOnly: true));
    }
    if (meals == null) return null;
    return [
      for (final meal in meals)
        {
          'mealId': meal.id,
          'mealName': mealDisplayName(meal.name),
          if (meal.plannedAtMs case final int time) 'plannedAtMs': time,
          if (mealStatusBlocksAnotherMealActivation(meal.status)) ...{
            'activeStatus': mealStatusLabel(meal.status),
            if (meal.treatmentSurplus) 'treatmentSurplus': true,
            'progress': _caregiverMealProgress(session.uid, meal),
          },
        },
    ];
  }

  Future<List<Map<String, Object?>>> _loadChildWatchPlans(
    MealDecisionWatchSession session,
  ) async {
    if (_watchSession() != session) return const [];
    final meals = await ref.read(plannedMealsForTodayStreamProvider.future);
    if (_watchSession() != session) return const [];
    final canRequest =
        ref.read(mealDecisionPreferencesProvider).method ==
            MealDecisionMethod.caregiver &&
        ref
            .read(mealDecisionRemoteControllerProvider.notifier)
            .backgroundEnabled;
    final active = meals
        .where((meal) => mealStatusBlocksAnotherMealActivation(meal.status))
        .firstOrNull;
    final visible = active == null
        ? meals.where((meal) => meal.status == 'planned').take(30)
        : [active];
    final progress = active == null
        ? null
        : await _childMealProgress(session, active.id, active.status!);
    final accepted = active == null
        ? await Future.wait(
            visible.map(
              (meal) async => MapEntry(
                meal.id,
                await readAcceptedCaregiverMeal(
                  ref.read(databaseProvider),
                  session.uid,
                  meal.id,
                ),
              ),
            ),
          )
        : const <MapEntry<int, AcceptedCaregiverMeal?>>[];
    final prefs = active == null
        ? await ref.read(sharedPrefsProvider.future)
        : null;
    final acceptedById = Map.fromEntries(accepted);
    if (_watchSession() != session) return const [];
    return [
      for (final meal in visible)
        {
          'mealId': meal.id,
          'mealName': mealDisplayName(meal.name),
          if (active != null) ...{
            'activeStatus': mealStatusLabel(active.status!),
            if (progress != null) 'progress': progress,
            if (progress?['treatmentSurplus'] == true) 'treatmentSurplus': true,
          },
          if (_canSummarizeOnWatch(meal.status) &&
              (progress == null
                  ? meal.status != 'eating-extra'
                  : progress['canFinishEating'] == true))
            'canComplete': true,
          if (mealStatusesStartingEating.contains(meal.status))
            'canAddOn': true,
          if (meal.plannedAt case final DateTime at)
            'plannedAtMs': at.millisecondsSinceEpoch,
          if (meal.plannedDay case final String day) 'plannedDay': day,
          if (acceptedById[meal.id] case final AcceptedCaregiverMeal plan) ...{
            'acceptedDecision': plan.advice.decision!.name,
            if (plan.bolusDueAt case final DateTime due)
              'bolusDueAtMs': due.millisecondsSinceEpoch,
          },
          'canRequest':
              canRequest &&
              meal.status == 'planned' &&
              acceptedById[meal.id] == null &&
              (prefs == null ||
                  !usesManualMealChoice(
                    prefs,
                    meal.id,
                    meal.plannedAt?.millisecondsSinceEpoch,
                  )),
        },
    ];
  }

  Map<String, Object?> _caregiverMealProgress(
    String uid,
    CaregiverWatchMeal meal,
  ) {
    if (meal.status == 'eating-extra' && meal.addOnProgress == null) {
      return const {};
    }
    final history =
        ref
            .read(
              caregiverWatchProgressHistoryProvider((
                uid: uid,
                mealId: meal.id,
                status: meal.status,
              )),
            )
            .asData
            ?.value ??
        const [];
    final inbox = ref.read(mealDecisionRemoteControllerProvider);
    final request = inbox.accountUid == uid
        ? inbox.requests
              .where(
                (request) =>
                    request.mealId == meal.id && request.status == 'accepted',
              )
              .firstOrNull
        : null;
    final waiting = history
        .where((entry) => entry.status == 'bolused-waiting')
        .firstOrNull;
    return watchMealProgress(
      meal.status,
      decision: request?.answer?.decision,
      mirroredAddOn: meal.addOnProgress,
      history: history.map((entry) => entry.status),
      waitStartedAt: waiting == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(waiting.at),
      waitMinutes: request?.minutes,
    );
  }

  Future<Map<String, Object?>?> _childMealProgress(
    MealDecisionWatchSession session,
    int mealId,
    String status,
  ) async {
    final db = ref.read(databaseProvider);
    try {
      final meal = await db.mealDao.getMealById(mealId);
      if (_watchSession() != session || meal?.status != status) return null;
      final advice = await db.mealAdvisorResultDao.getMealAdvisorResult(mealId);
      final history = await db.mealAdvisorResultDao.getMealStatusHistory(
        mealId,
      );
      if (_watchSession() != session) return null;
      final monitorWait = status == 'bolused-waiting'
          ? await readMealWaitStatus()
          : null;
      final wait = monitorWait?.mealId == mealId ? monitorWait : null;
      final addOn = MealAddOnBolusContext.decode(meal?.addOnBolusContext);
      MealCalculatorRequest? handoff;
      if ((status == 'waiting-for-bolus' ||
              status == 'bolused-waiting' ||
              (status == 'eating-extra' &&
                  addOn?.waitingForExtraBolus == true)) &&
          defaultTargetPlatform == TargetPlatform.android &&
          !kIsWeb) {
        try {
          final saved = await PreferencesMealCalculatorRequestStore().read();
          handoff = saved
              .map(MealCalculatorRequest.fromJson)
              .where(
                (request) =>
                    request.matchesMealStage(mealId, addOn?.requestedAt),
              )
              .lastOrNull;
        } catch (_) {
          // A missing handoff leaves the stage visible without amounts.
        }
      }
      var shownCarbs = addOn?.requestedCarbs ?? handoff?.event.carbs;
      if (addOn != null &&
          !addOn.awaitingBolus &&
          addOn.acceptedWizardKeys.isNotEmpty &&
          addOn.requestedExtendedCarbs > 0) {
        final submitted = await db.localMirrorDao.getBolusWizardsBetween(
          addOn.bolusWindowStartedAt,
          DateTime.now(),
        );
        final acceptedCarbs = submitted
            .where(
              (wizard) =>
                  addOn.acceptedWizardKeys.contains('at:${wizard.createdAt}'),
            )
            .fold(0.0, (sum, wizard) => sum + wizard.toDomain().carbs);
        if (acceptedCarbs > 0) shownCarbs = acceptedCarbs.ceilMacro();
      }
      return _watchSession() == session
          ? {
              ...watchMealProgress(
                status,
                decision: storedMealDecision(advice?.result),
                history: history,
                addOn: addOn,
                waitDeadline: wait?.deadline,
                carbs: shownCarbs,
                extendedCarbs: addOn == null
                    ? handoff?.event.extendedCarbs
                    : null,
                carbsEntered:
                    (addOn != null
                        ? !addOn.awaitingBolus && addOn.bolusConfirmed
                        : handoff?.tracker.carbsEntered == true) ||
                    status == 'bolused-waiting',
                extendedCarbsConfirmed:
                    handoff?.tracker.extendedCarbsConfirmed == true &&
                    (handoff?.event.extendedCarbs ?? 0) > 0,
                waitingForExtendedCarbs:
                    wait?.waitingForExtendedCarbs == true ||
                    (addOn != null
                        ? !addOn.awaitingBolus &&
                              addOn.requestedExtendedCarbs > 0 &&
                              !addOn.extendedCarbsConfirmed
                        : handoff?.tracker.bolusConfirmed == true &&
                              handoff?.hasPendingScheduledExtendedCarbs ==
                                  true),
              ),
              if (meal!.treatmentSurplus) 'treatmentSurplus': true,
            }
          : null;
    } catch (_) {
      return null;
    }
  }

  bool _canSummarizeOnWatch(String? status) =>
      mealStatusesStartingEating.contains(status) || status == 'eating-extra';

  Future<Map<String, Object?>?> _loadChildWatchMealDetails(
    MealDecisionWatchSession session,
    int mealId,
  ) async {
    if (_watchSession() != session) return null;
    final db = ref.read(databaseProvider);
    final meal = await db.mealDao.getMealById(mealId);
    if (_watchSession() != session ||
        meal == null ||
        meal.purpose != 'meal' ||
        meal.status != 'planned') {
      return null;
    }
    final ingredients = await db.ingredientDao.getIngredientsInMeal(mealId);
    if (_watchSession() != session) return null;
    final names = ingredients.map((ingredient) => ingredient.name).toSet();
    final name = mealDisplayName(meal.name);
    final separator = name.indexOf(': ');
    final suffix = separator > 0 ? name.substring(separator + 2) : '';
    final generatedSuffix = names.any(
      (ingredient) =>
          suffix == ingredient || suffix.startsWith('$ingredient, '),
    );
    return {
      'mealName': generatedSuffix ? name.substring(0, separator) : name,
      'ingredients': names.take(8).toList(growable: false),
    };
  }

  Future<String> _startChildWatchMealAddOn(
    MealDecisionWatchSession session,
    int mealId,
    double totalPortions,
  ) async {
    if (_watchSession() != session || !_watchMealCompletions.add(mealId)) {
      return 'unavailable';
    }
    try {
      final base = await ref.refresh(
        mealSummaryControllerProvider(mealId).future,
      );
      if (_watchSession() != session ||
          !mealStatusesStartingEating.contains(base.mealStatus)) {
        return 'unavailable';
      }
      final draft = prepareMealAddOnDraft(base, totalMultiplier: totalPortions);
      if (!mealAddOnAmountsValid(draft)) return 'phoneRequired';
      await ref
          .read(recordMealAddOnUseCaseProvider)
          .call(draft, onlyFirstServing: true);
      return 'ok';
    } catch (_) {
      return 'unavailable';
    } finally {
      _watchMealCompletions.remove(mealId);
    }
  }

  Future<String> _completeChildWatchMeal(
    MealDecisionWatchSession session,
    int mealId,
  ) async {
    if (_watchSession() != session || !_watchMealCompletions.add(mealId)) {
      return 'unavailable';
    }
    try {
      final controller = ref.read(mealCompletionControllerProvider);
      final details = await controller.refresh(mealId);
      if (_watchSession() != session ||
          !_canSummarizeOnWatch(details.meal.status)) {
        return 'unavailable';
      }
      if (details.meal.status == 'eating-extra' && details.requiresBolus) {
        return 'unavailable';
      }
      final endedAt = clock.now();
      if (!details.timing.canAssumeEndedNow(endedAt)) {
        return 'phoneRequired';
      }
      final base = await ref.refresh(
        mealSummaryControllerProvider(mealId).future,
      );
      if (_watchSession() != session ||
          base.mealStatus != details.meal.status) {
        return 'unavailable';
      }
      final draft = base.copyWith(
        extraItems: const [],
        itemsById: {
          for (final entry in base.itemsById.entries)
            entry.key: entry.value.copyWith(
              consumedAmount: entry.value.reportedAmount,
            ),
        },
      );
      final changes = calculateMealCompletionAapsCarbs(draft);
      if (!mealCompletionAmountsValid(
            draft,
            inferMealCompletionChoice(draft),
          ) ||
          controller.needsReview(draft, details) ||
          changes.carbs != 0 ||
          changes.extendedCarbs != 0) {
        return 'phoneRequired';
      }
      final result = await controller.complete(
        draft: draft,
        details: details,
        action: null,
        endedAt: endedAt,
        finishingRefill: details.meal.status == 'eating-extra',
      );
      return result.requiresBolus ? 'bolusPending' : 'ok';
    } catch (_) {
      return 'unavailable';
    } finally {
      _watchMealCompletions.remove(mealId);
    }
  }

  Future<String> _openChildWatchSummaryOnPhone(
    MealDecisionWatchSession session,
    int mealId, {
    bool start = false,
  }) async {
    if (_watchSession() != session) return 'unavailable';
    final meal = await ref.read(databaseProvider).mealDao.getMealById(mealId);
    if (_watchSession() != session ||
        meal == null ||
        meal.purpose != 'meal' ||
        (start
            ? meal.status != 'planned'
            : !_canSummarizeOnWatch(meal.status) &&
                  meal.status != 'waiting-for-bolus')) {
      return 'unavailable';
    }
    try {
      final interactive = await _watchChannel.invokeMethod<bool>(
        'isPhoneInteractive',
      );
      if (!mounted || _watchSession() != session) return 'unavailable';
      final nav = ref.read(appRouterProvider).navigatorKey.currentContext;
      if (interactive == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          nav != null &&
          nav.mounted) {
        unawaited(_presentWatchMealSummary(nav, session, mealId, start: start));
        return 'ok';
      }
      final posted = await _watchChannel.invokeMethod<bool>('postMealSummary', {
        'mealId': mealId,
        'start': start,
        'title': start
            ? mealDisplayName(meal.name)
            : context.lang.mealCompletionTitle,
      });
      return posted == true ? 'ok' : 'unavailable';
    } on PlatformException {
      return 'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    }
  }

  Future<void> _presentWatchMealSummary(
    BuildContext nav,
    MealDecisionWatchSession session,
    int mealId, {
    bool start = false,
  }) async {
    if (_openingWatchMealSummary) return;
    _openingWatchMealSummary = true;
    try {
      final meal = await ref.read(databaseProvider).mealDao.getMealById(mealId);
      if (!mounted ||
          !nav.mounted ||
          _watchSession() != session ||
          meal == null ||
          meal.purpose != 'meal') {
        return;
      }
      if (start) {
        if (meal.status != 'planned') return;
        final planned = meal.toDomain();
        final result = await showMealStatusDialog(
          context: nav,
          meal: planned,
          startImmediately: true,
        );
        if (result != null &&
            mounted &&
            nav.mounted &&
            _watchSession() == session) {
          await handleMealStatusDialogResult(
            context: nav,
            ref: ref,
            meal: planned,
            result: result,
          );
        }
        return;
      }
      if (meal.status == 'waiting-for-bolus' &&
          meal.consumptionConfirmedEndedAt != null) {
        await openAapsAfterBolusStatusUpdateIfNeeded(
          context: nav,
          ref: ref,
          meal: meal.toDomain(),
          status: meal.status,
        );
      } else if (_canSummarizeOnWatch(meal.status)) {
        await openMealCompletion(nav, mealId: mealId);
      }
    } finally {
      _openingWatchMealSummary = false;
    }
  }

  Future<void> _resumeWatchMealSummary() async {
    final session = _watchSession();
    if (session == null ||
        session.mode != MealDecisionWatchMode.child ||
        _openingWatchMealSummary) {
      return;
    }
    try {
      final nav = ref.read(appRouterProvider).navigatorKey.currentContext;
      if (nav == null || !nav.mounted) return;
      final intent = await _watchChannel.invokeMapMethod<String, Object?>(
        'takeMealSummary',
      );
      final mealId = intent?['mealId'];
      if (mealId is! int || _watchSession() != session || !nav.mounted) {
        return;
      }
      await _presentWatchMealSummary(
        nav,
        session,
        mealId,
        start: intent?['start'] == true,
      );
    } on PlatformException {
      // The next foreground request can retry navigation.
    } on MissingPluginException {
      // No Android counterpart on this platform.
    }
  }

  Future<String> _skipChildWatchMeal(
    MealDecisionWatchSession session,
    int mealId,
  ) async {
    if (_watchSession() != session) return 'unavailable';
    final db = ref.read(databaseProvider);
    final notifications = ref.read(notificationsControllerUiProvider);
    try {
      final skipped = await db.transaction(() async {
        final meal = await db.mealDao.getMealById(mealId);
        if (_watchSession() != session ||
            meal?.status != 'planned' ||
            meal?.purpose != 'meal') {
          return false;
        }
        return db.mealDao.tryUpdateMealStatus(mealId, 'skipped');
      });
      if (!skipped) return 'unavailable';
      try {
        await notifications.cancelMealNotifications(
          mealId,
          includeTargetConsent: true,
          includeBolusInstructions: true,
        );
      } catch (_) {
        // The committed skip cannot be undone by notification cleanup failure.
      }
      return 'ok';
    } catch (_) {
      return 'unavailable';
    }
  }

  Future<Map<String, Object?>?> _requestChildWatchDecision(
    MealDecisionWatchSession session,
    int mealId,
    String requestId,
  ) async {
    if (_watchSession() != session) return null;
    final preferences = ref.read(mealDecisionPreferencesProvider);
    final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
    if (preferences.method != MealDecisionMethod.caregiver ||
        !remote.backgroundEnabled) {
      return null;
    }
    try {
      final db = ref.read(databaseProvider);
      final meal = await db.mealDao.getMealById(mealId);
      if (meal?.status != 'planned' || meal?.purpose != 'meal') return null;
      final outbox = FamilyMirrorOutbox(db);
      final source = await outbox.sourceForOwner(session.uid);
      if (await outbox.mealNeedsPublishing(mealId)) {
        await requestFamilyMirrorSync(db);
        final wait = Stopwatch()..start();
        while (_watchSession() == session &&
            await outbox.mealNeedsPublishing(mealId)) {
          if (wait.elapsed >= const Duration(seconds: 3)) return null;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      if (_watchSession() != session ||
          !remote.backgroundEnabled ||
          (await db.mealDao.getMealById(mealId)) != meal ||
          await outbox.mealNeedsPublishing(mealId) ||
          ref.read(mealDecisionPreferencesProvider).method !=
              MealDecisionMethod.caregiver) {
        return null;
      }
      if (_watchSession() != session) return null;
      final suggestion = await ref.read(captureMealAdvisorSuggestionProvider)(
        meal!.toDomain(),
        ref.read(deviceStatusUiProvider),
      );
      if (_watchSession() != session ||
          await outbox.mealNeedsPublishing(mealId))
        return null;
      final result = await remote.execute(
        'create',
        mealDecisionCreationData(
          requestId: requestId,
          mealId: mealId,
          sourceId: source,
          preferences: preferences,
          advisorSuggestion: suggestion,
        ),
        refresh: false,
      );
      if (_watchSession() != session) return null;
      final id = result['requestId'];
      final deadline = result['deadline'];
      if (id is! String || deadline is! int) return null;
      unawaited(remote.refresh());
      return {
        'requestId': id,
        'mealId': mealId,
        'mealName': mealDisplayName(meal.name),
        'deadlineMs': deadline,
        'status': result['status'] == 'responded' ? 'answered' : 'waiting',
      };
    } catch (_) {
      return null;
    }
  }

  bool _watchOwnsClaim(
    MealDecisionWatchSession session,
    MealDecisionRemoteRequest request,
  ) {
    final until = _watchClaimEnds[(session.uid, request.id)];
    final observed = request.data['claimUntil'];
    return until != null &&
        until > clock.now().millisecondsSinceEpoch &&
        observed is int &&
        observed <= until;
  }

  Future<int?> _renewWatchPresence(
    MealDecisionWatchSession session,
    String requestId,
    String stage,
  ) async {
    if (_watchSession() != session) return null;
    try {
      final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
      final result = await remote.execute('heartbeat', {
        'requestId': requestId,
        'stage': stage,
        'present': true,
      }, refresh: false);
      if (_watchSession() != session) return null;
      final until = result['claimUntil'] as int?;
      if (until != null) _watchClaimEnds[(session.uid, requestId)] = until;
      unawaited(remote.refresh());
      return until;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _respondFromWatch(
    MealDecisionWatchSession session,
    String requestId,
    Map<String, Object?> decision,
  ) async {
    if (_watchSession() != session) return false;
    try {
      await ref.read(mealDecisionRemoteControllerProvider.notifier).execute(
        'respond',
        {'requestId': requestId, 'decision': decision},
        refresh: false,
      );
      if (_watchSession() != session) return false;
      _dismissWatchInvitation(requestId);
      unawaited(
        ref.read(mealDecisionRemoteControllerProvider.notifier).refresh(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _claimFromWatch(
    MealDecisionWatchSession session,
    String requestId,
  ) async {
    final key = (session.uid, requestId);
    if (_watchSession() != session || !_watchClaims.add(key)) return false;
    try {
      final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
      final result = await remote.execute('claim', {
        'requestId': requestId,
      }, refresh: false);
      if (_watchSession() != session) return false;
      final until = result['claimUntil'] as int?;
      if (until == null) return false;
      final now = clock.now().millisecondsSinceEpoch;
      _watchClaimEnds.removeWhere((_, end) => end <= now);
      _watchClaimEnds[key] = until;
      _dismissWatchInvitation(requestId);
      return true;
    } catch (_) {
      return false;
    } finally {
      _watchClaims.remove(key);
    }
  }

  Future<bool> _claimOnPhoneFromWatch(
    MealDecisionWatchSession session,
    String requestId,
  ) async {
    final key = (session.uid, requestId);
    if (_watchSession() != session || !_watchClaims.add(key)) return false;
    try {
      final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
      final result = await remote.execute('claim', {
        'requestId': requestId,
      }, refresh: false);
      if (_watchSession() != session || result['claimUntil'] is! int) {
        return false;
      }
      _watchClaimEnds.remove(key);
      _dismissWatchInvitation(requestId);
      await MealDecisionNotificationIntentStore().add(
        MealDecisionNotificationIntent(requestId, 'claimOnPhone'),
      );
      if (_watchSession() != session) return false;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        try {
          await showMealDecisionPhoneHandoff(requestId);
        } catch (_) {
          // The handoff remains queued for the next resume.
        }
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _watchClaims.remove(key);
    }
  }

  Future<bool> _declineFromWatch(
    MealDecisionWatchSession session,
    String requestId,
  ) async {
    if (_watchSession() != session) return false;
    try {
      final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
      await remote.execute('decline', {'requestId': requestId}, refresh: false);
      if (_watchSession() != session) return false;
      _dismissWatchInvitation(requestId);
      unawaited(remote.refresh());
      return true;
    } catch (_) {
      return false;
    }
  }

  void _dismissWatchInvitation(String requestId) {
    presentedRequests.add(requestId);
    final handler =
        MealDecisionPresentationRegistry.caregiverActions[requestId];
    if (handler != null) unawaited(handler('watchHandled'));
    unawaited(cancelMealDecisionNotification(requestId));
  }

  Future<Map<String, Object?>?> _loadWatchPreview(
    MealDecisionWatchSession session,
    MealDecisionRemoteRequest request,
  ) async {
    final lang = context.lang;
    final portionLabel = lang.mealPortionLabel;
    final deferLabel = lang.mealDecisionDefer;
    final deferralMinutes = ref
        .read(mealDecisionPreferencesProvider)
        .deferralMinutes;
    final provider = familyPlanningSessionProvider((
      uid: session.uid,
      home: false,
      mealId: request.mealId,
      context: true,
    ));
    final listener = ref.listenManual(provider, (_, _) {});
    final family = listener.read();
    final nightscout = ref.listenManual(
      nightscoutRepositoryProvider,
      (_, _) {},
    );
    try {
      await timeMealDecision(
        'watch.phone.family',
        () => family.refreshAndWait(
          mirrorOnly: true,
          timing: (phase, elapsed) {
            mealDecisionTiming('watch.phone.family.$phase', elapsedMs: elapsed);
          },
        ),
      );
      final scope = FamilyAccessScope(family);
      final expectedRevision = request.data['mealRevision'];
      if (_watchSession() != session ||
          scope.owner != request.ownerUid ||
          scope.source != request.sourceId ||
          (expectedRevision is int &&
              family.rows['meals/${request.mealId}']?['revision'] !=
                  expectedRevision) ||
          !family.complete ||
          !scope.isCurrent) {
        return null;
      }
      final current = ref
          .read(mealDecisionRemoteControllerProvider)
          .byId(request.id);
      if (current == null ||
          current.claimedByUid != session.uid ||
          current.claimAvailable ||
          current.status != 'waiting' ||
          !current.pending) {
        return null;
      }
      final rows = family.rows.values.toList();
      final details = FamilyMealDetails(rows)
          .build(request.mealId, portionLabel, includePlannedPreview: true)
          ?.details;
      if (details == null) return null;
      final totals = details.preferredNutritionTotals;
      final visible = ref.read(caregiverVisibleStateProvider);
      var repository = nightscout.read().asData?.value;
      CaregiverMealContextHistory? history;
      try {
        final ready = repository ??= await ref
            .read(nightscoutRepositoryProvider.future)
            .timeout(const Duration(seconds: 1));
        history = await timeMealDecision(
          'watch.phone.nightscout',
          () => CaregiverMealContextHistory.load(
            NightscoutHistoryRepositories(ready),
            cachedTarget: visible.snapshot?.temporaryTarget,
            seriesTimeout: const Duration(seconds: 3),
          ),
        );
      } catch (_) {
        mealDecisionTiming('watch.phone.nightscout.unavailable');
      }
      final latest = ref
          .read(mealDecisionRemoteControllerProvider)
          .byId(request.id);
      if (_watchSession() != session ||
          !scope.isCurrent ||
          !family.complete ||
          latest == null ||
          latest.claimedByUid != session.uid ||
          latest.claimAvailable ||
          latest.status != 'waiting' ||
          !latest.pending ||
          (repository != null &&
              !identical(repository, nightscout.read().asData?.value))) {
        return null;
      }
      final glucose =
          history?.readings.lastOrNull ?? visible.snapshot?.latestGlucose;
      final activityTime = history?.asOf ?? clock.now();
      final activities = MealDecisionActivityContext.fromRows(
        rows,
        activityTime,
      );
      final watchHistory = CaregiverMealContextHistory(
        asOf: activityTime,
        syncedAt: history?.syncedAt,
        glucose: history?.glucose ?? const [],
        devices: history?.devices.isNotEmpty == true
            ? history!.devices
            : [if (visible.snapshot?.deviceStatus case final device?) device],
        treatments:
            history?.treatments ??
            [if (visible.snapshot?.temporaryTarget case final target?) target],
      );
      final watchContext = mealDecisionWatchContext(
        watchHistory,
        activities,
        lang,
      );
      mealDecisionTiming(
        'watch.phone.history.points iob=${(watchContext['iobHistory'] as List).length} '
        'cob=${(watchContext['cobHistory'] as List).length}',
      );
      return {
        ...watchContext,
        'historyAvailable': history?.syncedAt != null,
        if (request.data['advisorSuggestion'] case final Map suggestion)
          'advisorSuggestion': suggestion,
        'options': [
          for (final answer in MealDecisionAnswer.values)
            {
              'type': answer.name,
              'label': answer == MealDecisionAnswer.deferMeal
                  ? deferLabel
                  : mealDecisionLabel(answer.decision!),
              if (answer.requiresMinutes)
                'defaultMinutes': mealDecisionDefaultMinutes(
                  answer,
                  deferralMinutes: deferralMinutes,
                ),
            },
        ],
        if (details.meal.plannedAt case final DateTime plannedAt)
          'plannedAtMs': plannedAt.millisecondsSinceEpoch,
        if (totals != null) ...{
          'netCarbsG': totals.totalNetCarbsG,
          if (totals.totalNetCarbsG.isFinite)
            'mealCarbs': totals.totalNetCarbsG.ceilMacro(),
          'mealExtendedCarbs': mealExtendedCarbsFromNutrients(
            fatGrams: totals.totalFatG,
            proteinGrams: totals.totalProteinG,
          ),
          'proteinG': totals.totalProteinG,
          'fatG': totals.totalFatG,
        },
        'ingredients': [
          for (final ingredient in details.ingredients)
            if (ingredient.plannedAmount.isFinite &&
                ingredient.plannedAmount > 0)
              {
                'name': ingredient.ingredientName,
                'amount': ingredient.plannedAmount,
                'portion': ingredient.portionLabel,
                if (ingredient.plannedTotalGrams.isFinite &&
                    ingredient.plannedTotalGrams > 0)
                  'grams': ingredient.plannedTotalGrams,
              },
        ],
        if (glucose != null) ...{
          'glucoseMgDl': glucose.sgv,
          'glucoseDirection': glucose.direction,
          'glucoseAtMs': glucose.date.millisecondsSinceEpoch,
        },
      };
    } catch (_) {
      return null;
    } finally {
      nightscout.close();
      listener.close();
    }
  }

  Future<void> replayReceipts() async {
    if (!mounted || !configured || replaying) return;
    replaying = true;
    try {
      await ref.read(reconcileMealDecisionReceiptsProvider)();
    } catch (_) {
      /* Durable receipts retry on resume. */
    } finally {
      replaying = false;
    }
  }

  Future<void> drain() async {
    if (!mounted || !configured) return;
    if (routing) {
      drainAgain = true;
      return;
    }
    final navContext = ref.read(appRouterProvider).navigatorKey.currentContext;
    if (navContext == null) return;
    routing = true;
    try {
      await replayReceipts();
      final store = MealDecisionNotificationIntentStore();
      for (final intent in await store.read()) {
        if (!mounted || !configured || !navContext.mounted) return;
        final phoneHandoff = intent.action == 'claimOnPhone';
        if (phoneHandoff &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          continue;
        }
        final uid = ref.read(googleAccountProvider).asData?.value?.uid;
        final controller = ref.read(
          mealDecisionRemoteControllerProvider.notifier,
        );
        await controller.refresh();
        if (!mounted ||
            ref.read(googleAccountProvider).asData?.value?.uid != uid) {
          return;
        }
        final inbox = ref.read(mealDecisionRemoteControllerProvider);
        if (inbox.failed) return;
        final request = inbox.byId(intent.requestId);
        if (request == null) {
          await store.remove(intent);
          if (phoneHandoff) {
            await cancelMealDecisionPhoneHandoff(intent.requestId);
          }
          continue;
        }
        final mode = await ref.read(applicationDeviceModeProvider.future);
        if (!mounted ||
            !configured ||
            ref.read(googleAccountProvider).asData?.value?.uid != uid) {
          return;
        }
        if (!navContext.mounted) return;
        if (phoneHandoff &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          continue;
        }
        if (phoneHandoff && mode != ApplicationDeviceMode.caregiver) {
          await store.remove(intent);
          await cancelMealDecisionPhoneHandoff(intent.requestId);
          continue;
        }
        if (mode == ApplicationDeviceMode.caregiver) {
          await showCaregiverMealDecisionRequest(
            navContext,
            request.id,
            action: phoneHandoff ? 'claim' : intent.action,
            waitForClose: false,
          );
          await store.remove(intent);
          if (phoneHandoff) {
            await cancelMealDecisionPhoneHandoff(intent.requestId);
          }
        } else if (mode == ApplicationDeviceMode.patient &&
            request.ownerUid == uid) {
          if (ref.read(mealDecisionPreferencesProvider).method !=
              MealDecisionMethod.caregiver) {
            await store.remove(intent);
            continue;
          }
          if (MealDecisionPresentationRegistry.childMeals.contains(
            request.mealId,
          )) {
            await store.remove(intent);
            continue;
          }
          final stored = await ref
              .read(databaseProvider)
              .mealDao
              .getMealById(request.mealId);
          if (stored == null || !navContext.mounted) continue;
          if (stored.status != 'planned') {
            await store.remove(intent);
            continue;
          }
          final meal = stored.toDomain();
          final result = await showMealStatusDialog(
            context: navContext,
            meal: meal,
            startImmediately: true,
            initialCaregiverRequestId: request.id,
          );
          if (result != null && mounted && navContext.mounted) {
            await handleMealStatusDialogResult(
              context: navContext,
              ref: ref,
              meal: meal,
              result: result,
            );
          }
          await store.remove(intent);
        }
      }
      if (!mounted ||
          !configured ||
          !navContext.mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          MealDecisionPresentationRegistry.caregiverRequests.isNotEmpty) {
        return;
      }
      final mode = await ref.read(applicationDeviceModeProvider.future);
      if (!mounted || !navContext.mounted) {
        return;
      }
      final uid = ref.read(googleAccountProvider).asData?.value?.uid;
      final inbox = ref.read(mealDecisionRemoteControllerProvider);
      if (uid == null ||
          inbox.accountUid != uid ||
          inbox.loading ||
          inbox.failed) {
        return;
      }
      if (mode == ApplicationDeviceMode.patient) {
        await _openScheduledChildAnswer(navContext, uid, inbox);
        return;
      }
      if (mode != ApplicationDeviceMode.caregiver) return;
      if (presentedAccount != uid) {
        presentedAccount = uid;
        presentedRequests.clear();
      }
      for (final request in inbox.requests.reversed) {
        if (!caregiverCanOpenMealDecision(request, uid) ||
            _watchClaims.contains((uid, request.id)) ||
            presentedRequests.contains(request.id)) {
          continue;
        }
        presentedRequests.add(request.id);
        await showCaregiverMealDecisionRequest(
          navContext,
          request.id,
          waitForClose: false,
        );
        break;
      }
    } catch (_) {
      // Keep the durable intent for the next resume/refresh if navigation failed.
    } finally {
      routing = false;
      if (drainAgain && mounted) {
        drainAgain = false;
        unawaited(drain());
      }
    }
  }

  Future<void> _openScheduledChildAnswer(
    BuildContext context,
    String uid,
    MealDecisionRemoteInbox inbox,
  ) async {
    if (ref.read(mealDecisionPreferencesProvider).method !=
            MealDecisionMethod.caregiver ||
        MealDecisionPresentationRegistry.childMeals.isNotEmpty)
      return;
    final db = ref.read(databaseProvider);
    for (final request in inbox.requests.reversed) {
      if (request.ownerUid != uid ||
          request.status != 'answered' ||
          request.expired ||
          _presentedScheduledAnswers.contains((uid, request.id)))
        continue;
      final stored = await db.mealDao.getMealById(request.mealId);
      if (stored?.status != 'planned' || stored?.plannedAt == null) continue;
      final journal = await ScheduledMealDecisionJournal(db).load(
        request.mealId,
        DateTime.fromMillisecondsSinceEpoch(stored!.plannedAt!),
      );
      if (!mounted ||
          !context.mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          ref.read(googleAccountProvider).asData?.value?.uid != uid)
        return;
      if (journal?.uid != uid ||
          journal?.requestId != request.id ||
          ref
                  .read(mealDecisionRemoteControllerProvider)
                  .byId(request.id)
                  ?.status !=
              'answered' ||
          MealDecisionPresentationRegistry.childMeals.isNotEmpty)
        continue;
      _presentedScheduledAnswers.add((uid, request.id));
      final meal = stored.toDomain();
      final result = await showMealStatusDialog(
        context: context,
        meal: meal,
        startImmediately: true,
        initialCaregiverRequestId: request.id,
      );
      if (result != null && mounted && context.mounted) {
        await handleMealStatusDialogResult(
          context: context,
          ref: ref,
          meal: meal,
          result: result,
        );
      }
      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(cleanTimeoutNotifications());
    }
    if (state == AppLifecycleState.resumed && configured) {
      unawaited(_resumeWatchMealSummary());
      unawaited(
        ref.read(mealDecisionRemoteControllerProvider.notifier).refresh(),
      );
      unawaited(drain());
    }
  }

  @override
  void dispose() {
    _watchChannel.setMethodCallHandler(null);
    receiptRetry?.cancel();
    unawaited(intentSubscription?.cancel());
    unawaited(presentationSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isNotEmpty) {
      ref.watch(mealDecisionNotificationsProvider);
      ref.listen(
        applicationDeviceModeProvider,
        (_, _) => unawaited(_resumeWatchMealSummary()),
      );
      ref.listen(
        initialConfigurationDoneProvider,
        (_, _) => unawaited(_resumeWatchMealSummary()),
      );
      ref.listen(googleAccountProvider, (_, _) {
        unawaited(cleanTimeoutNotifications());
        unawaited(_resumeWatchMealSummary());
      });
      ref.listen(
        mealDecisionPreferencesProvider,
        (_, _) => unawaited(cleanTimeoutNotifications()),
      );
      if (ref.watch(applicationDeviceModeProvider).asData?.value ==
          ApplicationDeviceMode.patient) {
        ref.listen(
          mealWaitStatusProvider,
          (_, _) => unawaited(_notifyWatchInboxChanged()),
        );
        ref.listen(mealTreatmentSurplusesProvider, (previous, next) {
          if (!setEquals(previous?.value, next.value))
            unawaited(_notifyWatchInboxChanged());
        });
        ref.listen(
          mealsStreamProvider,
          (_, _) => unawaited(cleanTimeoutNotifications()),
        );
        ref.listen(plannedMealsForTodayStreamProvider, (_, _) {
          unawaited(_notifyWatchInboxChanged());
        });
      }
    }
    if (Firebase.apps.isNotEmpty &&
        ref.watch(initialConfigurationDoneProvider).asData?.value == true) {
      final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
      if (uid != null &&
          ref.watch(applicationDeviceModeProvider).asData?.value ==
              ApplicationDeviceMode.caregiver) {
        ref.listen(caregiverWatchMealsProvider(uid), (previous, next) {
          if (!listEquals(previous, next)) {
            unawaited(_notifyWatchInboxChanged());
          }
        });
        final meal = ref.watch(caregiverWatchMealsProvider(uid))?.firstOrNull;
        if (meal != null &&
            mealStatusBlocksAnotherMealActivation(meal.status)) {
          ref.listen(
            caregiverWatchProgressHistoryProvider((
              uid: uid,
              mealId: meal.id,
              status: meal.status,
            )),
            (_, _) => unawaited(_notifyWatchInboxChanged()),
          );
        }
      }
      ref.watch(mealDecisionRemoteControllerProvider);
      ref.listen(mealDecisionRemoteControllerProvider, (previous, next) {
        final uid = ref.read(googleAccountProvider).asData?.value?.uid;
        if (previous?.accountUid != next.accountUid ||
            previous?.failed != next.failed ||
            previous?.loading != next.loading ||
            !listEquals(_watchInboxState(previous), _watchInboxState(next))) {
          final caregiver =
              ref.read(applicationDeviceModeProvider).asData?.value ==
              ApplicationDeviceMode.caregiver;
          final old = _watchInvitationIds(previous, previous?.accountUid);
          final active = caregiver
              ? _watchInvitationIds(next, uid)
              : <String>{};
          unawaited(
            _notifyWatchInboxChanged(
              added:
                  caregiver &&
                      !next.loading &&
                      !next.failed &&
                      WidgetsBinding.instance.lifecycleState ==
                          AppLifecycleState.resumed
                  ? active.difference(old)
                  : const {},
              removed: old.difference(active),
            ),
          );
        }
        if (uid != null &&
            next.accountUid == uid &&
            !next.loading &&
            !next.failed) {
          for (final request in next.requests) {
            if (request.ownerUid == uid &&
                request.status == 'answered' &&
                !request.expired &&
                ref.read(applicationDeviceModeProvider).asData?.value ==
                    ApplicationDeviceMode.patient &&
                !MealDecisionPresentationRegistry.childMeals.contains(
                  request.mealId,
                ) &&
                _notifiedChildAnswers.add((uid, request.id))) {
              unawaited(
                showChildMealDecisionResponse(request.id).catchError(
                  (Object error) => debugPrint(
                    'MealDecisionPush Child response failed: ${error.runtimeType}',
                  ),
                ),
              );
            }
            final before = previous?.byId(request.id);
            if (request.ownerUid == uid &&
                (request.status == 'accepted' ||
                    request.data['outcome'] != null)) {
              unawaited(cancelScheduledMealDecisionFallback(request.id));
            }
            if (request.claimedByUid == uid && before?.claimedByUid != uid) {
              if (_watchClaims.contains((uid, request.id)) ||
                  _watchOwnsClaim((
                    uid: uid,
                    mode: MealDecisionWatchMode.caregiver,
                  ), request) ||
                  MealDecisionPresentationRegistry.caregiverRequests.contains(
                    request.id,
                  )) {
                presentedRequests.add(request.id);
              } else {
                presentedRequests.remove(request.id);
              }
            }
            final member = request.members
                .where((m) => m['uid'] == uid)
                .firstOrNull;
            final awaitingChild =
                request.ownerUid == uid &&
                request.status == 'answered' &&
                !request.expired;
            if (!awaitingChild &&
                (!request.pending ||
                    request.status != 'waiting' ||
                    member?['status'] == 'declined' ||
                    (request.claimedByUid != null &&
                        !request.claimAvailable))) {
              unawaited(cancelMealDecisionNotification(request.id));
            }
          }
        }
        final shouldDrain = !identical(previous, next);
        if (shouldDrain && !next.loading && !next.failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(replayReceipts());
              unawaited(drain());
            }
          });
        }
      });
    }
    return widget.child;
  }
}
