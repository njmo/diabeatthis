import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app_mode/application_device_mode.dart';
import '../../auth/load_firebase_callable_identity.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../meal_decision_preferences_provider.dart';
import 'meal_decision_push.dart';
import 'notification_token_serial_queue.dart';

final mealDecisionNotificationsProvider = Provider<void>((ref) {
  final enabled = ref
      .watch(mealDecisionPreferencesProvider)
      .caregiverResponsesEnabled;
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      Firebase.apps.isEmpty) {
    return;
  }
  final runtime = MealDecisionNotificationsRuntime(enabled);
  ref.onDispose(runtime.dispose);
  runtime.start();
});

class MealDecisionNotificationsRuntime {
  MealDecisionNotificationsRuntime(this.enabled);
  final bool enabled;
  static final NotificationTokenSerialQueue tokenQueue =
      NotificationTokenSerialQueue();
  final http.Client client = http.Client();
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<String>? tokenSubscription;
  StreamSubscription<RemoteMessage>? messageSubscription;
  Timer? retry;
  bool disposed = false;
  static String? lastUid;
  int generation = 0;

  void start() {
    FirebaseMessaging.onBackgroundMessage(
      mealDecisionFirebaseBackgroundHandler,
    );
    messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(showMealDecisionPush(message));
    });
    tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => scheduleRegistration(),
    );
    authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final nextUid = user?.uid;
      if (lastUid != null && lastUid != nextUid) tokenQueue.invalidate();
      lastUid = nextUid;
      generation++;
      scheduleRegistration();
    });
  }

  void scheduleRegistration() {
    final expectedGeneration = generation;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    unawaited(
      tokenQueue
          .run(
            deleteToken: FirebaseMessaging.instance.deleteToken,
            operation: () async {
              if (disposed ||
                  generation != expectedGeneration ||
                  uid == null ||
                  FirebaseAuth.instance.currentUser?.uid != uid) {
                return;
              }
              await register(uid, expectedGeneration);
            },
          )
          .catchError((Object _) {
            if (!disposed) {
              retry?.cancel();
              retry = Timer(const Duration(seconds: 30), scheduleRegistration);
            }
          }),
    );
  }

  Future<void> register(String uid, int expectedGeneration) async {
    if (disposed || generation != expectedGeneration) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final mode = await loadApplicationDeviceMode();
      final allowed = mode == ApplicationDeviceMode.patient || enabled;
      final token = await messaging.getToken();
      if (token == null) {
        throw StateError('Notification token unavailable');
      }
      if (disposed ||
          generation != expectedGeneration ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final transport = AuthenticatedCallableTransport(
        client: client,
        projectId: Firebase.app().options.projectId,
        identity: loadFirebaseCallableIdentity,
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
      );
      await transport.call('registerMealDecisionNotifications', {
        'enabled': allowed,
        'token': token,
      }, expectedUid: uid);
      retry?.cancel();
    } catch (_) {
      if (!disposed) {
        retry?.cancel();
        retry = Timer(const Duration(seconds: 30), scheduleRegistration);
      }
    }
  }

  void dispose() {
    disposed = true;
    retry?.cancel();
    unawaited(authSubscription?.cancel());
    unawaited(tokenSubscription?.cancel());
    unawaited(messageSubscription?.cancel());
    client.close();
  }
}
