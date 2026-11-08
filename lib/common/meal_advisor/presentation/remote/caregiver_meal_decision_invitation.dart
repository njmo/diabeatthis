import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../family/family_providers.dart';
import '../../../l10n/language.dart';
import '../../notifications/meal_decision_push.dart';
import '../../remote/meal_decision_remote_controller.dart';
import 'caregiver_meal_decision_invitation_dialog.dart';
import 'caregiver_meal_decision_timeout.dart';
import 'meal_decision_presentation_registry.dart';

class CaregiverMealDecisionInvitation extends HookConsumerWidget {
  const CaregiverMealDecisionInvitation({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final inbox = ref.watch(mealDecisionRemoteControllerProvider);
    final request = inbox.byId(requestId);
    final family = uid == null
        ? null
        : ref.watch(secureFamilyStatusProvider(uid)).asData?.value;
    final name = family?.members
        .where((member) => member.id == request?.ownerUid)
        .firstOrNull
        ?.displayName
        .trim();
    final busy = useState(false);
    final failed = useState(false);
    final closing = useRef(false);
    final tick = useState(DateTime.now());
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => tick.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);

    Future<void> act(String action) async {
      if (busy.value || closing.value) return;
      busy.value = true;
      failed.value = false;
      try {
        await ref.read(mealDecisionRemoteControllerProvider.notifier).execute(
          action == 'delegate' ? 'claim' : action,
          {'requestId': requestId},
        );
        if (!context.mounted || closing.value) return;
        closing.value = true;
        final route = ModalRoute.of(context);
        final navigator = Navigator.of(context);
        await cancelMealDecisionNotification(requestId);
        if (route != null && route.isActive && navigator.mounted) {
          navigator.removeRoute(route, action);
        }
      } catch (_) {
        if (context.mounted) failed.value = true;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    useEffect(() {
      Future<void> handle(String action) async {
        if (action == 'claim' || action == 'decline' || action == 'delegate') {
          await act(action);
        }
      }

      MealDecisionPresentationRegistry.installCaregiverHandler(
        requestId,
        handle,
      );
      return () => MealDecisionPresentationRegistry.removeCaregiverHandler(
        requestId,
        handle,
      );
    }, [requestId, request]);

    final unavailable =
        uid == null ||
        inbox.accountUid != uid ||
        (!inbox.loading &&
            !inbox.failed &&
            (request == null ||
                !request.pending ||
                request.status != 'waiting' ||
                (request.claimedByUid != null &&
                    request.claimedByUid != uid &&
                    !request.claimAvailable)));
    final timedOut =
        request?.timedOutAt(tick.value) == true &&
        uid != null &&
        inbox.accountUid == uid;
    useEffect(() {
      if (unavailable && !timedOut && !closing.value) {
        closing.value = true;
        final route = ModalRoute.of(context);
        final navigator = Navigator.of(context);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await cancelMealDecisionNotification(requestId);
          if (route != null && route.isActive && navigator.mounted) {
            navigator.removeRoute(route);
          }
        });
      }
      return null;
    }, [unavailable, timedOut]);

    if (timedOut && request != null) {
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      return CaregiverMealDecisionTimeout(
        request: request,
        onClose: () {
          if (navigator.mounted &&
              route != null &&
              route.isActive &&
              route.navigator == navigator) {
            navigator.removeRoute(route);
          }
        },
      );
    }

    return CaregiverMealDecisionInvitationDialog(
      name: name == null || name.isEmpty
          ? context.lang.mealDecisionInvitationChild
          : name,
      busy: busy.value,
      failed: failed.value,
      onAccept: () => act('claim'),
      onCancel: () => act('decline'),
    );
  }
}
