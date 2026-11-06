import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_labels.dart';
import 'setup_icon_bubble.dart';
import 'setup_requirement_chip.dart';

class SetupFeatureHelpSheet extends StatelessWidget {
  const SetupFeatureHelpSheet({super.key, required this.feature});
  final SetupFeature feature;

  static Future<void> show(BuildContext context, SetupFeature feature) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Localizations.override(
          context: sheetContext,
          locale: Localizations.localeOf(context),
          child: SetupFeatureHelpSheet(feature: feature),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wikiPage = switch (feature.id) {
      SetupFeatureId.mealMonitor => 'Meals',
      SetupFeatureId.activityMonitor => 'Activity',
      SetupFeatureId.mealPhoto || SetupFeatureId.aiAssistance => 'AI',
      _ => null,
    };
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SetupIconBubble(icon: setupFeatureIcon(feature.id)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.lang.featureName(feature.id),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (wikiPage == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    context.lang.setupPlanned,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              for (final detail
                  in context.lang.featureDetails(feature.id).split('\n'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(detail)),
                    ],
                  ),
                ),
              Text(
                context.lang.setupRequires,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: feature.requirements
                    .map(
                      (requirement) =>
                          SetupRequirementChip(requirement: requirement),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (wikiPage != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final opened = await launchUrl(
                        Uri.https(
                          'github.com',
                          '/njmo/diabeatthis/wiki/$wikiPage',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                      if (opened) return;
                    } catch (_) {
                      /* Report launch failure below. */
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.lang.setupWikiFailed)),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(context.lang.setupWiki),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.lang.setupUnderstood),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
