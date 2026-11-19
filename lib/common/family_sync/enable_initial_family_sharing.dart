import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/initial_configuration_provider.dart';
import '../../core/data/provider/shared_prefs_provider.dart';
import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../core/drift/providers/database_provider.dart';
import '../auth/google_authentication_providers.dart';
import '../family/family_providers.dart';
import 'request_family_mirror_sync.dart';

const initialFamilySharingPendingKey = 'initial-family-sharing-pending';

class FamilySharingSetupFailure implements Exception {
  const FamilySharingSetupFailure();
}

final enableInitialFamilySharingProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      final authentication = ref.read(googleAuthenticationRepositoryProvider);
      final prefs = await ref.read(sharedPrefsProvider.future);
      await EnableInitialFamilySharing(
        ref.read(databaseProvider),
        () async => (await authentication.watchAccount().first.timeout(
          const Duration(seconds: 10),
        ))?.uid,
        beforeEnable: (uid, revision, source) async {
          if (!await prefs.setString(
            initialFamilySharingPendingKey,
            jsonEncode({'uid': uid, 'revision': revision, 'source': source}),
          )) {
            throw StateError('Sharing setup intent was not saved.');
          }
        },
      )();
    } catch (_) {
      throw const FamilySharingSetupFailure();
    }
  },
);

/// Reconcile only consent introduced by an interrupted setup, preserving any
/// pre-existing or independently changed consent. Never infer unlinking offline.
final reconcileInitialFamilySharingProvider = Provider<Future<void> Function(bool)>(
  (ref) => (selected) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final pending = prefs.getString(initialFamilySharingPendingKey);
    if (pending == null) return;
    if (hasInitialConfiguration(prefs)) {
      try {
        await prefs.remove(initialFamilySharingPendingKey);
      } catch (_) {}
      return;
    }
    if (selected) return;
    try {
      final checkpoint = jsonDecode(pending) as Map;
      final db = ref.read(databaseProvider);
      final row = await db
          .customSelect('SELECT * FROM family_sync_identity WHERE singleton=1')
          .getSingle();
      final matches =
          row.readNullable<String>('owner_uid') == checkpoint['uid'] &&
          row.read<int>('enabled_revision') == checkpoint['revision'] &&
          row.read<String>('source_id') == checkpoint['source'];
      if (row.read<int>('enabled') == 1 && matches) {
        final authentication = ref.read(googleAuthenticationRepositoryProvider);
        Future<String?> currentUid() async =>
            (await authentication.watchAccount().first.timeout(
              const Duration(seconds: 10),
            ))?.uid;
        if (await currentUid() != checkpoint['uid']) {
          throw const FamilySharingSetupFailure();
        }
        final status = await ref
            .read(authenticatedFamilyTransportProvider)
            .call(
              'getFamilyStatus',
              {},
              expectedUid: checkpoint['uid'] as String,
            );
        if ((status['members'] as List).isNotEmpty) {
          throw const FamilySharingSetupFailure();
        }
        await db.transaction(() async {
          if (await currentUid() != checkpoint['uid']) {
            throw const FamilySharingSetupFailure();
          }
          await db.customStatement(
            'UPDATE family_sync_identity SET enabled=0,enabled_revision=enabled_revision+1 WHERE singleton=1 AND owner_uid=? AND enabled_revision=? AND source_id=?',
            [checkpoint['uid'], checkpoint['revision'], checkpoint['source']],
          );
        });
        await requestFamilyMirrorSync(db);
      }
      await prefs.remove(initialFamilySharingPendingKey);
    } catch (_) {
      throw const FamilySharingSetupFailure();
    }
  },
);

/// Preparing the selected family feature is part of setup, before publishing
/// configuration completion. A caregiver already reads Firebase directly and never uploads
/// the caregiver phone's patient tables.
class EnableInitialFamilySharing {
  const EnableInitialFamilySharing(
    this.db,
    this.currentUid, {
    this.beforeEnable,
  });
  final Future<void> Function(String uid, int revision, String source)?
  beforeEnable;
  final DatabaseImpl db;
  final Future<String?> Function() currentUid;

  Future<void> call() async {
    final uid = await currentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Google sign-in is required for family sharing.');
    }
    await db.transaction(() async {
      final source = await FamilyMirrorOutbox(db).bindOwner(uid);
      final row = await db
          .customSelect(
            'SELECT enabled,enabled_revision FROM family_sync_identity WHERE singleton=1',
          )
          .getSingle();
      if (row.read<int>('enabled') == 0) {
        await beforeEnable?.call(
          uid,
          row.read<int>('enabled_revision') + 1,
          source,
        );
      }
      if (await currentUid() != uid) {
        throw StateError('Google account changed during setup.');
      }
      await db.customStatement(
        'UPDATE family_sync_identity SET enabled=1,enabled_revision=enabled_revision+1 WHERE singleton=1 AND enabled=0',
      );
    });
    await requestFamilyMirrorSync(db);
  }
}
