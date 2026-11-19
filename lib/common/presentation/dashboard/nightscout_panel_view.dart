import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'dashboard_spacing.dart';

/// Provides [lastUpdate] down the widget tree so child readings can integrate
/// the timestamp into their header layout (e.g., mockup 2 style).
class NightscoutPanelScope extends InheritedWidget {
  const NightscoutPanelScope({
    super.key,
    required this.lastUpdate,
    this.syncRibbon,
    required super.child,
  });

  final String? lastUpdate;
  final Widget? syncRibbon;

  static NightscoutPanelScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NightscoutPanelScope>();

  @override
  bool updateShouldNotify(NightscoutPanelScope oldWidget) =>
      lastUpdate != oldWidget.lastUpdate || syncRibbon != oldWidget.syncRibbon;
}

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

  bool _hasIntegratedHeader(Widget widget) {
    final typeName = widget.runtimeType.toString();
    if (typeName.contains('GlucoseReading') ||
        typeName.contains('DeviceStatusDashboard') ||
        typeName.contains('GlucoseDashboard')) {
      return true;
    }
    if (widget is RepaintBoundary && widget.child != null) {
      return _hasIntegratedHeader(widget.child!);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showStandaloneLastUpdate = !_hasIntegratedHeader(readings);

    return Padding(
      padding: DashboardSpacing.panel,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: NightscoutPanelScope(
          lastUpdate: lastUpdate,
          syncRibbon: showStandaloneLastUpdate ? null : syncRibbon,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncRibbon != null && showStandaloneLastUpdate) syncRibbon!,
              Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  syncRibbon == null || !showStandaloneLastUpdate ? 0 : 8,
                  0,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showStandaloneLastUpdate)
                      RepaintBoundary(
                        child: Text(
                          lastUpdate ?? context.lang.dashboardWaitingForData,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
      ),
    );
  }
}
