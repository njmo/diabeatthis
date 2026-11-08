import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../family_sync/family_access_scope.dart';
import '../../../l10n/language.dart';
import '../../../widgets/inline_status_notice.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../demo/meal_decision_demo_answer.dart';
import '../../demo/meal_decision_demo_controller.dart';
import '../../demo/meal_decision_demo_request.dart';
import '../../meal_decision_preferences_provider.dart';
import '../caregiver_meal_local_context.dart';
import '../meal_decision_default_minutes.dart';
import 'meal_decision_demo_meal_link.dart';
import 'meal_decision_demo_notice.dart';
import 'meal_decision_demo_options.dart';
import 'meal_decision_demo_response_view.dart';
import 'meal_decision_demo_snapshot_view.dart';
import 'meal_decision_demo_status_label.dart';
import 'meal_decision_demo_timeout_outcome.dart';
import 'meal_decision_demo_transfer_button.dart';
import 'show_meal_decision_demo.dart';

class CaregiverMealDecisionDemoSheet extends HookConsumerWidget {
  const CaregiverMealDecisionDemoSheet({
    super.key,
    required this.requestKey,
    required this.requestId,
    required this.caregiverName,
    this.caregiverId = 'demo-caregiver',
    this.familyScope,
  });
  final String requestKey, requestId, caregiverName, caregiverId;
  final FamilyAccessScope? familyScope;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(mealDecisionDemoControllerProvider)[requestKey];
    final decisionStep = useState(false);
    final answer = useState(MealDecisionDemoAnswer.insulinAndEat);
    final preferences = ref.watch(mealDecisionPreferencesProvider);
    final minutes = useTextEditingController(text: '10');
    final message = useTextEditingController();
    final form = useMemoized(() => GlobalKey<FormState>());
    final current = request != null && request.id == requestId;
    final claimedElsewhere =
        current &&
        request.claimedById != null &&
        request.claimedById != caregiverId;
    final waiting =
        current &&
        request.status == MealDecisionDemoStatus.waiting &&
        !claimedElsewhere &&
        !request.claimExpired;
    useEffect(() {
      Future.microtask(() {
        if (ref.context.mounted) {
          ref
              .read(mealDecisionDemoControllerProvider.notifier)
              .claim(
                requestKey,
                requestId,
                caregiverName,
                caregiverId: caregiverId,
              );
        }
      });
      return null;
    }, [requestKey, requestId, caregiverName, caregiverId]);
    useOnAppLifecycleStateChange((previous, next) {
      ref
          .read(mealDecisionDemoControllerProvider.notifier)
          .updateCaregiverContext(
            requestKey,
            requestId,
            caregiverId,
            present: next == AppLifecycleState.resumed,
          );
    });
    useEffect(
      () {
        final deadline = current ? request.claimExpiresAt : null;
        if (deadline == null ||
            request?.claimedById != caregiverId ||
            request?.status != MealDecisionDemoStatus.waiting) {
          return null;
        }
        final timer = Timer(
          deadline.difference(clock.now()).isNegative
              ? Duration.zero
              : deadline.difference(clock.now()),
          () {
            if (ref.context.mounted) {
              ref
                  .read(mealDecisionDemoControllerProvider.notifier)
                  .expireClaim(requestKey, requestId, caregiverId, deadline);
            }
          },
        );
        return timer.cancel;
      },
      [
        current ? request.claimExpiresAt : null,
        request?.claimedById,
        request?.status,
        caregiverId,
      ],
    );
    Map? localMeal;
    if (familyScope?.isCurrent == true) {
      localMeal =
          familyScope!.family.rows['meals/${request?.mealId}']?['payload']
              as Map?;
    }
    return PopScope(
      canPop: !waiting,
      child: MealStartSheet(
        maxHeightFactor: .75,
        title: familyScope != null
            ? ((localMeal?['name'] as String?) ??
                  context.lang.beforeMealUnavailable)
            : (request?.mealName ?? context.lang.mealDecisionDemoSampleMeal),
        subtitle: decisionStep.value
            ? context.lang.mealDecisionDemoDecisionStep
            : context.lang.mealDecisionDemoContextStep,
        onBack: waiting && decisionStep.value
            ? () {
                decisionStep.value = false;
                ref
                    .read(mealDecisionDemoControllerProvider.notifier)
                    .updateCaregiverContext(
                      requestKey,
                      requestId,
                      caregiverId,
                      present: true,
                      stage: MealDecisionDemoStage.context,
                    );
              }
            : null,
        showClose: !waiting,
        onClose: waiting ? null : () => Navigator.of(context).pop(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (familyScope != null && request?.mealId != null)
              InlineStatusNotice(
                icon: Icons.science_outlined,
                message: context.lang.mealDecisionRealContextDemoNotice,
              )
            else
              const MealDecisionDemoNotice(),
            const SizedBox(height: 14),
            if (!current)
              Text(context.lang.mealDecisionDemoStale)
            else if (request.status == MealDecisionDemoStatus.timedOut)
              MealDecisionDemoTimeoutOutcome(request: request)
            else if (request.claimExpired)
              Text(context.lang.mealDecisionDemoClaimExpired)
            else if (claimedElsewhere && request.answer == null)
              Text(context.lang.mealDecisionDemoClaimedBy(request.claimedBy!))
            else if (waiting) ...[
              Text(
                context.lang.mealDecisionDemoClaimedBy(caregiverName.trim()),
              ),
              const SizedBox(height: 12),
              if (!decisionStep.value) ...[
                if (familyScope != null && request.mealId != null)
                  CaregiverMealLocalContext(
                    scope: familyScope!,
                    mealId: request.mealId!,
                  )
                else ...[
                  MealDecisionDemoMealLink(
                    mealName: request.mealName,
                    snapshot: request.snapshot,
                  ),
                  MealDecisionDemoSnapshotView(
                    snapshot: request.snapshot,
                    compact: true,
                  ),
                ],
              ],
              if (decisionStep.value) ...[
                const SizedBox(height: 8),
                Text(
                  context.lang.mealDecisionDemoChooseAnswer,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Form(
                  key: form,
                  child: Column(
                    children: [
                      MealDecisionDemoOptions(
                        value: answer.value,
                        onChanged: (value) {
                          if (value != answer.value && value.requiresMinutes) {
                            minutes.text =
                                '${mealDecisionDefaultMinutes(value, deferralMinutes: preferences.deferralMinutes)}';
                          }
                          answer.value = value;
                        },
                      ),
                      if (answer.value.requiresMinutes)
                        TextFormField(
                          controller: minutes,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                answer.value == MealDecisionDemoAnswer.deferMeal
                                ? context.lang.mealDecisionDeferralMinutes
                                : context.lang.uiWaitingTimeAfterInsulinMin,
                          ),
                          validator: (text) {
                            final value = int.tryParse(text ?? '');
                            return value == null || value < 1 || value > 180
                                ? context.lang.mealDecisionDemoMinutesInvalid
                                : null;
                          },
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: message,
                        maxLines: 2,
                        maxLength: 240,
                        decoration: InputDecoration(
                          labelText: context.lang.mealDecisionDemoMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (request.answer != null) ...[
              if (request.caregiverId != caregiverId) ...[
                Text(
                  context.lang.mealDecisionDemoAnsweredBy(
                    request.caregiverName!,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              MealDecisionDemoResponseView(request: request),
              const SizedBox(height: 14),
              Text(
                request.status == MealDecisionDemoStatus.answered
                    ? context.lang.mealDecisionDemoReplySent
                    : mealDecisionDemoRequestLabel(context, request),
              ),
            ] else
              Text(mealDecisionDemoRequestLabel(context, request)),
          ],
        ),
        actions: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (waiting && !decisionStep.value)
              FilledButton(
                onPressed: () {
                  decisionStep.value = true;
                  ref
                      .read(mealDecisionDemoControllerProvider.notifier)
                      .updateCaregiverContext(
                        requestKey,
                        requestId,
                        caregiverId,
                        present: true,
                        stage: MealDecisionDemoStage.decision,
                      );
                },
                child: Text(context.lang.mealDecisionDemoProceed),
              ),
            if (waiting && decisionStep.value)
              FilledButton(
                onPressed: () {
                  if (form.currentState?.validate() != true) return;
                  ref
                      .read(mealDecisionDemoControllerProvider.notifier)
                      .respond(
                        requestKey,
                        requestId,
                        answer: answer.value,
                        minutes: int.tryParse(minutes.text) ?? 0,
                        caregiverName: caregiverName,
                        caregiverId: caregiverId,
                        message: message.text,
                        suggestMealTarget: false,
                      );
                },
                child: Text(context.lang.mealDecisionDemoSendToChild),
              ),
            if (waiting)
              MealDecisionDemoTransferButton(
                requestKey: requestKey,
                requestId: requestId,
                caregiverId: caregiverId,
              ),
            if (current && request.answer != null)
              OutlinedButton(
                onPressed: () => showChildMealDecisionDemo(
                  context,
                  requestKey: requestKey,
                  mealName: request.mealName,
                ),
                child: Text(context.lang.mealDecisionDemoChildPreview),
              ),
            if (!waiting)
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
