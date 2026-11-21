import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../features/low_treatment/data/repositories/family_treatment_journal.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../family/family_status.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_database_provider.dart';
import '../data/family_chat_preferences_provider.dart';
import '../data/family_chat_remote.dart';
import '../data/family_chat_settings_store.dart';
import '../domain/family_chat_preferences.dart';
import '../family_chat_platform.dart';
import 'family_chat_settings_controller.dart';
import 'family_chat_settings_local_gate.dart';

class FamilyChatSettingsRuntime extends ChangeNotifier {
  FamilyChatSettingsRuntime({
    required this.controller,
    required this.db,
    required this.currentUid,
    required this.configured,
    required this.draft,
    this.observeLifecycle = true,
    this.clock = DateTime.now,
  }) {
    controller.addListener(_changed);
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(pump()));
      _timer = Timer.periodic(statusFreshness, (_) {
        final last = _lastPumpAt;
        // Status- or resume-driven pumps already refreshed recently.
        if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            (last == null || clock().difference(last) >= statusFreshness)) {
          unawaited(pump());
        }
      });
    }
  }
  final FamilyChatSettingsController controller;
  final FamilyChatDatabase db;
  final String? Function() currentUid;
  final bool observeLifecycle;
  final DateTime Function() clock;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool configured, _disposed = false, _cached = false, _migrating = false;
  bool _accountDraftChecked = false;
  bool _scopeNeedsVerification = false;
  int _configurationGeneration = 0;
  // Joiners of an in-flight migration get its real issued result.
  Completer<bool>? _migrationDone;
  FamilyChatPreferences draft;
  int _revision = 0;
  Future<void>? _starting;
  bool get _current => !_disposed && currentUid() == controller.uid;
  bool get allowSession =>
      _current &&
      configured &&
      !_scopeNeedsVerification &&
      _accountDraftChecked &&
      (controller.readyForRuntime || _cached);
  bool get cachedOnly => allowSession && !controller.readyForRuntime;

  void setConfigured(bool value) {
    if (configured == value) return;
    _configurationGeneration++;
    final wasConfigured = configured;
    configured = value;
    if (!wasConfigured && value) {
      _scopeNeedsVerification = true;
      unawaited(_verifyConfiguredScope());
    }
    _changed();
  }

  Future<void> _verifyConfiguredScope() async {
    final generation = _configurationGeneration;
    await controller.synchronize();
    if (!_current || !configured || generation != _configurationGeneration) {
      return;
    }
    controller.requireFreshScope();
    await controller.synchronize();
    if (_current &&
        configured &&
        generation == _configurationGeneration &&
        controller.fresh) {
      _scopeNeedsVerification = false;
      _changed();
    }
  }

  void setDraft(FamilyChatPreferences value) {
    draft = value;
    _accountDraftChecked = false;
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    if (!_current || !configured || !controller.mayUseCachedRead) {
      _cached = false;
    }
    notifyListeners();
    final revision = ++_revision;
    unawaited(_checkCache(revision));
    unawaited(_migrateDraft());
  }

  Future<void> start() {
    if (_starting != null) return _starting!;
    _starting = controller.start().catchError((Object _) {}).whenComplete(() {
      _starting = null;
      _changed();
    });
    return _starting!;
  }

  /// Unchanged family-status emissions (about every 3 s) re-check settings at
  /// most this often, so a remote account OFF or settings change made without
  /// a membership change is still observed within a bounded delay.
  static const statusFreshness = Duration(seconds: 30);
  bool _statusSeen = false;
  String? _statusFingerprint;
  DateTime? _lastPumpAt;
  Future<void>? _statusPump;
  bool _statusPumpAgain = false;

  /// Stable fingerprint of what the chat settings depend on in a status.
  static String? statusFingerprint(FamilyStatus? status) => status == null
      ? null
      : jsonEncode([
          [
            for (final member in status.members)
              [
                member.id,
                member.role.name,
                member.invitationId,
                member.canDisconnect,
              ],
          ],
          status.pending?.id,
          status.canLeave,
          status.joinState,
          status.invitationState,
          status.activeInvitationId,
          status.activeInvitationRevision,
        ]);

  /// Entry point for the family-status subscription. A changed fingerprint
  /// (membership/account change) pumps immediately, queued once behind an
  /// in-flight pump; an unchanged one joins the in-flight pump or is skipped
  /// until [statusFreshness] has passed since the last pump. Explicit pumps,
  /// lifecycle resume and settings commands never wait behind this throttle.
  Future<void> statusChanged(FamilyStatus? status) {
    final fingerprint = statusFingerprint(status);
    final changed = !_statusSeen || fingerprint != _statusFingerprint;
    _statusSeen = true;
    _statusFingerprint = fingerprint;
    final running = _statusPump;
    if (running != null) {
      if (changed) _statusPumpAgain = true;
      return running;
    }
    final last = _lastPumpAt;
    if (!changed &&
        last != null &&
        clock().difference(last) < statusFreshness) {
      return Future.value();
    }
    final pumping = () async {
      try {
        do {
          _statusPumpAgain = false;
          await pump();
        } while (_statusPumpAgain && _current);
      } finally {
        _statusPump = null;
      }
    }();
    // `await pump()` always yields first, so this runs before `finally`.
    return _statusPump = pumping;
  }

  Future<void> pump() async {
    if (!_current) return;
    _lastPumpAt = clock();
    if (!controller.initialized) {
      await start();
      return;
    }
    if (_scopeNeedsVerification) {
      await _verifyConfiguredScope();
      if (_scopeNeedsVerification) return;
    }
    await controller.synchronize();
    _changed();
    // Only a migration that issued a settings command needs another pass;
    // an unchanged draft must not double every config fetch.
    if (await _migrateDraft()) await controller.synchronize();
  }

  Future<void> _checkCache(int revision) async {
    if (!_current || !configured || !controller.mayUseCachedRead) return;
    var allowed = false;
    try {
      final confirmed = controller.confirmed;
      final cached = await db.metadata('account:${controller.uid}');
      final token = await db.fence.accountRevocation(controller.uid);
      if (confirmed != null &&
          cached != null &&
          token == null &&
          cached['uid'] == controller.uid &&
          cached['familyId'] == confirmed['familyId'] &&
          cached['epoch'] == confirmed['epoch'] &&
          (cached['historyGeneration'] as int? ?? 0) >=
              (confirmed['historyGeneration'] as int? ?? 0) &&
          cached['_observedLocalAt'] is int &&
          clock().millisecondsSinceEpoch >= cached['_observedLocalAt'] &&
          cached['_lastServerNow'] is int &&
          ['account', 'policy'].every(
            (section) =>
                cached[section]?['enabled'] == true &&
                confirmed[section]?['enabled'] == true &&
                ['revision', 'offGeneration'].every(
                  (key) => cached[section]?[key] == confirmed[section]?[key],
                ),
          )) {
        allowed = true;
      }
    } catch (_) {
      /* Uncertain local state stays hidden. */
    }
    if (!_current || revision != _revision || !controller.mayUseCachedRead) {
      return;
    }
    if (_cached != allowed) {
      _cached = allowed;
      notifyListeners();
    }
  }

  /// Completes with whether a settings command was issued.
  Future<bool> _migrateDraft() async {
    if (_migrating) return _migrationDone!.future;
    if (!_current ||
        !configured ||
        !controller.initialized ||
        !draft.setupCommitted) {
      return false;
    }
    _migrating = true;
    var issued = false;
    final done = Completer<bool>();
    _migrationDone = done;
    final currentDraft = draft;
    String draftId(FamilyChatPreferences value) =>
        value.changeId ?? 'legacy:${value.enabled}:${value.retention.name}';
    final id = draftId(currentDraft);
    try {
      var state = await controller.store.read(controller.uid);
      if (!_current) return issued;
      if (state['accountDraft'] != id) {
        if (currentDraft.accountExplicit) {
          if (currentDraft.enabled && !controller.canRequestEnable) {
            return issued;
          }
          await controller.setAccountEnabled(currentDraft.enabled);
          issued = true;
        }
        if (!_current) return issued;
        await controller.store.update(controller.uid, (value) {
          value['accountDraft'] = id;
        });
      }
      if (_current && draft.setupCommitted && draftId(draft) == id) {
        _accountDraftChecked = true;
        notifyListeners();
      }
      if (!controller.fresh) return issued;
      state = await controller.store.read(controller.uid);
      if (!_current) return issued;
      final config = controller.confirmed!;
      final policyId = '${config['familyId']}:${config['epoch']}:$id';
      if (state['policyDraft'] == policyId) return issued;
      if (config['policyConfigured'] != true && state['policy'] == null) {
        if (config['canInitialize'] == true) {
          await controller.initializeFounder(currentDraft.retention);
          issued = true;
        } else if (config['canManage'] == true &&
            currentDraft.retentionExplicit) {
          await controller.setFamilyPolicy(retention: currentDraft.retention);
          issued = true;
        }
      }
      if (_current &&
          controller.confirmed?['familyId'] == config['familyId'] &&
          controller.confirmed?['epoch'] == config['epoch']) {
        await controller.store.update(controller.uid, (value) {
          value['policyDraft'] = policyId;
        });
      }
    } catch (_) {
      /* Durable commands and the setup draft survive retry. */
    } finally {
      _migrating = false;
      done.complete(issued);
      if (_current && draftId(draft) != id) scheduleMicrotask(_changed);
    }
    return issued;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle?.dispose();
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }
}

