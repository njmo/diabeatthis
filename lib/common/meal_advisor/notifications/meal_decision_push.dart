import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meal_decision_wear_notifications/meal_decision_wear_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/bootstrap/local_notifications_bootstrap.dart'
    as bootstrap;
import '../../app_mode/application_device_mode.dart';
import '../../l10n/application_language.dart';
import '../../l10n/language.dart';
import '../../notifications/firebase_background_handler.dart';
import '../meal_decision_eligibility.dart';
import '../meal_decision_preference_keys.dart';
import '../meal_decision_preferences.dart';
import '../remote/scheduled_meal_decision_journal.dart';
import 'meal_decision_notification_eligibility.dart';
import 'meal_decision_notification_intent.dart';

const _mealDecisionChannel = 'meal_decision_requests';
const _androidFlagLocalOnly = 0x100;

/// FCM data contains only the opaque request ID, never clinical information.
Future<void> showMealDecisionPush(RemoteMessage message) async {
  final id = message.data['requestId'];
  if (message.data.length != 1 ||
      id is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
    return;
  }
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (!await MealDecisionNotificationEligibility().allows(uid)) {
    if (kDebugMode) {
      debugPrint(
        'MealDecisionPush ignored: notification eligibility unavailable '
        '(signedIn=${uid != null})',
      );
    }
    return;
  }
  final mode = await loadApplicationDeviceMode();
  final storage = SharedPreferencesAsync();
  final saved = await storage.getString(mealDecisionPreferencesKey);
  final preferences =
      saved == null &&
          await storage.getBool(aiAssistedMealAdvisorPreferenceKey) == true
      ? const MealDecisionPreferences(method: MealDecisionMethod.ai)
      : MealDecisionPreferences.decode(saved);
  if (!mealDecisionEnabled(mode, preferences)) {
    if (kDebugMode) debugPrint('MealDecisionPush ignored: disabled in settings');
    return;
  }
  final caregiver = mode == ApplicationDeviceMode.caregiver;
  if (!caregiver) {
    await showChildMealDecisionResponse(id);
    return;
  }
  if (kDebugMode) debugPrint('MealDecisionPush Wear forwarding started');
  final forwarded = await forwardWearMealInvitation(id);
  if (kDebugMode) {
    debugPrint('MealDecisionPush Wear forwarding confirmed=$forwarded');
  }
  if (forwarded) return;
  await _showMealDecisionNotification(id, caregiver: true, localOnly: true);
  await wakePhoneForMealInvitation(_mealDecisionChannel);
}

Future<void> showChildMealDecisionResponse(String requestId) async {
  final forwarded = await forwardWearMealInvitation(
    requestId,
    childResponse: true,
  );
  if (kDebugMode) {
    debugPrint('MealDecisionPush Child response forwarded=$forwarded');
  }
  if (forwarded) return;
  await _showMealDecisionNotification(
    requestId,
    caregiver: false,
    localOnly: true,
    childResponse: true,
  );
  await wakePhoneForMealInvitation(_mealDecisionChannel);
}

Future<void> showScheduledMealDecisionFallback(String requestId) =>
    _showMealDecisionNotification(requestId, caregiver: false, timedOut: true);

Future<void> showMealDecisionPhoneHandoff(String requestId) async {
  await _showMealDecisionNotification(
    requestId,
    caregiver: false,
    localOnly: true,
    phoneHandoff: true,
  );
  await wakePhoneForMealInvitation(_mealDecisionChannel);
}

Future<void> _showMealDecisionNotification(
  String id, {
  required bool caregiver,
  bool timedOut = false,
  bool localOnly = false,
  bool phoneHandoff = false,
  bool childResponse = false,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await initializeLanguageStringsFromPreferences();
  await bootstrap.init(plugin);
  final notificationId = timedOut
      ? mealDecisionNotificationId('timeout/$id')
      : mealDecisionNotificationId(phoneHandoff ? 'watch-phone/$id' : id);
  await plugin.show(
    id: notificationId,
    title: timedOut
        ? lang.mealDecisionTimeoutChildTitle
        : childResponse
        ? lang.mealDecisionAnswerTitle
        : lang.mealDecisionNotificationTitle,
    body: timedOut
        ? lang.mealDecisionTimeoutWaiting
        : childResponse
        ? lang.mealDecisionDemoAnswered
        : lang.mealDecisionNotificationBody,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _mealDecisionChannel,
        lang.mealDecisionNotificationTitle,
        importance: Importance.high,
        priority: Priority.high,
        onlyAlertOnce: childResponse,
        additionalFlags: localOnly
            ? Int32List.fromList([_androidFlagLocalOnly])
            : null,
        timeoutAfter: timedOut
            ? scheduledMealDecisionRecoveryWindow.inMilliseconds
            : phoneHandoff || childResponse
            ? 300000
            : null,
        actions: caregiver
            ? [
                AndroidNotificationAction(
                  'claim',
                  lang.mealDecisionNotificationClaim,
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'delegate',
                  lang.mealDecisionNotificationDelegate,
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'decline',
                  lang.mealDecisionNotificationDecline,
                  showsUserInterface: true,
                ),
              ]
            : [],
      ),
    ),
    payload: jsonEncode({
      'type': mealDecisionNotificationType,
      'requestId': id,
    }),
  );
}

@pragma('vm:entry-point')
Future<void> mealDecisionFirebaseBackgroundHandler(
  RemoteMessage message,
) async {
  await familyFirebaseBackgroundHandler(message);
}

int mealDecisionNotificationId(String requestId) {
  var id = 0;
  for (final unit in requestId.codeUnits) {
    id = (id * 31 + unit) & 0x7fffffff;
  }
  return id;
}

Future<void> cancelMealDecisionNotification(String requestId) async {
  try {
    await FlutterLocalNotificationsPlugin().cancel(
      id: mealDecisionNotificationId(requestId),
    );
  } catch (_) {
    // A notification failure must not prevent the decision UI from closing.
  }
}

Future<void> cancelMealDecisionPhoneHandoff(String requestId) =>
    cancelMealDecisionNotification('watch-phone/$requestId');

Future<void> cancelScheduledMealDecisionFallback(
  String requestId, {
  bool throwOnFailure = false,
}) async {
  try {
    await FlutterLocalNotificationsPlugin().cancel(
      id: mealDecisionNotificationId('timeout/$requestId'),
    );
  } catch (_) {
    if (throwOnFailure) rethrow;
  }
}
