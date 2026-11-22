import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../../family/family_providers.dart';
import '../meal_decision_eligibility.dart';
import '../meal_decision_preferences_provider.dart';
import '../meal_decision_timing.dart';
import 'meal_decision_remote_request.dart';

class MealDecisionRemoteInbox {
  const MealDecisionRemoteInbox({
    this.requests = const [],
    this.loading = false,
    this.failed = false,
    this.retryableReadFailure = false,
    this.accountUid,
    this.authoritative = false,
  });
  final List<MealDecisionRemoteRequest> requests;
  final bool loading, failed;
  final bool retryableReadFailure;
  final String? accountUid;

  /// True only after a successful server fetch for [accountUid].
  final bool authoritative;

  bool canResolveNotificationFor(String? uid) =>
      uid != null && accountUid == uid && authoritative && !loading && !failed;
  MealDecisionRemoteRequest? byId(String id) =>
      requests.where((r) => r.id == id).firstOrNull;
  MealDecisionRemoteRequest? forMeal(int mealId) =>
      requests.where((r) => r.mealId == mealId && r.pending).firstOrNull;
  MealDecisionRemoteRequest? latestForMeal(int mealId) {
    final matches = requests.where((r) => r.mealId == mealId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.firstOrNull;
  }
}

final mealDecisionRemoteControllerProvider =
    NotifierProvider<MealDecisionRemoteController, MealDecisionRemoteInbox>(
      MealDecisionRemoteController.new,
    );

class MealDecisionRemoteController extends Notifier<MealDecisionRemoteInbox> {
  int generation = 0;
  bool again = false;
  Future<void>? pendingRefresh;
  bool backgroundEnabled = true;
  @override
  MealDecisionRemoteInbox build() {
    backgroundEnabled = false;
    if (Firebase.apps.isEmpty) return const MealDecisionRemoteInbox();
    final configured =
        ref.watch(initialConfigurationDoneProvider).asData?.value == true;
    final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
    final mode = ref.watch(applicationDeviceModeProvider).asData?.value;
    final preferencesReady = ref.watch(sharedPrefsProvider).asData != null;
    final preferences = ref.watch(mealDecisionPreferencesProvider);
    final paired = configured && uid != null && mode != null && preferencesReady
        ? ref.watch(
            secureFamilyStatusProvider(uid).select(
              (value) => mealDecisionFamilyPaired(mode, value.asData?.value),
            ),
          )
        : false;
    final enabled = mode != null && mealDecisionEnabled(mode, preferences);
    backgroundEnabled = configured && uid != null && paired && enabled;
    final version = ++generation;
    var active = true;
    StreamSubscription? subscription;
    Timer? initializationRetry;
    ref.onDispose(() {
      active = false;
      subscription?.cancel();
      initializationRetry?.cancel();
    });
    if (!configured ||
        uid == null ||
        mode == null ||
        !preferencesReady ||
        !paired) {
      return const MealDecisionRemoteInbox();
    }
    late Future<void> Function() connect;
    void retryInitialization() {
      initializationRetry?.cancel();
      initializationRetry = Timer(const Duration(seconds: 10), () {
        if (!active || generation != version) return;
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          retryInitialization();
          return;
        }
        unawaited(connect());
      });
    }

    connect = () async {
      try {
        if (mode == ApplicationDeviceMode.caregiver) {
          await execute('configure', {'enabled': enabled}, refresh: false);
        }
        if (!active || generation != version) return;
        if (!enabled) {
          state = MealDecisionRemoteInbox(accountUid: uid);
          return;
        }
        await refresh();
        if (!active || generation != version) return;
        await subscription?.cancel();
        subscription = FirebaseFirestore.instance
            .doc('familyMealDecisionSignals/$uid')
            .snapshots()
            .listen(
              (event) {
                if (active &&
                    generation == version &&
                    !event.metadata.isFromCache) {
                  unawaited(refresh());
                }
              },
              onError: (Object error) {
                if (active && generation == version) {
                  state = MealDecisionRemoteInbox(
                    accountUid: uid,
                    requests: mealDecisionAccessDenied(error)
                        ? const []
                        : state.requests,
                    failed: true,
                  );
                  retryInitialization();
                }
              },
            );
      } catch (error) {
        if (active && generation == version) {
          state = MealDecisionRemoteInbox(
            accountUid: uid,
            requests: mealDecisionAccessDenied(error)
                ? const []
                : state.requests,
            failed: true,
          );
          retryInitialization();
        }
      }
    };
    Future.microtask(connect);
    return MealDecisionRemoteInbox(loading: enabled);
  }

  Future<Map<String, dynamic>> execute(
    String action,
    Map<String, Object?> values, {
    bool refresh = true,
  }) async {
    final uid = ref.read(googleAccountProvider).asData?.value?.uid;
    if (uid == null) throw StateError('Google authentication is required');
    Future<Map<String, dynamic>> call() => ref
        .read(authenticatedFamilyTransportProvider)
        .call('mealDecision', {'action': action, ...values}, expectedUid: uid);
    final result = switch (action) {
      'claim' ||
      'fetch' ||
      'respond' => await timeMealDecision('firebase.$action', call),
      _ => await call(),
    };
    if (refresh &&
        ref.mounted &&
        ref.read(googleAccountProvider).asData?.value?.uid == uid) {
      await this.refresh();
    }
    return result;
  }

  Future<void> refresh() {
    if (!backgroundEnabled) return Future.value();
    again = true;
    if (pendingRefresh != null) return pendingRefresh!;
    final completion = Completer<void>();
    pendingRefresh = completion.future;
    Future<void> drain() async {
      try {
        while (again && ref.mounted) {
          again = false;
          final version = generation;
          final uid = ref.read(googleAccountProvider).asData?.value?.uid;
          try {
            final response = await execute('fetch', {}, refresh: false);
            if (!ref.mounted || version != generation) continue;
            final rows = response['requests'];
            if (rows is! List) {
              throw const FormatException('Missing meal decision inbox');
            }
            state = MealDecisionRemoteInbox(
              accountUid: uid,
              authoritative: true,
              requests: [
                for (final r in rows)
                  MealDecisionRemoteRequest(
                    Map<String, dynamic>.from(r as Map),
                  ),
              ],
            );
          } catch (error) {
            if (ref.mounted && version == generation) {
              state = MealDecisionRemoteInbox(
                accountUid: uid,
                requests: mealDecisionAccessDenied(error)
                    ? const []
                    : state.requests,
                failed: true,
                retryableReadFailure:
                    error is CallableFailure &&
                    error.code == 'unavailable' &&
                    (error.rejectionCode == null ||
                        const {
                          'unavailable',
                          'internal',
                          'deadline-exceeded',
                        }.contains(error.rejectionCode)),
              );
            }
          }
        }
      } finally {
        pendingRefresh = null;
        completion.complete();
      }
    }

    unawaited(drain());
    return completion.future;
  }
}

bool mealDecisionAccessDenied(Object error) => error is CallableFailure
    ? error.code == 'unauthenticated' ||
          const {
            'permission-denied',
            'unauthenticated',
          }.contains(error.rejectionCode)
    : error is FirebaseException &&
          const {'permission-denied', 'unauthenticated'}.contains(error.code);
