import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../auth/load_firebase_callable_identity.dart';
import '../backend/authenticated_callable_transport.dart';
import '../ingredient_catalog/firebase_ingredient_catalog_repository.dart';
import '../ingredient_catalog/http_catalog_callable_transport.dart';
import '../l10n/language.dart';
import 'family_mirror_background_runtime.dart';
import 'family_plan_signal_listener.dart';
import 'family_workflow_guard.dart';
import 'synchronize_family_plans_use_case.dart';

/// Only metadata is listened to; all content/authorization goes through callables.
class FamilyPlanBackgroundRuntime {
  FamilyPlanBackgroundRuntime(
    this.db,
    this.mirror, {
    this.cancelConfirmation,
    this.workflowGuard,
  });
  final DatabaseImpl db;
  final FamilyWorkflowGuard? workflowGuard;
  final Future<void> Function(int)? cancelConfirmation;
  final FamilyMirrorBackgroundRuntime mirror;
  final client = http.Client();
  Timer? timer;
  final signals = FamilyPlanSignalListener();
  DateTime? retryAfter;
  bool pending = true;
  bool busy = false;
  bool disposed = false;
  void start() {
    timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(tick()),
    );
    unawaited(tick());
  }

  Future<void> tick() async {
    if (disposed || busy || (retryAfter?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    busy = true;
    try {
      final settings = await db
          .customSelect(
            'SELECT enabled,enabled_revision,owner_uid FROM family_sync_identity WHERE singleton=1',
          )
          .getSingle();
      if (settings.read<int>('enabled') != 1) {
        await signals.disconnect();
        retryAfter = null;
        return;
      }
      mirror.initialization ??= mirror
          .initialize()
          .timeout(const Duration(seconds: 15))
          .catchError((Object error) {
            mirror.initialization = null;
            throw error;
          });
      await mirror.initialization;
      if (disposed) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        await signals.disconnect();
        return;
      }
      final queue = FamilyMirrorOutbox(db);
      final bound = settings.readNullable<String>('owner_uid');
      if (bound != null && bound != uid) {
        await signals.disconnect();
        return;
      }
      if (bound == null) {
        final source = await queue.sourceForOwner(uid);
        final consent = settings.read<int>('enabled_revision');
        final registration = AuthenticatedCallableTransport(
          client: client,
          projectId: Firebase.app().options.projectId,
          currentUid: () => FirebaseAuth.instance.currentUser?.uid,
          identity: loadFirebaseCallableIdentity,
        );
        await registration.call(
          'registerFamilyMirror',
          {'sourceId': source},
          expectedUid: uid,
          allowRequest: () => queue.enabledAt(consent),
        );
        if (FirebaseAuth.instance.currentUser?.uid != uid ||
            !await queue.enabledAt(consent)) {
          return;
        }
        await queue.bindOwner(uid);
      }
      await signals.connect(
        uid,
        FirebaseFirestore.instance
            .doc('familyPlanSignals/$uid')
            .snapshots()
            .where((event) => !event.metadata.isFromCache)
            .map<void>((_) {}),
        onChange: () {
          if (disposed) return;
          pending = true;
          retryAfter = null;
          unawaited(tick());
        },
        onFailure: () {
          pending = true;
          retryAfter = DateTime.now().add(const Duration(minutes: 1));
        },
      );
      final journal = await db
          .customSelect(
            'SELECT operation_id FROM family_plan_journal WHERE acknowledged=0 LIMIT 1',
          )
          .get();
      if (!pending && journal.isEmpty) return;
      pending = false;
      final transport = AuthenticatedCallableTransport(
        client: client,
        projectId: Firebase.app().options.projectId,
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        identity: loadFirebaseCallableIdentity,
      );
      final more = await SynchronizeFamilyPlansUseCase(
        db: db,
        transport: transport,
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        cancelConfirmation: cancelConfirmation,
        workflowGuard: workflowGuard,
        languageCode: LanguageStrings.current.localeName.startsWith('pl')
            ? 'pl'
            : 'en',
        catalog: FirebaseIngredientCatalogRepository(
          HttpCatalogCallableTransport(
            client: client,
            projectId: Firebase.app().options.projectId,
            appCheckToken: () => FirebaseAppCheck.instance.getToken(),
          ),
        ),
      )();
      pending = pending || more;
      if (more) retryAfter = DateTime.now().add(const Duration(minutes: 1));
    } catch (_) {
      pending = true;
      retryAfter = DateTime.now().add(const Duration(minutes: 1));
    } finally {
      busy = false;
    }
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    signals.dispose();
    client.close();
  }
}
