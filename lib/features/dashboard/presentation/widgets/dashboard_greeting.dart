import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/notifier_provider/simple_provider.dart';

class DashboardGreeting extends ConsumerWidget {
  const DashboardGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(nameProvider).asData?.value.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.lang.dashboardGreetingShort,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (name != null && name.isNotEmpty)
          Text(name, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
