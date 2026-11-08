import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/language.dart';
import '../../../widgets/active_presence_indicator.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../demo/meal_decision_demo_controller.dart';
import '../../demo/meal_decision_demo_request.dart';
import 'child_meal_decision_message.dart';
import 'meal_decision_demo_fallback_action.dart';
import 'meal_decision_demo_status_label.dart';
import 'meal_decision_demo_timeout_outcome.dart';
import 'show_meal_decision_demo.dart';

class ChildMealDecisionDemoSheet extends ConsumerWidget {
  const ChildMealDecisionDemoSheet({
    super.key,
    required this.requestKey,
    required this.mealName,
  });
  final String requestKey, mealName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(mealDecisionDemoControllerProvider)[requestKey];
    final controller = ref.read(mealDecisionDemoControllerProvider.notifier);
    final answered = request?.status == MealDecisionDemoStatus.answered;
    final waiting = request?.status == MealDecisionDemoStatus.waiting;
    final sending = request?.status == MealDecisionDemoStatus.sending;
    final locked = sending || waiting || answered;
    final canSend =
        request == null || request.status == MealDecisionDemoStatus.accepted;
    return PopScope(
      canPop: !locked,
      child: MealStartSheet(
        title: request?.mealName ?? mealName,
        subtitle: context.lang.mealDecisionDemoChildSubtitle,
        showClose: !locked,
        onClose: locked ? null : () => Navigator.of(context).pop(),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (request != null) ...[
              Text(
                DateFormat.Hm(
                  context.lang.localeName,
                ).format(request.snapshot.capturedAt),
              ),
              const SizedBox(height: 12),
            ],
            if (request != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  waiting || sending
                      ? Icons.hourglass_top
                      : answered
                      ? Icons.mark_chat_unread_outlined
                      : Icons.task_alt,
                ),
                title: Text(
                  request.status == MealDecisionDemoStatus.timedOut &&
                          request.fallbackAdvice == null
                      ? context.lang.mealDecisionTimeoutChildTitle
                      : mealDecisionDemoRequestLabel(context, request),
                ),
                subtitle: waiting
                    ? ActivePresenceIndicator(
                        active:
                            request.claimedBy != null &&
                            request.caregiverPresent,
                        label: request.claimedBy == null
                            ? context.lang.mealDecisionDemoWaitingDetail
                            : !request.caregiverPresent
                            ? context.lang.mealDecisionDemoCaregiverAway(
                                request.claimedBy!,
                              )
                            : request.stage == MealDecisionDemoStage.context
                            ? context.lang.mealDecisionDemoCaregiverReviewing(
                                request.claimedBy!,
                              )
                            : context.lang.mealDecisionDemoCaregiverDeciding(
                                request.claimedBy!,
                              ),
                      )
                    : null,
              ),
              if (request.transferredFrom != null &&
                  request.transferredTo != null)
                Text(
                  context.lang.mealDecisionDemoTransferred(
                    request.transferredFrom!,
                    request.transferredTo!,
                  ),
                ),
              if (request.status == MealDecisionDemoStatus.timedOut &&
                  request.fallbackAdvice != null)
                MealDecisionDemoTimeoutOutcome(request: request),
              if (request.answer != null) ...[
                ChildMealDecisionMessage(request: request),
              ],
            ],
          ],
        ),
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canSend)
              FilledButton.icon(
                icon: const Icon(Icons.send_outlined),
                onPressed: () => controller.send(requestKey, mealName),
                label: Text(
                  request == null
                      ? context.lang.mealDecisionDemoSend
                      : context.lang.mealDecisionDemoAgain,
                ),
              ),
            if (sending)
              FilledButton.icon(
                onPressed: null,
                icon: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text(context.lang.mealDecisionDemoSending),
              ),
            if (waiting)
              OutlinedButton.icon(
                icon: const Icon(Icons.science_outlined),
                onPressed: () => showCaregiverMealDecisionDemo(
                  context,
                  requestKey: requestKey,
                  requestId: request!.id,
                  caregiverName:
                      request.claimedBy ??
                      context.lang.mealDecisionDemoCaregiver,
                  caregiverId: request.claimedById ?? 'demo-caregiver',
                ),
                label: Text(context.lang.mealDecisionDemoSimulateReply),
              ),
            if (request != null && answered) ...[
              FilledButton(
                onPressed: () => controller.acknowledge(requestKey, request.id),
                child: Text(context.lang.mealDecisionDemoAccept),
              ),
            ],
            if (request != null &&
                request.status == MealDecisionDemoStatus.timedOut &&
                request.fallbackAdvice == null)
              MealDecisionDemoFallbackAction(request: request),
            if (!locked)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(MaterialLocalizations.of(context).closeButtonLabel),
              ),
          ],
        ),
      ),
    );
  }
}
