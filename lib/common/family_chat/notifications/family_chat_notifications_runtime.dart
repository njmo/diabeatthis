import 'dart:async';
import 'dart:convert';

import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../../../app/router/providers/app_router_provider.dart';
import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/logger/logger.dart';
import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../notifications/firebase_background_handler.dart';
import '../application/family_chat_background.dart';
import '../application/family_chat_runtime.dart';
import '../application/family_chat_settings_controller.dart';
import '../application/family_chat_settings_runtime.dart';
import '../application/family_treatment_aaps_handoff.dart';
import '../application/family_treatment_adapter.dart';
import '../application/family_treatment_consumption_recovery.dart';
import '../application/family_treatment_recovery.dart';
import '../data/family_chat_remote.dart';
import '../family_chat_platform.dart';
import '../presentation/family_chat_page.dart';
import '../presentation/family_treatment_aaps_review.dart';
import '../../meal_advisor/notifications/meal_decision_notification_intent.dart';
import 'family_chat_presenter_provider.dart';
import 'family_chat_push.dart';
import 'family_chat_registration.dart';

final familyChatNotificationsProvider = Provider<void>((ref) {
  if (!supportsFamilyChat || Firebase.apps.isEmpty) {
    return;
  }
  if (ref.watch(initialConfigurationDoneProvider).asData?.value != true) return;
  final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
  if (uid == null) return;
  final settings = ref.watch(familyChatSettingsRuntimeProvider);
  bool wantsEnabled() =>
      settings?.allowSession == true && settings?.cachedOnly == false;
  final runtime = ref.watch(familyChatRuntimeProvider);
  final transport = ref.watch(authenticatedFamilyTransportProvider);
  final presenter = ref.watch(familyChatUiPresenterProvider);
  var disposed = false, running = false, again = false;
  String? lastKey, lastRegistration;
  Timer? retry;
  Future<void> register({bool force = false}) async {
    if (disposed) return;
    if (running) {
      again = true;
      return;
    }
    running = true;
    try {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      if (settings == null ||
          !wantsEnabled() &&
              settings.controller.admission !=
                  FamilyChatSettingsAdmission.revoked) {
        return;
      }
      final session = runtime.session;
      if (wantsEnabled() && session?.enabled != true) return;
      final guard = await runtime.db.activeChat();
      final enabled =
          wantsEnabled() &&
          guard['enabled'] == true &&
          guard['uid'] == uid &&
          guard['scope'] == session?.scope;
      if (wantsEnabled() && !enabled) return;
      final messaging = FirebaseMessaging.instance;
      if (isCaregiverOnlyPlatform) {
        if (enabled) {
          final current = await messaging.getNotificationSettings();
          final permissions =
              current.authorizationStatus == AuthorizationStatus.notDetermined
              ? await messaging.requestPermission()
              : current;
          if (permissions.authorizationStatus == AuthorizationStatus.denied) {
            return;
          }
        }
        if (await messaging.getAPNSToken() == null) {
          throw StateError('APNs token is still unavailable');
        }
      }
      if (disposed || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final token = await messaging.getToken();
      if (token == null ||
          disposed ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final key = jsonEncode([uid, enabled, session?.scope, token]);
      if (!force && key == lastKey) {
        final registration = lastRegistration;
        if (!enabled ||
            registration != null &&
                (await runtime.db.metadata(registration))?['confirmed'] ==
                    true) {
          return;
        }
      }
      final sequence = await runtime.db.fence.nextRegistration();
      if (disposed || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final registration = {
        'enabled': enabled,
        'token': token,
        ...sequence,
        'revocationToken': familyChatRevocationToken(),
      };
      final journal = FamilyChatRegistrationJournal(runtime.db);
      final prepared = enabled
          ? await journal.prepare(uid, session!.scope!, registration)
          : null;
      if (disposed || FirebaseAuth.instance.currentUser?.uid != uid) return;
      await FamilyChatRemote(
        transport,
        uid,
      ).call('registerFamilyChatNotifications', registration);
      if (prepared != null) await journal.confirm(prepared);
      if (!disposed) {
        lastKey = key;
        lastRegistration = prepared;
        retry?.cancel();
      }
    } catch (error) {
      Log.w('FamilyChatPush', 'Registration failed (${error.runtimeType})');
      if (!disposed) {
        retry?.cancel();
        retry = Timer(const Duration(seconds: 30), () {
          unawaited(register(force: true));
        });
      }
    } finally {
      running = false;
      if (again && !disposed) {
        again = false;
        unawaited(register());
      }
    }
  }

  void changed() {
    unawaited(register());
  }

  runtime.addListener(changed);
  settings?.addListener(changed);
  final appleLifecycle = isCaregiverOnlyPlatform
      ? AppLifecycleListener(onResume: changed)
      : null;
  if (!isCaregiverOnlyPlatform) {
    FirebaseMessaging.onBackgroundMessage(familyFirebaseBackgroundHandler);
  }
  final tokens = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
    unawaited(register(force: true));
  });
  final messages = FirebaseMessaging.onMessage.listen((message) {
    if (message.data['type'] != 'familyChat') return;
    Log.d('FamilyChatPush', 'Foreground chat push received');
    unawaited(() async {
      try {
        final received = await FamilyChatBackground(
          db: runtime.db,
          api: FamilyChatRemote(transport, uid),
          currentUid: () =>
              disposed ? null : FirebaseAuth.instance.currentUser?.uid,
          presenter: presenter,
          shouldPresent: (_) => !runtime.conversationVisible,
        ).receive(Map<String, dynamic>.from(message.data));
        if (!received) {
          Log.d('FamilyChatPush', 'Foreground push was not accepted');
        }
      } catch (error, stackTrace) {
        final cause = error is DriftRemoteException ? error.remoteCause : error;
        final sqliteCode = cause is SqliteException
            ? ', SQLite code ${cause.extendedResultCode}'
            : '';
        // Exception messages can include SQL arguments with chat data.
        final chatFrames = RegExp(
          r'package:[\w]+/common/family_chat/[\w/]+\.dart:\d+:\d+',
        ).allMatches(stackTrace.toString()).take(4).map((m) => m[0]).join(' ');
        Log.w(
          'FamilyChatPush',
          'Foreground delivery failed (${error.runtimeType}, '
              'cause ${cause.runtimeType}$sqliteCode) $chatFrames',
        );
      }
      if (!disposed) await runtime.session?.synchronize(enqueueAgain: true);
    }());
  });
  // Queued replies and ACKs are retried by the session's single bounded retry
  // lifecycle; a second periodic full sync here would spin on terminal rows.
  ref.onDispose(() {
    disposed = true;
    retry?.cancel();
    appleLifecycle?.dispose();
    runtime.removeListener(changed);
    settings?.removeListener(changed);
    unawaited(tokens.cancel());
    unawaited(messages.cancel());
  });
  scheduleMicrotask(changed);
});

class FamilyChatNotificationRuntime extends ConsumerStatefulWidget {
  const FamilyChatNotificationRuntime({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<FamilyChatNotificationRuntime> createState() =>
      _FamilyChatNotificationRuntimeState();
}

class _FamilyChatNotificationRuntimeState
    extends ConsumerState<FamilyChatNotificationRuntime>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _opens;
  FamilyChatRuntime? _runtime;
  Timer? _retry;
  bool _routing = false, _checkedLaunch = false;
  bool _routeAgain = false;
  bool _cleaning = false;
  StreamSubscription<User?>? _auth;
  StreamSubscription<RemoteMessage>? _remoteOpens;
  Map<String, dynamic>? _pendingRemoteOpen;

  void _handleRemoteOpen(RemoteMessage message) {
    if (!mounted) return;
    if (message.data['type'] != 'familyChat') {
      final id = message.data['requestId'];
      if (message.data.length == 1 &&
          id is String &&
          RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
        unawaited(
          MealDecisionNotificationIntentStore().add(
            MealDecisionNotificationIntent(id, 'open'),
          ),
        );
      }
      return;
    }
    final recipient = message.data['uid'];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (recipient is! String || (uid != null && recipient != uid)) return;
    _pendingRemoteOpen = message.data;
    unawaited(_drain());
  }

  Future<void> _checkInitialRemoteOpen() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) _handleRemoteOpen(message);
    } catch (error) {
      Log.w(
        'FamilyChatPush',
        'Remote launch check failed (${error.runtimeType})',
      );
    }
  }

  Timer? _cleanupRetry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _opens = familyChatOpenEvents.stream.listen((_) {
      unawaited(_drain());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_drain());
  }

  void _changed() {
    unawaited(_drain());
    unawaited(_cleanup());
  }

  Future<void> _cleanup() async {
    if (!mounted || _cleaning || Firebase.apps.isEmpty || !supportsFamilyChat) {
      return;
    }
    _cleaning = true;
    try {
      final db = ref.read(familyChatDatabaseProvider);
      final settings = ref.read(familyChatSettingsRuntimeProvider);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // Temporary admission holds close local delivery, but the same account
      // can still receive an FCM wake-up with identifiers only.
      final retainRegistration =
          ref.read(initialConfigurationDoneProvider).asData?.value == true &&
          settings?.controller.admission != FamilyChatSettingsAdmission.revoked;
      final active = await db.activeChat();
      await FamilyChatRegistrationJournal(db).revokeObsolete(
        currentUid: uid,
        enabled: retainRegistration,
        currentScope: active['enabled'] == true
            ? active['scope'] as String?
            : null,
        revoke: revokeFamilyChatDevice,
      );
    } catch (_) {
      /* Durable capabilities remain available for a later retry. */
    } finally {
      _cleaning = false;
      if (mounted) {
        _cleanupRetry?.cancel();
        _cleanupRetry = Timer(const Duration(seconds: 10), () {
          unawaited(_cleanup());
        });
      }
    }
  }

  Future<void> _drain() async {
    if (_routing) {
      _routeAgain = true;
      return;
    }
    if (!mounted ||
        _routing ||
        Firebase.apps.isEmpty ||
        ref.read(initialConfigurationDoneProvider).asData?.value != true) {
      return;
    }
    final runtime = _runtime, session = _runtime?.session;
    if (runtime == null || session?.enabled != true) return;
    _routing = true;
    try {
      if (!_checkedLaunch) {
        _checkedLaunch = true;
        final launch = await FlutterLocalNotificationsPlugin()
            .getNotificationAppLaunchDetails();
        final response = launch?.notificationResponse;
        if (launch?.didNotificationLaunchApp == true &&
            response != null &&
            familyChatNotificationPayload(response.payload) != null) {
          await handleFamilyChatNotificationResponse(response);
        }
      }
      var remoteOpen = _pendingRemoteOpen;
      final recipient = FirebaseAuth.instance.currentUser?.uid;
      if (remoteOpen != null &&
          (remoteOpen['uid'] != recipient ||
              session!.scope !=
                  jsonEncode([
                    recipient,
                    remoteOpen['familyId'],
                    remoteOpen['epoch'],
                  ]))) {
        _pendingRemoteOpen = null;
        remoteOpen = null;
      }
      final intent = remoteOpen == null
          ? await runtime.db.metadata('chatOpen')
          : {...remoteOpen, 'scope': session!.scope};
      if (intent == null) return;
      Future<void> clearIntent() async {
        if (remoteOpen != null) {
          if (identical(_pendingRemoteOpen, remoteOpen)) {
            _pendingRemoteOpen = null;
          }
          return;
        }
        await runtime.db.customStatement(
          "DELETE FROM chat_metadata WHERE key='chatOpen' AND value=?",
          [jsonEncode(intent)],
        );
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != session!.uid ||
          intent['uid'] != uid ||
          intent['scope'] != session.scope) {
        await clearIntent();
        return;
      }
      final scope = session.scope!;
      final guard = await runtime.db.activeChat();
      if (guard['enabled'] != true ||
          guard['uid'] != uid ||
          guard['scope'] != scope) {
        return;
      }
      final id = intent['messageId'];
      final generation = intent['historyGeneration'] ?? 0;
      if (id is! String ||
          generation is! int ||
          (remoteOpen == null &&
              !await runtime.db.historyAllows(scope, generation))) {
        await clearIntent();
        return;
      }
      if (intent['reviewAaps'] == true) {
        if (session.isCaregiver || intent['stamp'] != guard['stamp']) {
          await clearIntent();
          return;
        }
        bool isForeground() =>
            mounted &&
            session.enabled &&
            runtime.session == session &&
            FirebaseAuth.instance.currentUser?.uid == uid &&
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        if (!isForeground()) return;
        final navigator = ref.read(appRouterProvider).navigatorKey.currentState;
        if (navigator == null) {
          _retry?.cancel();
          _retry = Timer(const Duration(milliseconds: 250), _changed);
          return;
        }
        final handoff = ref.read(familyTreatmentAapsHandoffProvider);
        final subscription = ref.listenManual(
          familyTreatmentExecutorProvider(session),
          (_, _) {},
        );
        try {
          final handled = await handoff.open(
            executor: subscription.read(),
            messageId: id,
            confirm: (pending) =>
                showFamilyTreatmentAapsReview(navigator.context, pending),
            isCurrent: () async {
              final active = await runtime.db.activeChat();
              final current = await runtime.db.metadata('chatOpen');
              return active['enabled'] == true &&
                  active['uid'] == uid &&
                  active['scope'] == scope &&
                  active['stamp'] == guard['stamp'] &&
                  current?['intentId'] == intent['intentId'] &&
                  isForeground();
            },
          );
          if (handled) await clearIntent();
        } finally {
          subscription.close();
        }
        return;
      }
      // A just-queued outgoing request can still be in the local outbox
      // when its confirmation banner is tapped.
      var target = remoteOpen == null && session.isCaregiver
          ? session.targets
                .where(
                  (target) => session
                      .messages(target)
                      .any(
                        (message) =>
                            message['id'] == id &&
                            message['kind'] == 'lowTreatment' &&
                            message['senderUid'] == uid &&
                            message['operationSigned'] == true,
                      ),
                )
                .firstOrNull
          : null;
      if (target == null) {
        var message = await runtime.db.message(scope, id);
        if (message == null) {
          final result =
              await FamilyChatRemote(
                ref.read(authenticatedFamilyTransportProvider),
                uid!,
              ).call('fetchFamilyChatMessageStates', {
                'ids': [id],
              });
          final rows = result['messages'] as List;
          if (rows.length == 1) {
            message = Map<String, dynamic>.from(rows.single as Map);
          }
        }
        if (!mounted || runtime.session != session || !session.enabled) return;
        final participants = message?['participants'] as Map?;
        final messageGeneration = message?['historyGeneration'] ?? 0;
        final validMessage =
            message?['id'] == id &&
            messageGeneration is int &&
            (remoteOpen != null || messageGeneration == generation) &&
            participants?[uid] == session.config?['epoch'] &&
            (message?['expiresAt'] == null ||
                (message!['expiresAt'] as int) > session.serverNow) &&
            await runtime.db.historyAllows(scope, messageGeneration);
        target = !validMessage
            ? null
            : message!['conversationId'] == 'family'
            ? 'family'
            : participants!.keys
                  .whereType<String>()
                  .where((id) => id != uid)
                  .singleOrNull;
      }
      if (target == null) {
        await clearIntent();
        return;
      }
      if (remoteOpen != null && !session.targets.contains(target)) {
        await session.synchronize(enqueueAgain: true);
        if (!mounted ||
            runtime.session != session ||
            !session.enabled ||
            session.scope != scope ||
            FirebaseAuth.instance.currentUser?.uid != uid) {
          return;
        }
        if (!session.targets.contains(target)) {
          await clearIntent();
          return;
        }
      }
      final navigator = ref.read(appRouterProvider).navigatorKey.currentState;
      if (navigator == null) {
        _retry?.cancel();
        _retry = Timer(const Duration(milliseconds: 250), _changed);
        return;
      }
      if (remoteOpen != null ||
          jsonEncode(await runtime.db.metadata('chatOpen')) ==
              jsonEncode(intent)) {
        await clearIntent();
      }
      if (mounted &&
          session.enabled &&
          runtime.session == session &&
          session.scope == scope &&
          FirebaseAuth.instance.currentUser?.uid == uid) {
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => FamilyChatPage(initialTarget: target),
            ),
          ),
        );
      }
    } catch (error) {
      Log.w(
        'FamilyChatPush',
        'Conversation routing failed (${error.runtimeType})',
      );
      if (mounted) {
        _retry?.cancel();
        _retry = Timer(const Duration(seconds: 3), _changed);
      }
    } finally {
      _routing = false;
      if (_routeAgain && mounted) {
        _routeAgain = false;
        scheduleMicrotask(() {
          unawaited(_drain());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (supportsFamilyChat && Firebase.apps.isNotEmpty && _auth == null) {
      _auth = FirebaseAuth.instance.authStateChanges().listen((_) {
        unawaited(_cleanup());
      });
      if (isCaregiverOnlyPlatform) {
        _remoteOpens = FirebaseMessaging.onMessageOpenedApp.listen(
          _handleRemoteOpen,
        );
        unawaited(_checkInitialRemoteOpen());
      }
      scheduleMicrotask(() {
        unawaited(_cleanup());
      });
    }
    if (supportsFamilyChat && Firebase.apps.isNotEmpty) {
      ref.watch(familyChatNotificationsProvider);
      ref.watch(familyChatSettingsRuntimeProvider);
      if (!isCaregiverOnlyPlatform) {
        ref.watch(familyTreatmentRecoveryProvider);
        ref.watch(familyTreatmentConsumptionRecoveryProvider);
      }
      final runtime = ref.watch(familyChatRuntimeProvider);
      if (_runtime != runtime) {
        _runtime?.removeListener(_changed);
        _runtime = runtime;
        runtime.addListener(_changed);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_drain());
      });
    }
    return widget.child;
  }

  @override
  void dispose() {
    _cleanupRetry?.cancel();
    unawaited(_auth?.cancel());
    unawaited(_remoteOpens?.cancel());
    _runtime?.removeListener(_changed);
    _retry?.cancel();
    unawaited(_opens?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
