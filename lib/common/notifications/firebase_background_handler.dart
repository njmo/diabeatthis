import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import '../family_chat/notifications/family_chat_push.dart';
import '../meal_advisor/notifications/meal_decision_push.dart';

@pragma('vm:entry-point')
Future<void> familyFirebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await routeFamilyFirebaseMessage(message);
}

Future<void> routeFamilyFirebaseMessage(
  RemoteMessage message, {
  Future<void> Function()? initialize,
  Future<void> Function(RemoteMessage)? chat,
  Future<void> Function(RemoteMessage)? meal,
}) async {
  if (message.data['type'] == 'familyChat') {
    await (chat ?? showFamilyChatPush)(message);
    return;
  }
  if (initialize != null) {
    await initialize();
  } else if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await (meal ?? showMealDecisionPush)(message);
}
