import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../platform/network_connection_provider.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_database_provider.dart';
import '../data/family_chat_notification_platform.dart';
import '../data/family_chat_preferences_provider.dart';
import '../data/family_chat_remote.dart';
import '../family_chat_platform.dart';
import '../notifications/family_chat_presenter_provider.dart';
import 'family_chat_background.dart';
import 'family_chat_session.dart';
import 'family_chat_settings_controller.dart';
import 'family_chat_settings_runtime.dart';

export '../data/family_chat_database_provider.dart';

/// Shared lifecycle barrier: an old UID must finish purging before reuse.
class FamilyChatRuntime extends ChangeNotifier with WidgetsBindingObserver {
  FamilyChatRuntime(this.db, {this.notificationPresenter}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final FamilyChatDatabase db;
  final FamilyChatPushPresenter? notificationPresenter;
  FamilyChatSession? _session;
  bool _identityKnown = true;
  bool _chatVisible = false;
  ModalRoute<dynamic>? _chatRoute;
  bool get conversationVisible =>
      (_chatRoute?.isCurrent ?? _chatVisible) && _foreground && _identityKnown;
  FamilyChatSession? get session => _identityKnown ? _session : null;
  String? _desiredUid;
  bool _desiredEnabled = false;
  String? _desiredScope;
  bool _disposed = false;
  bool _foreground = true;
  bool _networkConnected = false;
  bool _backendVerified = false;
  int _revision = 0;
  Future<void> _transition = Future.value();
  Future<void> _guardBarrier = Future.value();
  Future<void> _disableBackground() {
    _guardBarrier = _guardBarrier.catchError((Object _) {}).then((_) async {
      final ids = await db.deactivateChat();
      await FamilyChatNotificationPlatform.cancel(
        db,
        ids,
        keepTrying: () => !_disposed,
      );
    });
    return _guardBarrier;
  }

  Future<void> update(
    String? uid,
    bool enabled,
    FamilyChatApi? api, {
    String? scope,
  }) {
    final wasUnknown = !_identityKnown;
    _identityKnown = true;
    final scopeChanged =
        scope != null &&
        (_desiredScope != scope ||
            (_session != null && _session!.expectedScope != scope) ||
            (_session?.scope != null && _session!.scope != scope));
    if (_desiredUid == uid && _desiredEnabled == enabled && !scopeChanged) {
      if (wasUnknown) {
        final retry = Future.wait<void>([_transition, _guardBarrier]).then((
          _,
        ) async {
          if (_disposed || !_identityKnown || _desiredUid != uid) return;
          _session?.setForeground(
            _foreground && _identityKnown,
            chatVisible: _chatVisible,
          );
          await _session?.synchronize(enqueueAgain: true);
        });
        _changed();
        return Future.wait<void>([_transition, retry]).then((_) {});
      }
      final session = _session;
      if (scope != null &&
          session != null &&
          !session.serverVerified &&
          !session.busy) {
        return session.synchronize();
      }
      return _transition;
    }
    _desiredUid = uid;
    _desiredEnabled = enabled;
    _desiredScope = scope;
    final revision = ++_revision;
    final old = _session;
    final guard = _disableBackground();
    _session = null;
    final purge = old?.invalidate(preserveHistory: old.uid == uid);
    if (!_disposed) notifyListeners();
    _transition = _transition.catchError((Object _) {}).then((_) async {
      await guard;
      await purge;
      old?.removeListener(_changed);
      old?.dispose();
      if (_disposed ||
          revision != _revision ||
          uid == null ||
          !enabled ||
          api == null) {
        return;
      }
      final next = FamilyChatSession(
        uid: uid,
        api: api,
        db: db,
        expectedScope: scope,
        notificationPresenter: notificationPresenter,
        isChatVisible: () => conversationVisible,
        loadHistoryWhenHidden: false,
        isCurrentAccount: () =>
            !_disposed &&
            _identityKnown &&
            _desiredUid == uid &&
            _desiredEnabled &&
            (_desiredScope == null || _desiredScope == scope) &&
            revision == _revision,
      );
      _session = next;
      next.addListener(_changed);
      await next.start(
        foreground: _foreground && _identityKnown,
        chatVisible: _chatVisible,
      );
      if (!_disposed && revision == _revision) {
        next.setForeground(
          _foreground && _identityKnown,
          chatVisible: _chatVisible,
        );
      }
      _changed();
    });
    return _transition;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setForeground(bool value) {
    _foreground = value;
    _session?.setForeground(value && _identityKnown, chatVisible: _chatVisible);
  }

  void setNetworkConnected(bool connected) {
    final reconnect = connected && !_networkConnected;
    _networkConnected = connected;
    if (reconnect && _foreground && _identityKnown) {
      _session?.resumeQueuedSends();
    }
  }

  void setBackendVerified(bool verified) {
    final recovered = verified && !_backendVerified;
    _backendVerified = verified;
    if (recovered && _foreground && _identityKnown) {
      _session?.resumeQueuedSends();
    }
  }

  void setChatVisible(bool value) {
    if (_chatVisible == value) return;
    _chatVisible = value;
    _session?.setForeground(_foreground && _identityKnown, chatVisible: value);
  }

  void trackChatRoute(ModalRoute<dynamic> route) {
    _chatRoute = route;
    setChatVisible(route.isCurrent);
  }

  void forgetChatRoute(ModalRoute<dynamic> route) {
    if (!identical(_chatRoute, route)) return;
    _chatRoute = null;
    setChatVisible(false);
  }

  void suspendIdentity() {
    if (!_identityKnown) return;
    _identityKnown = false;
    unawaited(
      _disableBackground().catchError((Object _) {
        _changed();
      }),
    );
    _session?.suspendIdentity();
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      setForeground(state == AppLifecycleState.resumed);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _revision++;
    final old = _session;
    _session = null;
    old?.removeListener(_changed);
    old?.dispose();
    super.dispose();
  }
}

final familyChatRuntimeProvider = Provider<FamilyChatRuntime>((ref) {
  final runtime = FamilyChatRuntime(
    ref.watch(familyChatDatabaseProvider),
    notificationPresenter: supportsFamilyChat
        ? ref.watch(familyChatUiPresenterProvider)
        : null,
  );
  ref.onDispose(runtime.dispose);
  if (Firebase.apps.isEmpty) return runtime;
  ref.listen(networkConnectionProvider, (_, next) {
    final connections = next.asData?.value;
    if (connections != null) {
      runtime.setNetworkConnected(
        connections.any((connection) => connection != ConnectivityResult.none),
      );
    }
  });
  final transport = ref.watch(authenticatedFamilyTransportProvider);
  FamilyChatSettingsRuntime? settings;
  void update() {
    final account = ref.read(googleAccountProvider);
    final prefs = ref.read(sharedPrefsProvider);
    if (account.isLoading || account.hasError) {
      runtime.suspendIdentity();
      return;
    }
    final uid = account.asData?.value?.uid;
    runtime.setBackendVerified(
      uid != null &&
          settings?.controller.uid == uid &&
          settings?.controller.fresh == true &&
          settings?.controller.error == null,
    );
    if (uid == null) {
      unawaited(runtime.update(null, false, null));
      return;
    }
    if (prefs.isLoading || prefs.hasError) {
      if (runtime._desiredUid != uid) {
        unawaited(runtime.update(uid, false, null));
      } else {
        runtime.suspendIdentity();
      }
      return;
    }
    if (ref.read(initialConfigurationDoneProvider).asData?.value != true) {
      unawaited(runtime.update(uid, false, null));
      return;
    }
    final api = FamilyChatRemote(transport, uid);
    if (settings?.controller.uid == uid && settings!.allowSession) {
      final controller = settings!.controller;
      final confirmed = controller.confirmed;
      final confirmedScope = (controller.fresh && confirmed != null)
          ? jsonEncode([uid, confirmed['familyId'], confirmed['epoch']])
          : null;
      if (controller.fresh && confirmed != null) {
        if (runtime.session?.scope != null &&
            runtime.session!.scope != confirmedScope) {
          runtime.session?.reconcileConfirmedScope(confirmed);
        } else {
          runtime.session?.reconcileConfirmedHistory(confirmed);
        }
      }
      unawaited(runtime.update(uid, true, api, scope: confirmedScope));
    } else if (runtime._desiredUid != uid ||
        settings?.controller.admission == FamilyChatSettingsAdmission.revoked) {
      unawaited(runtime.update(uid, false, api));
    } else {
      runtime.suspendIdentity();
    }
  }

  void bind(FamilyChatSettingsRuntime? next) {
    settings?.removeListener(update);
    settings = next;
    settings?.addListener(update);
    scheduleMicrotask(() {
      if (ref.mounted) update();
    });
  }

  ref.listen(googleAccountProvider, (_, _) => update());
  ref.listen(sharedPrefsProvider, (_, _) => update());
  ref.listen(familyChatPreferencesProvider, (_, _) => update());
  ref.listen(initialConfigurationDoneProvider, (_, _) => update());
  ref.listen(familyChatSettingsRuntimeProvider, (_, next) => bind(next));
  bind(ref.read(familyChatSettingsRuntimeProvider));
  ref.onDispose(() => settings?.removeListener(update));
  // Do not perform a notification-producing transition during a widget build.
  scheduleMicrotask(() {
    if (ref.mounted) update();
  });
  return runtime;
});
