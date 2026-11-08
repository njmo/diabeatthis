import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../l10n/language.dart';
import '../../remote/meal_decision_remote_request.dart';
import 'meal_decision_compact_status.dart';
import 'meal_decision_stage_chip.dart';

class MealDecisionCaregiverRoster extends HookWidget {
  const MealDecisionCaregiverRoster({
    super.key,
    required this.request,
    this.compact = false,
  });
  final bool compact;
  final MealDecisionRemoteRequest request;
  @override
  Widget build(BuildContext context) {
    final expiryTick = useState(0);
    final presentUntil = (request.data['presentUntil'] as num?)?.toInt() ?? 0;
    useEffect(() {
      final remaining = presentUntil - DateTime.now().millisecondsSinceEpoch;
      if (remaining <= 0) return null;
      final timer = Timer(Duration(milliseconds: remaining + 1), () {
        expiryTick.value++;
      });
      return timer.cancel;
    }, [presentUntil]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final member in request.members)
          MealDecisionCaregiverStatus(
            request: request,
            member: member,
            compact: compact,
          ),
      ],
    );
  }
}

class MealDecisionCaregiverStatus extends StatelessWidget {
  const MealDecisionCaregiverStatus({
    super.key,
    required this.request,
    required this.member,
    this.compact = false,
  });
  final MealDecisionRemoteRequest request;
  final Map<String, dynamic> member;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final declined = member['status'] == 'declined';
    final disabled = member['status'] == 'disabled';
    final responded = request.respondingCaregiverUid == member['uid'];
    final claimed = member['uid'] == request.claimedByUid;
    final away = claimed && !responded && !request.present;
    final colors = Theme.of(context).colorScheme;
    final name = member['displayName'] as String? ?? '';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    final color = declined
        ? colors.error
        : away
        ? Colors.amber.shade600
        : responded || claimed
        ? Colors.green.shade400
        : colors.primary;
    final icon = declined
        ? Icons.close
        : disabled
        ? Icons.notifications_off_outlined
        : away
        ? Icons.warning_amber_rounded
        : responded || claimed
        ? Icons.check_circle_outline
        : Icons.schedule;
    final label = declined
        ? context.lang.mealDecisionRemoteDeclined
        : disabled
        ? context.lang.mealDecisionRemoteDisabled
        : responded
        ? context.lang.mealDecisionStatusAnswered
        : !claimed
        ? context.lang.mealDecisionRemotePending
        : away
        ? context.lang.mealDecisionStatusAway
        : request.stage == 'decision'
        ? context.lang.mealDecisionStatusDecision
        : context.lang.mealDecisionStatusAnalysis;
    if (compact) {
      final compactColor = Theme.of(context).brightness == Brightness.light
          ? declined
                ? colors.error
                : away
                ? Colors.amber.shade900
                : responded || claimed
                ? Colors.green.shade800
                : colors.primary
          : color;
      return MealDecisionCompactStatus(
        name: name,
        label: label,
        icon: icon,
        color: compactColor,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .45),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .45),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(initials),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!claimed && !responded && !declined && !disabled)
              MealDecisionStageChip(
                label: context.lang.mealDecisionWaitingBadge,
                icon: icon,
                color: Colors.amber.shade600,
              )
            else
              Tooltip(
                message: label,
                child: Icon(icon, color: color, size: 24),
              ),
          ],
        ),
      ),
    );
  }
}
