import '../meal_decision_answer.dart';
import '../remote/caregiver_meal_decision_eligibility.dart';
import '../remote/meal_decision_remote_controller.dart';
import '../remote/meal_decision_remote_request.dart';

enum MealDecisionWatchMode { child, caregiver }

typedef MealDecisionWatchSession = ({String uid, MealDecisionWatchMode mode});

/// Phone-side contract shared by WatchConnectivity and the Wear OS Data Layer.
class MealDecisionWatchProtocol {
  const MealDecisionWatchProtocol({
    required this.session,
    required this.refreshInbox,
    this.readInbox,
    this.loadPreview,
    this.claim,
    this.claimOnPhone,
    this.decline,
    this.respond,
    this.renewPresence,
    this.ownsClaim,
    this.loadChildPlans,
    this.loadChildMealDetails,
    this.loadCaregiverMeals,
    this.requestChildDecision,
    this.prepareChildAdvisor,
    this.acceptChildAdvisor,
    this.completeChildMeal,
    this.startChildMealAddOn,
    this.openPhoneMealSummary,
    this.startMealOnPhone,
    this.startAcceptedMeal,
    this.startEatingAfterWait,
    this.skipChildMeal,
    this.acceptChildDecision,
    this.rejectChildDecision,
    this.languageTag,
  });

  static const channelName = 'pl.diabeatthis.app/meal_decision_watch';
  static const methodName = 'exchange';
  static const version = 1;

  final MealDecisionWatchSession? Function() session;
  final Future<MealDecisionRemoteInbox> Function() refreshInbox;
  final MealDecisionRemoteInbox? Function()? readInbox;
  final Future<Map<String, Object?>?> Function(
    MealDecisionWatchSession,
    MealDecisionRemoteRequest,
  )?
  loadPreview;
  final Future<bool> Function(MealDecisionWatchSession, String)? claim;
  final Future<bool> Function(MealDecisionWatchSession, String)? claimOnPhone;
  final Future<bool> Function(MealDecisionWatchSession, String)? decline;
  final Future<bool> Function(
    MealDecisionWatchSession,
    String,
    Map<String, Object?>,
  )?
  respond;
  final Future<int?> Function(MealDecisionWatchSession, String, String)?
  renewPresence;
  final bool Function(MealDecisionWatchSession, MealDecisionRemoteRequest)?
  ownsClaim;
  final Future<List<Map<String, Object?>>> Function(MealDecisionWatchSession)?
  loadChildPlans;
  final Future<Map<String, Object?>?> Function(MealDecisionWatchSession, int)?
  loadChildMealDetails;
  final List<Map<String, Object?>>? Function(MealDecisionWatchSession)?
  loadCaregiverMeals;
  final Future<Map<String, Object?>?> Function(
    MealDecisionWatchSession,
    int,
    String,
  )?
  requestChildDecision;
  final Future<Map<String, Object?>?> Function(
    MealDecisionWatchSession,
    int,
    String,
  )?
  prepareChildAdvisor;
  final Future<bool> Function(MealDecisionWatchSession, int, String)?
  acceptChildAdvisor;
  final Future<String> Function(MealDecisionWatchSession, int)?
  completeChildMeal;
  final Future<String> Function(MealDecisionWatchSession, int, double)?
  startChildMealAddOn;
  final Future<String> Function(MealDecisionWatchSession, int)?
  openPhoneMealSummary;
  final Future<String> Function(MealDecisionWatchSession, int)?
  startMealOnPhone;
  final Future<String> Function(MealDecisionWatchSession, int)?
  startAcceptedMeal;
  final Future<String> Function(MealDecisionWatchSession, int)?
  startEatingAfterWait;
  final Future<String> Function(MealDecisionWatchSession, int)? skipChildMeal;
  final Future<bool> Function(
    MealDecisionWatchSession,
    MealDecisionRemoteRequest,
  )?
  acceptChildDecision;
  final Future<bool> Function(
    MealDecisionWatchSession,
    MealDecisionRemoteRequest,
  )?
  rejectChildDecision;
  final String Function()? languageTag;

