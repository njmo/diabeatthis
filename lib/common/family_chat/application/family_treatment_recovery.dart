import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/providers/database_provider.dart';
import '../../../features/low_treatment/data/repositories/family_treatment_journal.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../data/family_chat_remote.dart';
import 'confirm_family_treatment.dart';

/// This lane finalizes only already committed clinical records. It deliberately
/// survives chat OFF/unlink and never claims or saves an unapplied intention.
final familyTreatmentRecoveryProvider = Provider<void>((ref) {
  if (kIsWeb || Firebase.apps.isEmpty) return;
  final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
  if (uid == null) return;
  final journal = FamilyTreatmentJournal(ref.watch(databaseProvider));
  final api = FamilyChatRemote(
    ref.watch(authenticatedFamilyTransportProvider),
    uid,
  );
  var disposed = false, running = false;
  bool current() => !disposed && FirebaseAuth.instance.currentUser?.uid == uid;
  Future<void> recover() async {
    if (!current() || running) return;
    running = true;
    try {
      await recoverFamilyTreatmentAcknowledgements(
        journal: journal,
        api: api,
        currentUid: () => current() ? uid : null,
      );
    } catch (_) {
      // Database/auth initialization can race startup; retry on resume/timer.
    } finally {
      running = false;
    }
  }

  final lifecycle = AppLifecycleListener(onResume: () => unawaited(recover()));
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      unawaited(recover());
    }
  });
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    lifecycle.dispose();
  });
  scheduleMicrotask(() => unawaited(recover()));
});
