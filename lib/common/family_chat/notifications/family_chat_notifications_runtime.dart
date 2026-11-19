import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/providers/app_router_provider.dart';
import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/logger/logger.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../notifications/firebase_background_handler.dart';
import '../application/family_chat_background.dart';
import '../application/family_chat_runtime.dart';
import '../application/family_chat_settings_controller.dart';
import '../application/family_chat_settings_runtime.dart';
import '../application/family_treatment_consumption_recovery.dart';
import '../application/family_treatment_recovery.dart';
import '../data/family_chat_remote.dart';
import '../presentation/family_chat_page.dart';
import 'family_chat_presenter_provider.dart';
import 'family_chat_push.dart';
import 'family_chat_registration.dart';

final familyChatNotificationsProvider = Provider<void>((ref) {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      Firebase.apps.isEmpty) {
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
      final token = await FirebaseMessaging.instance.getToken();
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
  FirebaseMessaging.onBackgroundMessage(familyFirebaseBackgroundHandler);
  final tokens = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
    unawaited(register(force: true));
  });
  final messages = FirebaseMessaging.onMessage.listen((message) {
    if (message.data['type'] != 'familyChat') return;
    unawaited(() async {
      try {
        final received = await FamilyChatBackground(
          db: runtime.db,
          api: FamilyChatRemote(transport, uid),
          currentUid: () =>
              disposed ? null : FirebaseAuth.instance.currentUser?.uid,
          presenter: presenter,
          shouldPresent: (target) =>
              !(runtime.conversationVisible &&
                  runtime.session?.visibleTarget == target),
        ).receive(Map<String, dynamic>.from(message.data));
        if (!received) {
          Log.d('FamilyChatPush', 'Foreground push was not accepted');
        }
      } catch (error) {
        Log.w(
          'FamilyChatPush',
          'Foreground delivery failed (${error.runtimeType})',
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
    if (!mounted ||
        _cleaning ||
        Firebase.apps.isEmpty ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
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
      final intent = await runtime.db.metadata('chatOpen');
      if (intent == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != session!.uid ||
          intent['uid'] != uid ||
          intent['scope'] != session.scope) {
        await runtime.db.customStatement(
          "DELETE FROM chat_metadata WHERE key='chatOpen'",
        );
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
          !await runtime.db.historyAllows(scope, generation)) {
        await runtime.db.customStatement(
          "DELETE FROM chat_metadata WHERE key='chatOpen'",
        );
        return;
      }
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
      final validMessage =
          message?['id'] == id &&
          (message?['historyGeneration'] ?? 0) == generation &&
          participants?[uid] == session.config?['epoch'] &&
          (message?['expiresAt'] == null ||
              (message!['expiresAt'] as int) > session.serverNow) &&
          await runtime.db.historyAllows(scope, generation);
      final target = !validMessage
          ? null
          : message!['conversationId'] == 'family'
          ? 'family'
          : participants!.keys
                .whereType<String>()
                .where((id) => id != uid)
                .singleOrNull;
      if (target == null) {
        await runtime.db.customStatement(
          "DELETE FROM chat_metadata WHERE key='chatOpen'",
        );
        return;
      }
      final navigator = ref.read(appRouterProvider).navigatorKey.currentState;
      if (navigator == null) {
        _retry?.cancel();
        _retry = Timer(const Duration(milliseconds: 250), _changed);
        return;
      }
      if (jsonEncode(await runtime.db.metadata('chatOpen')) ==
          jsonEncode(intent)) {
        await runtime.db.customStatement(
          "DELETE FROM chat_metadata WHERE key='chatOpen'",
        );
      }
      if (mounted && session.enabled && runtime.session == session) {
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
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        Firebase.apps.isNotEmpty &&
        _auth == null) {
      _auth = FirebaseAuth.instance.authStateChanges().listen((_) {
        unawaited(_cleanup());
      });
      scheduleMicrotask(() {
        unawaited(_cleanup());
      });
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        Firebase.apps.isNotEmpty) {
      ref.watch(familyChatNotificationsProvider);
      ref.watch(familyChatSettingsRuntimeProvider);
      ref.watch(familyTreatmentRecoveryProvider);
      ref.watch(familyTreatmentConsumptionRecoveryProvider);
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
    _runtime?.removeListener(_changed);
    _retry?.cancel();
    unawaited(_opens?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
