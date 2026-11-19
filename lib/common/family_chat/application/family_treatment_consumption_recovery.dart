import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/google_authentication_providers.dart';
import 'confirm_family_treatment.dart';
import 'family_chat_runtime.dart';
import 'family_chat_settings_runtime.dart';
import 'family_treatment_adapter.dart';

/// A foreground retry budget, independent from the already-committed ACK lane.
class FamilyTreatmentConsumptionBudget {
  FamilyTreatmentConsumptionBudget({int Function()? elapsedMilliseconds}) {
    final watch = Stopwatch()..start();
    _elapsed = elapsedMilliseconds ?? () => watch.elapsedMilliseconds;
  }
  late final int Function() _elapsed;
  int? _lastAttempt;
  Future<void>? _running;
}

class FamilyTreatmentConsumptionWorker {
  FamilyTreatmentConsumptionWorker({
    required this.ready,
    required this.recover,
    int Function()? elapsedMilliseconds,
    FamilyTreatmentConsumptionBudget? budget,
  }) : _budget =
           budget ??
           FamilyTreatmentConsumptionBudget(
             elapsedMilliseconds: elapsedMilliseconds,
           );
  final bool Function() ready;
  final Future<void> Function() recover;
  final FamilyTreatmentConsumptionBudget _budget;
  bool _disposed = false;

  Future<void> pump() {
    if (_disposed || !ready()) return Future.value();
    if (_budget._running != null) return _budget._running!;
    final time = _budget._elapsed();
    if (_budget._lastAttempt != null && time - _budget._lastAttempt! < 30000) {
      return Future.value();
    }
    _budget._lastAttempt = time;
    final done = Completer<void>();
    _budget._running = done.future;
    unawaited(_run(done));
    return done.future;
  }

  Future<void> _run(Completer<void> done) async {
    try {
      if (!_disposed && ready()) await recover();
    } catch (_) {
      /* Durable intentions remain available on the next attempt. */
    } finally {
      _budget._running = null;
      done.complete();
    }
  }

  void dispose() {
    _disposed = true;
  }
}

// Independent of account/settings rebuilds. Minimal in-memory UID budgets keep
// old in-flight work and its monotonic clock shared with its replacement.
final familyTreatmentConsumptionBudgetsProvider = Provider(
  (ref) => <String, FamilyTreatmentConsumptionBudget>{},
);

final familyTreatmentConsumptionRecoveryProvider = Provider<void>((ref) {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      Firebase.apps.isEmpty) {
    return;
  }
  final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
  if (uid == null) return;
  final runtime = ref.watch(familyChatRuntimeProvider);
  final settings = ref.watch(familyChatSettingsRuntimeProvider);
  final budgets = ref.watch(familyTreatmentConsumptionBudgetsProvider);
  final budget = budgets.putIfAbsent(uid, FamilyTreatmentConsumptionBudget.new);
  var disposed = false;
  bool ready() {
    final session = runtime.session;
    return !disposed &&
        ref.mounted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        FirebaseAuth.instance.currentUser?.uid == uid &&
        settings?.allowSession == true &&
        settings?.cachedOnly == false &&
        session?.uid == uid &&
        session?.serverVerified == true &&
        (session?.config?['members'] as List? ?? []).any(
          (member) => member['uid'] == uid && member['role'] == 'child',
        );
  }

  final worker = FamilyTreatmentConsumptionWorker(
    budget: budget,
    ready: ready,
    recover: () async {
      final session = runtime.session;
      if (!ready() || session == null) return;
      final scope = session.scope;
      bool admitted() =>
          ready() &&
          identical(runtime.session, session) &&
          session.scope == scope;
      // Keep the executor's auto-disposed Ref/clinical dependencies alive until
      // completion, while disposal still closes its authorization checks.
      final subscription = ref.listen(
        familyTreatmentExecutorProvider(session),
        (_, _) {},
      );
      try {
        await recoverFamilyTreatmentConsumptions(
          executor: subscription.read(),
          admitted: admitted,
        );
      } finally {
        subscription.close();
      }
    },
  );
  void changed() => unawaited(worker.pump());
  runtime.addListener(changed);
  settings?.addListener(changed);
  final lifecycle = AppLifecycleListener(onResume: changed);
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => changed());
  ref.onDispose(() {
    disposed = true;
    worker.dispose();
    timer.cancel();
    lifecycle.dispose();
    runtime.removeListener(changed);
    settings?.removeListener(changed);
  });
  scheduleMicrotask(changed);
});
