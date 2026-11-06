import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/notifier_provider/simple_provider.dart';
import '../../../../common/profile/profile_photo_controller.dart';
import '../../../../common/widgets/profile_avatar.dart';

class DashboardGreeting extends ConsumerWidget {
  const DashboardGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(googleAccountProvider).asData?.value;
    final name = account == null
        ? ref.watch(nameProvider).asData?.value.trim()
        : account.label;
    final photoPath = account == null
        ? ref.watch(profilePhotoControllerProvider).asData?.value
        : null;
    return Row(
      children: [
        ProfileAvatar(
          photoPath: account == null ? photoPath : null,
          photoUrl: account?.photoUrl,
          name: name,
          size: 40,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name != null && name.isNotEmpty
                ? name
                : context.lang.dashboardGreetingShort,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
