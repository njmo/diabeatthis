import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../async/coalescing_async_action.dart';
import '../auth/load_firebase_callable_identity.dart';
import '../backend/authenticated_callable_transport.dart';
import '../ingredient_catalog/firebase_ingredient_catalog_repository.dart';
import '../ingredient_catalog/http_catalog_callable_transport.dart';
import '../l10n/language.dart';
import 'family_mirror_background_runtime.dart';
import 'family_plan_signal_listener.dart';
import 'family_workflow_guard.dart';
import 'record_family_cloud_connection.dart';
import 'register_family_mirror.dart';
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
  StreamSubscription<User?>? accountSubscription;
  final signals = FamilyPlanSignalListener();
  DateTime? retryAfter;
  bool pending = true;
  bool busy = false;
  final signalPump = CoalescingAsyncAction();
  bool disposed = false;
  String? registeredIdentity;
  void start() => unawaited(tick());

  void scheduleRetry() {
    if (disposed) return;
    retryAfter = DateTime.now().add(const Duration(seconds: 15));
    timer?.cancel();
    timer = Timer(const Duration(seconds: 15), () {
      retryAfter = null;
      pending = true;
      unawaited(tick());
    });
  }

  Future<void> tick() => signalPump(tickOnce);

  Future<void> disconnectSignals(String? owner) async {
    if (owner != null) await recordFamilyCloudConnection(db, owner, false);
    await signals.disconnect();
  }

  Future<void> tickOnce() async {
    if (disposed || (retryAfter?.isAfter(DateTime.now()) ?? false)) return;
    busy = true;
    String? attemptOwner;
    try {
      final settings = await db
          .customSelect(
            'SELECT enabled,enabled_revision,owner_uid FROM family_sync_identity WHERE singleton=1',
          )
          .getSingle();
      attemptOwner = settings.readNullable<String>('owner_uid');
      if (settings.read<int>('enabled') != 1) {
        await signals.disconnect();
        retryAfter = null;
        return;
      }
      if (attemptOwner != null && signals.uid != attemptOwner) {
        await recordFamilyCloudConnection(db, attemptOwner, null);
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
      accountSubscription ??= FirebaseAuth.instance.idTokenChanges().listen((
        _,
      ) {
        if (disposed) return;
        pending = true;
        retryAfter = null;
        registeredIdentity = null;
        unawaited(tick());
      }, onError: (Object error) => scheduleRetry());
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final bound = settings.readNullable<String>('owner_uid');
      if (uid == null) {
        retryAfter = null;
        timer?.cancel();
        await disconnectSignals(bound);
        return;
      }
      final queue = FamilyMirrorOutbox(db);
      if (bound != null && bound != uid) {
        await disconnectSignals(bound);
        return;
      }
      final source = await queue.sourceForOwner(uid);
      final consent = settings.read<int>('enabled_revision');
      final identity = '$uid/$source/$consent';
      if (bound == null || registeredIdentity != identity) {
        final registration = AuthenticatedCallableTransport(
          client: client,
          projectId: Firebase.app().options.projectId,
          currentUid: () => FirebaseAuth.instance.currentUser?.uid,
          identity: loadFirebaseCallableIdentity,
        );
        await registerFamilyMirror(
          transport: registration,
          source: source,
          uid: uid,
          permitted: () => queue.enabledAt(consent),
        );
        if (FirebaseAuth.instance.currentUser?.uid != uid ||
            !await queue.enabledAt(consent)) {
          return;
        }
        await queue.bindOwner(uid);
        registeredIdentity = identity;
      }
      if (signals.uid != uid) await recordFamilyCloudConnection(db, uid, null);
      await signals.connect(
        uid,
        FirebaseFirestore.instance
            .doc('familyPlanSignals/$uid')
            .snapshots(includeMetadataChanges: true)
            .where((event) {
              if (!disposed && FirebaseAuth.instance.currentUser?.uid == uid) {
                unawaited(
                  recordFamilyCloudConnection(
                    db,
                    uid,
                    !event.metadata.isFromCache,
                  ),
                );
              }
              return !event.metadata.isFromCache;
            })
            .map<void>((_) {}),
        onChange: () {
          if (disposed) return;
          pending = true;
          retryAfter = null;
          unawaited(tick());
        },
        onFailure: () {
          unawaited(recordFamilyCloudConnection(db, uid, false));
          pending = true;
          scheduleRetry();
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
      if (more) scheduleRetry();
    } catch (_) {
      if (attemptOwner != null && signals.uid == null) {
        await recordFamilyCloudConnection(db, attemptOwner, false);
      }
      pending = true;
      scheduleRetry();
    } finally {
      busy = false;
    }
  }

  void dispose() {
    disposed = true;
    signalPump.dispose();
    timer?.cancel();
    unawaited(accountSubscription?.cancel());
    final owner = signals.uid;
    if (owner != null) unawaited(recordFamilyCloudConnection(db, owner, false));
    signals.dispose();
    client.close();
  }
}
