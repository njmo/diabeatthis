import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/bootstrap/local_notifications_bootstrap.dart'
    as bootstrap;
import '../../../firebase_options.dart';
import '../../app_mode/application_device_mode.dart';
import '../../l10n/application_language.dart';
import '../../l10n/language.dart';
import '../meal_decision_eligibility.dart';
import '../meal_decision_preference_keys.dart';
import '../meal_decision_preferences.dart';
import 'meal_decision_notification_eligibility.dart';
import 'meal_decision_notification_intent.dart';

/// FCM data contains only the opaque request ID, never clinical information.
Future<void> showMealDecisionPush(RemoteMessage message) async {
  final id = message.data['requestId'];
  if (message.data.length != 1 ||
      id is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
    return;
  }
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (!await MealDecisionNotificationEligibility().allows(uid)) return;
  final mode = await loadApplicationDeviceMode();
  final storage = SharedPreferencesAsync();
  final saved = await storage.getString(mealDecisionPreferencesKey);
  final preferences =
      saved == null &&
          await storage.getBool(aiAssistedMealAdvisorPreferenceKey) == true
      ? const MealDecisionPreferences(method: MealDecisionMethod.ai)
      : MealDecisionPreferences.decode(saved);
  if (!mealDecisionEnabled(mode, preferences)) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await initializeLanguageStringsFromPreferences();
  await bootstrap.init(plugin);
  final notificationId = mealDecisionNotificationId(id);
  final caregiver = mode == ApplicationDeviceMode.caregiver;
  await plugin.show(
    id: notificationId,
    title: lang.mealDecisionNotificationTitle,
    body: lang.mealDecisionNotificationBody,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'meal_decision_requests',
        lang.mealDecisionNotificationTitle,
        importance: Importance.high,
        priority: Priority.high,
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
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await showMealDecisionPush(message);
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