  Future<Map<String, Object?>> exchange(Object? message) async {
    if (message is! Map || message['version'] is! int) {
      return _reply('invalidRequest');
    }
    if (message['version'] != version) return _reply('unsupportedVersion');

    final action = message['action'];
    final requestId = message['requestId'];
    final mealAction = const {
      'completeMeal',
      'startMealAddOn',
      'phoneMealSummary',
      'startMealOnPhone',
      'startAcceptedMeal',
      'startEatingAfterWait',
      'skipMeal',
      'childMealDetails',
    }.contains(action);
    if (action != 'mode' &&
        action != 'list' &&
        !mealAction &&
        (!const {
              'open',
              'claim',
              'claimOnPhone',
              'decline',
              'respond',
              'presence',
              'requestDecision',
              'prepareAdvisor',
              'acceptAdvisor',
              'acceptDecision',
              'rejectDecision',
            }.contains(action) ||
            requestId is! String ||
            !RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId))) {
      return _reply('invalidRequest');
    }

    final current = session();
    if (current == null) return _reply('unavailable');
    final (:uid, :mode) = current;
    bool claimedHere(MealDecisionRemoteRequest request) =>
        ownsClaim?.call(current, request) ?? true;
    if (action == 'mode') return _reply('ok', mode: mode);
    if (mealAction) {
      final mealId = message['mealId'];
      if (mealId is! int || mealId <= 0) return _reply('invalidRequest');
      if (mode != MealDecisionWatchMode.child) return _reply('unavailable');
      if (action == 'childMealDetails') {
        final details = await loadChildMealDetails?.call(current, mealId);
        return session() == current && details != null
            ? _reply('ok', mode: mode, preview: details)
            : _reply('unavailable');
      }
      if (action == 'startMealAddOn') {
        final portions = message['totalPortions'];
        if (portions is! num || (portions != 1.5 && portions != 2)) {
          return _reply('invalidRequest', mode: mode);
        }
        final status = await startChildMealAddOn?.call(
          current,
          mealId,
          portions.toDouble(),
        );
        return session() == current
            ? _reply(status ?? 'unavailable', mode: mode)
            : _reply('unavailable');
      }
      final command = switch (action) {
        'completeMeal' => completeChildMeal,
        'phoneMealSummary' => openPhoneMealSummary,
        'startMealOnPhone' => startMealOnPhone,
        'startAcceptedMeal' => startAcceptedMeal,
        'startEatingAfterWait' => startEatingAfterWait,
        _ => skipChildMeal,
      };
      final status = await command?.call(current, mealId);
      return session() == current
          ? _reply(status ?? 'unavailable', mode: mode)
          : _reply('unavailable');
    }
    if (action == 'prepareAdvisor' || action == 'acceptAdvisor') {
      final mealId = message['mealId'];
      if (mealId is! int || mealId <= 0) return _reply('invalidRequest');
      if (mode != MealDecisionWatchMode.child) return _reply('unavailable');
      final id = requestId as String;
      if (action == 'acceptAdvisor') {
        final accepted = await acceptChildAdvisor?.call(current, mealId, id);
        return session() == current && accepted == true
            ? _reply('ok', mode: mode)
            : _reply('unavailable');
      }
      final preview = await prepareChildAdvisor?.call(current, mealId, id);
      return session() == current && preview != null
          ? _reply('ok', mode: mode, preview: preview)
          : _reply('unavailable');
    }
    if (action == 'requestDecision') {
      final mealId = message['mealId'];
      if (mealId is! int || mealId < 1) return _reply('invalidRequest');
      if (mode != MealDecisionWatchMode.child) return _reply('unavailable');
      final row = await requestChildDecision?.call(
        current,
        mealId,
        requestId as String,
      );
      if (row == null || session() != current) {
        return _reply('unavailable', mode: mode);
      }
      return _reply('ok', mode: mode, requests: [row]);
    }
    if (action == 'decline' || action == 'claimOnPhone') {
      if (mode != MealDecisionWatchMode.caregiver) return _reply('unavailable');
      final command = action == 'decline' ? decline : claimOnPhone;
      final done = await command?.call(current, requestId as String);
      return session() == current && done == true
          ? _reply('ok', mode: mode)
          : _reply('unavailable');
    }
    if (const {'claim', 'respond', 'presence'}.contains(action) &&
        mode != MealDecisionWatchMode.caregiver) {
      return _reply('unavailable');
    }

