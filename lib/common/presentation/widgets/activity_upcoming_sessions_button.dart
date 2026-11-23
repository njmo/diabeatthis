import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../routing/form_route_guard.dart';
import '../../widgets/responsive_bottom_sheet.dart';

class ActivityUpcomingSessionsButton extends StatelessWidget {
  const ActivityUpcomingSessionsButton({
    super.key,
    required this.contentBuilder,
    this.routeGuard,
  });
  final WidgetBuilder contentBuilder;
  final FormRouteGuard? routeGuard;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.event_available_outlined),
    label: Text(context.lang.dashboardUpcomingTitle),
    onPressed: () {
      final guard = routeGuard ?? formRouteGuardOf(context);
      showResponsiveBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => guard(
          SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.lang.dashboardUpcomingTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Flexible(child: contentBuilder(context)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
