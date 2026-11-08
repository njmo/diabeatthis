import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../../auth/load_firebase_callable_identity.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../../family/family_providers.dart';
import '../meal_decision_eligibility.dart';
import '../meal_decision_preferences_provider.dart';
import 'meal_decision_notification_eligibility.dart';
import 'meal_decision_push.dart';
import 'notification_token_serial_queue.dart';

final mealDecisionNotificationsProvider = Provider<void>((ref) {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      Firebase.apps.isEmpty) {
    return;
  }
  final configured = ref.watch(initialConfigurationDoneProvider).asData?.value;
  final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
  final mode = ref.watch(applicationDeviceModeProvider).asData?.value;
  final preferencesReady = ref.watch(sharedPrefsProvider).asData != null;
  final preferences = ref.watch(mealDecisionPreferencesProvider);
  if (uid == null || configured == null) return;
  var enabled = false;
  var revoke = true;
  if (configured) {
    if (mode == null || !preferencesReady) {
      // Unknown settings do not authorize delivery or token changes.
      revoke = false;
    } else {
      final paired = ref.watch(
        secureFamilyStatusProvider(uid).select(
          (value) => value.asData == null
              ? null
              : mealDecisionFamilyPaired(mode, value.asData!.value),
        ),
      );
      if (paired == null) {
        revoke = false;
      } else {
        enabled = paired && mealDecisionEnabled(mode, preferences);
      }
    }
  }
  final runtime = MealDecisionNotificationsRuntime(enabled, revoke: revoke);
  ref.onDispose(runtime.dispose);
  runtime.start();
});

class MealDecisionNotificationsRuntime {
  MealDecisionNotificationsRuntime(this.enabled, {this.revoke = true});
  final bool enabled;
  final bool revoke;
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
    if (!enabled) {
      scheduleRegistration();
      return;
    }
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
      final storage = SharedPreferencesAsync();
      await MealDecisionNotificationEligibility().set(uid, enabled);
      if (disposed ||
          generation != expectedGeneration ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      if (!enabled && !revoke) return;
      final key = 'meal_decision_registered_token:$uid';
      final token = enabled
          ? await messaging.getToken()
          : await storage.getString(key);
      if (!enabled && token == null) return;
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
        'enabled': enabled,
        'token': token,
      }, expectedUid: uid);
      if (enabled) {
        await storage.setString(key, token);
      } else {
        await storage.remove(key);
      }
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
