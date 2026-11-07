import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../l10n/language.dart';
import '../family_mirror_integration.dart';
import '../publish_family_mirror_use_case.dart';
import '../request_family_mirror_sync.dart';
import 'family_sync_labels.dart';

class FamilySyncPage extends ConsumerStatefulWidget {
  const FamilySyncPage({super.key});
  @override
  ConsumerState<FamilySyncPage> createState() => FamilySyncPageState();
}

class FamilySyncPageState extends ConsumerState<FamilySyncPage>
    with WidgetsBindingObserver {
  Timer? timer;
  StreamSubscription? signal;
  bool busy = false;
  bool enabled = false;
  bool failed = false;
  bool active = true;
  int revision = 0;
  int cursor = 0;
  String? listeningUid;
  String? loadedUid;
  String? owner;
  String? source;
  Map<String, ({int records, int pending})> counts = {};
  final cloudRows = <String, Map<String, dynamic>>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  void start() {
    if (!mounted || !active) return;
    timer?.cancel();
    unawaited(refresh());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    listeningUid = uid;
    unawaited(signal?.cancel());
    if (uid != null) {
      signal = FirebaseFirestore.instance
          .doc('familyMirrorSignals/$uid')
          .snapshots()
          .listen(
            (event) {
              if (!event.metadata.isFromCache) unawaited(refresh());
            },
            onError: (Object error) {
              if (mounted) {
                setState(() {
                  revision++;
                  failed = true;
                  cloudRows.clear();
                  counts = {};
                  cursor = 0;
                  loadedUid = null;
                });
                timer?.cancel();
                timer = Timer(const Duration(seconds: 15), start);
              }
            },
          );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      start();
    } else {
      revision++;
      timer?.cancel();
      unawaited(signal?.cancel());
    }
  }

  @override
  void dispose() {
    revision++;
    timer?.cancel();
    unawaited(signal?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh({bool upload = false}) async {
    if (!mounted || busy || !active) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final currentRevision = revision;
    var reportedFailure = false;
    setState(() => busy = true);
    try {
      final mode = await ref.read(applicationDeviceModeProvider.future);
      final transport = ref.read(authenticatedFamilyTransportProvider);
      if (mode == ApplicationDeviceMode.patient) {
        final db = ref.read(databaseProvider);
        var settings = await db
            .customSelect(
              'SELECT * FROM family_sync_identity WHERE singleton=1',
            )
            .getSingle();
        if (upload) {
          final queue = FamilyMirrorOutbox(db);
          final consent = settings.read<int>('enabled_revision');
          await PublishFamilyMirrorUseCase(
            outbox: queue,
            transport: transport,
            currentUid: () => FirebaseAuth.instance.currentUser?.uid,
            canSend: () => queue.enabledAt(consent),
          )();
          await db.customStatement(
            'UPDATE family_sync_identity SET last_error=NULL,last_success=? WHERE singleton=1',
            [DateTime.now().millisecondsSinceEpoch],
          );
          settings = await db
              .customSelect(
                'SELECT * FROM family_sync_identity WHERE singleton=1',
              )
              .getSingle();
        }
        reportedFailure = settings.readNullable<String>('last_error') != null;

        final rows = await db
            .customSelect(
              'SELECT kind,SUM(CASE WHEN deleted=0 THEN 1 ELSE 0 END) AS records,SUM(CASE WHEN revision>acknowledged_revision THEN 1 ELSE 0 END) AS pending,SUM(CASE WHEN failed_revision=revision THEN 1 ELSE 0 END) AS blocked FROM family_sync_outbox GROUP BY kind',
            )
            .get();
        if (!mounted ||
            currentRevision != revision ||
            FirebaseAuth.instance.currentUser?.uid != uid) {
          return;
        }
        reportedFailure =
            reportedFailure || rows.any((row) => row.read<int>('blocked') > 0);
        enabled = settings.read<int>('enabled') == 1;
        counts = {
          for (final row in rows)
            row.read<String>('kind'): (
              records: row.read<int>('records'),
              pending: row.read<int>('pending'),
            ),
        };
      } else {
        if (loadedUid != uid) {
          cloudRows.clear();
          cursor = 0;
          owner = null;
          source = null;
        }
        for (var page = 0; page < 20; page++) {
          final data = await transport.call('fetchFamilyMirror', {
            'after': cursor,
          }, expectedUid: uid);
          if (!mounted ||
              currentRevision != revision ||
              FirebaseAuth.instance.currentUser?.uid != uid) {
            return;
          }
          final changedSource =
              owner != data['ownerUid'] || source != data['sourceId'];
          if (changedSource) {
            cloudRows.clear();
            owner = data['ownerUid'] as String;
            source = data['sourceId'] as String?;
            if (cursor != 0) {
              cursor = 0;
              continue;
            }
          }
          for (final value in data['records'] as List) {
            final row = Map<String, dynamic>.from(value as Map);
            cloudRows['${row['kind']}/${row['id']}'] = row;
          }
          cursor = data['cursor'] as int;
          if (data['hasMore'] != true) break;
        }
        counts = {
          for (final integration in familyMirrorIntegrations)
            integration.kind: (
              records: cloudRows.values
                  .where(
                    (row) =>
                        row['kind'] == integration.kind &&
                        row['deleted'] != true,
                  )
                  .length,
              pending: 0,
            ),
        };
      }
      if (mounted &&
          currentRevision == revision &&
          FirebaseAuth.instance.currentUser?.uid == uid) {
        setState(() {
          loadedUid = uid;
          failed = reportedFailure;
        });
      }
    } catch (_) {
      if (mounted && currentRevision == revision) {
        setState(() {
          failed = true;
          if (ref.read(applicationDeviceModeProvider).asData?.value ==
              ApplicationDeviceMode.caregiver) {
            cloudRows.clear();
            counts = {};
            cursor = 0;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        timer?.cancel();
        if (failed && active) timer = Timer(const Duration(seconds: 15), start);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authenticatedFamilyTransportProvider);
    ref.listen(googleAccountProvider, (_, next) {
      final uid = next.asData?.value?.uid;
      if (next.isLoading || uid == listeningUid) return;
      revision++;
      timer?.cancel();
      unawaited(signal?.cancel());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          loadedUid = null;
          cloudRows.clear();
          counts = {};
          cursor = 0;
        });
        listeningUid = uid;
        if (uid != null) start();
      });
    });
    final account = ref.watch(googleAccountProvider).asData?.value;
    final patient =
        ref.watch(applicationDeviceModeProvider).asData?.value ==
        ApplicationDeviceMode.patient;
    final familyStatus = patient && account != null
        ? ref.watch(secureFamilyStatusProvider(account.uid))
        : null;
    final mayDisable =
        familyStatus != null &&
        !familyStatus.isLoading &&
        !familyStatus.hasError &&
        familyStatus.asData?.value.members.isEmpty == true;
    final visible = loadedUid == account?.uid
        ? counts
        : <String, ({int records, int pending})>{};
    return Scaffold(
      appBar: AppBar(title: Text(context.lang.familySyncTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(context.lang.familySyncDescription),
            if (account == null)
              Text(context.lang.familyGoogleRequired)
            else ...[
              if (patient)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.lang.familySyncEnable),
                  subtitle: Text(
                    enabled && !mayDisable
                        ? context.lang.setupFamilyDisconnectBeforeDisable
                        : context.lang.familySyncOffline,
                  ),
                  value: enabled,
                  onChanged: busy || (enabled && !mayDisable)
                      ? null
                      : (value) async {
                          final currentAccount = ref
                              .read(googleAccountProvider)
                              .asData
                              ?.value;
                          final roster = ref.read(
                            secureFamilyStatusProvider(account.uid),
                          );
                          if (currentAccount?.uid != account.uid ||
                              ref
                                      .read(applicationDeviceModeProvider)
                                      .asData
                                      ?.value !=
                                  ApplicationDeviceMode.patient) {
                            return;
                          }
                          if (!value &&
                              (roster.isLoading ||
                                  roster.hasError ||
                                  roster.asData?.value.members.isEmpty !=
                                      true)) {
                            return;
                          }
                          await ref.read(databaseProvider).customStatement(
                            'UPDATE family_sync_identity SET enabled=?,enabled_revision=enabled_revision+1 WHERE singleton=1',
                            [value ? 1 : 0],
                          );
                          await requestFamilyMirrorSync(
                            ref.read(databaseProvider),
                          );
                          if (mounted) setState(() => enabled = value);
                          await refresh(upload: value);
                        },
                ),
              if (busy) const LinearProgressIndicator(),
              if (failed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.lang.familySyncFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => refresh(upload: patient && enabled),
                icon: const Icon(Icons.sync),
                label: Text(context.lang.familySyncNow),
              ),
              for (final integration in familyMirrorIntegrations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    familySyncIntegrationLabel(context, integration.kind),
                  ),
                  subtitle: Text(
                    context.lang.familySyncCounts(
                      visible[integration.kind]?.records ?? 0,
                      visible[integration.kind]?.pending ?? 0,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