final familyChatSettingsRuntimeProvider = Provider<FamilyChatSettingsRuntime?>((
  ref,
) {
  if (!supportsFamilyChat || Firebase.apps.isEmpty) {
    return null;
  }
  final account = ref.watch(googleAccountProvider);
  final uid = account.asData?.value?.uid;
  if (account.isLoading || account.hasError || uid == null) return null;
  final prefs = ref.watch(sharedPrefsProvider);
  if (prefs.isLoading || prefs.hasError || prefs.asData == null) return null;
  String? currentUid() =>
      ref.mounted && FirebaseAuth.instance.currentUser?.uid == uid ? uid : null;
  final db = ref.watch(familyChatDatabaseProvider);
  final store = FamilyChatSettingsStore(db);
  final medical = ref.watch(databaseProvider);
  late final FamilyChatSettingsController controller;
  final gate = FamilyChatSettingsLocalGate(
    uid: uid,
    db: db,
    store: store,
    currentUid: currentUid,
    controller: () => controller,
    cancelClinical: FamilyTreatmentJournal(medical).cancelUnapplied,
  );
  controller = FamilyChatSettingsController(
    uid: uid,
    api: FamilyChatRemote(ref.watch(authenticatedFamilyTransportProvider), uid),
    store: store,
    currentUid: currentUid,
    applyLocal: gate.apply,
    closeAdmission: gate.closeAdmission,
    readRevocation: () => db.fence.accountRevocation(uid),
  );
  final runtime = FamilyChatSettingsRuntime(
    controller: controller,
    db: db,
    currentUid: currentUid,
    configured:
        ref.read(initialConfigurationDoneProvider).asData?.value == true,
    draft: ref.read(familyChatPreferencesProvider),
  );
  ref.onDispose(runtime.dispose);
  ref.listen(
    initialConfigurationDoneProvider,
    (_, value) => runtime.setConfigured(value.asData?.value == true),
  );
  ref.listen(
    familyChatPreferencesProvider,
    (_, value) => runtime.setDraft(value),
  );
  // Repeated unchanged emissions are coalesced by statusChanged.
  ref.listen(secureFamilyStatusProvider(uid), (_, next) {
    unawaited(runtime.statusChanged(next.asData?.value));
  });
  scheduleMicrotask(() {
    if (ref.mounted) unawaited(runtime.start());
  });
  return runtime;
});