    bool currentInbox(MealDecisionRemoteInbox inbox) =>
        session() == current &&
        inbox.accountUid == uid &&
        !inbox.loading &&
        !inbox.failed;
    if (action == 'acceptDecision' || action == 'rejectDecision') {
      final mealId = message['mealId'];
      if (mealId is! int || mealId <= 0) return _reply('invalidRequest');
      if (mode != MealDecisionWatchMode.child) return _reply('unavailable');
    }
    final childList = action == 'list' && mode == MealDecisionWatchMode.child;
    final caregiverList =
        action == 'list' &&
        mode == MealDecisionWatchMode.caregiver &&
        loadCaregiverMeals != null;
    final cached = action != 'claim' ? readInbox?.call() : null;
    var inbox = (childList || caregiverList) && readInbox != null
        ? cached ?? const MealDecisionRemoteInbox()
        : cached != null && currentInbox(cached)
        ? cached
        : await refreshInbox();
    if (childList &&
        message['openAnswer'] == true &&
        requestId is String &&
        RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId) &&
        (!currentInbox(inbox) || inbox.byId(requestId)?.status != 'answered')) {
      inbox = await refreshInbox();
    }
    if (!currentInbox(inbox) && !childList && !caregiverList) {
      return _reply('unavailable', mode: session() == current ? mode : null);
    }
    if (action == 'presence') {
      final stage = message['stage'];
      if (stage != 'context' && stage != 'decision') {
        return _reply('invalidRequest');
      }
      final request = inbox.byId(requestId as String);
      if (request == null ||
          request.claimedByUid != uid ||
          !claimedHere(request) ||
          request.claimAvailable ||
          !caregiverCanOpenMealDecision(request, uid)) {
        return _reply('unavailable', mode: mode);
      }
      final until = await renewPresence?.call(
        current,
        request.id,
        stage as String,
      );
      if (until == null || session() != current) return _reply('unavailable');
      return {'version': version, 'status': 'ok', 'claimUntilMs': until};
    }
    if (action == 'respond') {
      final answer = MealDecisionAnswer.values
          .where((answer) => answer.name == message['type'])
          .firstOrNull;
      final minutes = message['minutes'];
      final note = message['message'];
      if (answer == null ||
          (minutes != null && minutes is! int) ||
          note is! String) {
        return _reply('invalidRequest');
      }
      final decision = answer.remoteResponse(minutes as int?, note);
      if (decision == null) return _reply('invalidRequest');
      final request = inbox.byId(requestId as String);
      if (request != null &&
          request.claimedByUid == uid &&
          (request.claimAvailable || request.expired)) {
        return _reply('expired', mode: mode);
      }
      if (request == null ||
          request.claimedByUid != uid ||
          !claimedHere(request) ||
          request.claimAvailable ||
          !caregiverCanOpenMealDecision(request, uid) ||
          await respond?.call(current, requestId, decision) != true ||
          session() != current) {
        return _reply('unavailable');
      }
      return _reply('ok', mode: mode);
    }
    if (action == 'acceptDecision' || action == 'rejectDecision') {
      final request = inbox.byId(requestId as String);
      if (request == null ||
          request.ownerUid != uid ||
          request.mealId != message['mealId'] ||
          request.status != 'answered' ||
          request.expired ||
          request.answer == null ||
          await (action == 'acceptDecision'
                      ? acceptChildDecision
                      : rejectChildDecision)
                  ?.call(current, request) !=
              true ||
          session() != current) {
        return _reply('unavailable', mode: mode);
      }
      return _reply('ok', mode: mode);
    }
    if (action == 'claim') {
      final request = inbox.byId(requestId as String);
      if (request == null ||
          !request.claimAvailable ||
          !caregiverCanOpenMealDecision(request, uid) ||
          await claim?.call(current, requestId) != true ||
          session() != current) {
        return _reply('unavailable');
      }
      final latest = readInbox?.call();
      final latestRequest = latest?.byId(requestId);
      inbox =
          latest != null &&
              currentInbox(latest) &&
              latestRequest?.claimedByUid == uid &&
              latestRequest?.claimAvailable == false
          ? latest
          : await refreshInbox();
      if (!currentInbox(inbox)) return _reply('unavailable');
      final confirmed = inbox.byId(requestId);
      if (confirmed == null ||
          confirmed.claimedByUid != uid ||
          confirmed.claimAvailable) {
        return _reply('unavailable');
      }
    }

    final requests = [
      for (final request
          in currentInbox(inbox)
              ? inbox.requests
              : const <MealDecisionRemoteRequest>[])
        if ((action == 'list' || request.id == requestId) &&
            (mode == MealDecisionWatchMode.child
                ? request.ownerUid == uid && request.pending
                : caregiverCanOpenMealDecision(request, uid) &&
                      (request.claimAvailable || claimedHere(request))))
          {
            'requestId': request.id,
            'mealName': request.mealName,
            'deadlineMs': request.deadline.millisecondsSinceEpoch,
            if (mode == MealDecisionWatchMode.child) 'status': request.status,
            if (mode == MealDecisionWatchMode.child) 'mealId': request.mealId,
            if (caregiverList)
              if (int.tryParse('${request.data['mealId']}')
                  case final int mealId)
                'mealId': mealId,
            if (mode == MealDecisionWatchMode.child &&
                request.status == 'answered')
              if (request.answer case final MealDecisionAnswer answer)
                'decision': {
                  'type': answer.name,
                  if (request.data['allowManualDecision'] == false)
                    'allowManualDecision': false,
                  if (answer.requiresMinutes) 'minutes': request.minutes,
                  'note': request.message,
                  if (request.respondingCaregiverName case final String name)
                    'caregiverName': name,
                },
            if (mode == MealDecisionWatchMode.child &&
                request.status == 'waiting' &&
                !request.claimAvailable)
              if (request.claimedByName case final String name)
                'caregiverName': name,
            if (mode == MealDecisionWatchMode.child &&
                request.status == 'waiting' &&
                !request.claimAvailable)
              'stage': request.stage,
            if (!request.claimAvailable &&
                (mode == MealDecisionWatchMode.child ||
                    request.claimedByUid == uid))
              if (request.data['claimUntil'] case final int claimUntil)
                'claimUntilMs': claimUntil,
          },
    ];
    if (action != 'list' && requests.isEmpty) return _reply('unavailable');
    Map<String, Object?>? preview;
    if (action != 'list' && mode == MealDecisionWatchMode.caregiver) {
      final request = inbox.byId(requestId as String)!;
      if (request.claimedByUid == uid && !request.claimAvailable) {
        preview = await loadPreview?.call(current, request);
        if (session() != current ||
            !request.pending ||
            request.claimAvailable) {
          return _reply('unavailable');
        }
      }
    }
    final plans = childList
        ? await loadChildPlans?.call(current)
        : caregiverList
        ? loadCaregiverMeals?.call(current)
        : null;
    if (session() != current) return _reply('unavailable');
    final focusedRequest =
        childList && requestId is String && currentInbox(inbox)
        ? inbox.byId(requestId)
        : null;
    return _reply(
      'ok',
      mode: mode,
      requests: requests,
      preview: preview,
      plans: plans,
      inboxAvailable: caregiverList || childList ? currentInbox(inbox) : null,
      allCaregiversDeclined:
          focusedRequest?.ownerUid == uid &&
          focusedRequest?.status == 'expired' &&
          focusedRequest?.data['terminalReason'] == 'allCaregiversDeclined',
    );
  }

  Map<String, Object?> _reply(
    String status, {
    MealDecisionWatchMode? mode,
    List<Map<String, Object?>>? requests,
    Map<String, Object?>? preview,
    List<Map<String, Object?>>? plans,
    bool? inboxAvailable,
    bool allCaregiversDeclined = false,
  }) => {
    'version': version,
    'status': status,
    if (mode != null) 'mode': mode.name,
    if (requests != null) 'requests': requests,
    if (preview != null) 'preview': preview,
    if (plans != null) 'plans': plans,
    if (inboxAvailable != null) 'inboxAvailable': inboxAvailable,
    if (allCaregiversDeclined) 'allCaregiversDeclined': true,
    if (languageTag?.call() case final String tag) 'languageTag': tag,
  };
}
