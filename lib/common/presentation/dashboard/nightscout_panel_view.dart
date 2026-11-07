import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'dashboard_spacing.dart';

/// Shared frame; the source supplies the same readings/metrics presentation.
class NightscoutPanelView extends StatelessWidget {
  const NightscoutPanelView({
    super.key,
    required this.lastUpdate,
    required this.readings,
    this.footer,
    this.syncRibbon,
  });
  final String? lastUpdate;
  final Widget readings;
  final Widget? footer;
  final Widget? syncRibbon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: DashboardSpacing.panel,
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncRibbon != null) syncRibbon!,
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              syncRibbon == null ? 12 : 8,
              12,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: Text(
                    lastUpdate ?? context.lang.dashboardWaitingForData,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                readings,
                if (footer != null) footer!,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
