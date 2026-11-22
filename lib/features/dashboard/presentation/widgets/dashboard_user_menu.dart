import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common/family_chat/application/family_chat_runtime.dart';
import '../../../../common/family_chat/application/family_chat_settings_runtime.dart';
import '../../../../common/family_chat/data/family_chat_preferences_provider.dart';
import '../../../../common/family_chat/family_chat_platform.dart';
import '../../../../common/family_chat/presentation/family_chat_page.dart';
import '../../../../common/l10n/language.dart';

class DashboardUserMenu extends StatelessWidget {
  const DashboardUserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (supportsFamilyChat) const _FamilyChatButton(),
        IconButton(
          tooltip: context.lang.settingsTitle,
          icon: const Icon(LucideIcons.settings, size: 21),
          onPressed: () => context.router.pushPath('/settings'),
        ),
      ],
    );
  }
}

class _FamilyChatButton extends ConsumerWidget {
  const _FamilyChatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(familyChatRuntimeProvider);
    final settings = ref.watch(familyChatSettingsRuntimeProvider);
    final preferences = ref.watch(familyChatPreferencesProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([runtime, if (settings != null) settings]),
      builder: (context, _) {
        final session = runtime.session;
        final state = settings?.controller.state;
        final accountEnabled =
            state?['account']?['changes']?['accountEnabled'] as bool? ??
            state?['confirmed']?['account']?['enabled'] as bool? ??
            preferences.enabled;
        if (!accountEnabled) return const SizedBox.shrink();
        final hasUnread = session?.hasUnread ?? false;
        final senderName = !hasUnread || session?.unreadSender == null
            ? ''
            : session!.name(session.unreadSender!).trim();
        return IconButton(
          tooltip: context.lang.familyChatTitle,
          icon: Badge(
            isLabelVisible: hasUnread,
            label: Text(senderName.isEmpty ? '' : senderName.characters.first),
            backgroundColor: const Color(0xFF0EA5E9),
            child: const Icon(LucideIcons.messagesSquare, size: 21),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FamilyChatPage()),
            );
          },
        );
      },
    );
  }
}
