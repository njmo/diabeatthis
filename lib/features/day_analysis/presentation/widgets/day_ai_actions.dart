import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/day_analysis_draft.dart';
import '../controllers/day_ai_controller.dart';

class DayAiActions extends ConsumerWidget {
  final DayAiRequest request;
  final DayAnalysisDraft? draft;
  final bool hasSaved;
  final bool hasAnalysis;
  final bool disabled;
  const DayAiActions({
    super.key,
    required this.request,
    required this.draft,
    required this.hasSaved,
    required this.hasAnalysis,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (draft != null) ...[
          FilledButton(
            onPressed: disabled
                ? null
                : () => ref
                      .read(dayAiControllerProvider(request).notifier)
                      .accept(),
            child: Text(hasSaved ? lang.dayAiReplace : lang.dayAiAccept),
          ),
          TextButton(
            onPressed: disabled
                ? null
                : () => ref
                      .read(dayAiControllerProvider(request).notifier)
                      .discard(),
            child: Text(lang.dayAiDiscard),
          ),
        ],
        FilledButton.icon(
          onPressed: disabled
              ? null
              : () => ref
                    .read(dayAiControllerProvider(request).notifier)
                    .generate(),
          icon: const Icon(Icons.auto_awesome),
          label: Text(hasAnalysis ? lang.dayAiRegenerate : lang.dayAiGenerate),
        ),
      ],
    );
  }
}
