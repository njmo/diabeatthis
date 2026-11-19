import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/theme/app_design_tokens.dart';
import '../../domain/models/notification_event_actions.dart';
import '../../inbox/notification_inbox_entry.dart';
import '../in_app_notification_center.dart';
import 'notification_visuals.dart';

/// App-bar bell showing how many notifications arrived since the user last
/// looked, including those posted while the app was in the background.
class NotificationInboxButton extends ConsumerWidget {
  const NotificationInboxButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      inAppNotificationCenterProvider.select((state) => state.unreadCount),
    );
    return IconButton(
      tooltip: unread == 0
          ? context.lang.notificationInboxTitle
          : context.lang.notificationInboxUnreadTooltip(unread),
      onPressed: () => showNotificationInbox(context),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(
          unread > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}

Future<void> showNotificationInbox(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _NotificationInboxSheet(),
  );
}

class _NotificationInboxSheet extends ConsumerStatefulWidget {
  const _NotificationInboxSheet();

  @override
  ConsumerState<_NotificationInboxSheet> createState() =>
      _NotificationInboxSheetState();
}

class _NotificationInboxSheetState
    extends ConsumerState<_NotificationInboxSheet> {
  /// Unread when the sheet opened; highlighted for as long as it stays open
  /// even though they are marked read straight away.
  late final Set<int> _freshIds;

  @override
  void initState() {
    super.initState();
    final center = ref.read(inAppNotificationCenterProvider.notifier);
    _freshIds = ref
        .read(inAppNotificationCenterProvider)
        .inbox
        .where((entry) => !entry.read)
        .map((entry) => entry.id)
        .toSet();
    unawaited(center.refresh().then((_) => center.markAllRead()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inbox = ref.watch(
      inAppNotificationCenterProvider.select((state) => state.inbox),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.lang.notificationInboxTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (inbox.isNotEmpty)
                  TextButton(
                    onPressed: () => ref
                        .read(inAppNotificationCenterProvider.notifier)
                        .clear(),
                    child: Text(context.lang.notificationInboxClear),
                  ),
              ],
            ),
          ),
          Expanded(
            child: inbox.isEmpty
                ? _EmptyInbox(scrollController: scrollController)
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    itemCount: inbox.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _InboxEntryCard(
                      key: ValueKey(inbox[index].id),
                      entry: inbox[index],
                      fresh: _freshIds.contains(inbox[index].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      children: [
        Icon(
          Icons.notifications_none_rounded,
          size: 48,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.lang.notificationInboxEmpty,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.lang.notificationInboxEmptyHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InboxEntryCard extends ConsumerWidget {
  const _InboxEntryCard({super.key, required this.entry, required this.fresh});

  final NotificationInboxEntry entry;
  final bool fresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final center = ref.read(inAppNotificationCenterProvider.notifier);
    final definition = center.definitionFor(entry);
    final event = center.eventFor(entry);
    final actions = event == null
        ? definition.actions
        : notificationActionsFor(event, definition);
    final actionable = event != null && entry.active && actions.isNotEmpty;
    final expired = !actionable && actions.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md - AppSpacing.xs,
        AppSpacing.md - AppSpacing.xs,
        AppSpacing.md - AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: fresh
            ? scheme.secondaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md + 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: expired ? 0.55 : 1,
                child: NotificationChannelBadge(
                  channel: definition.channelType,
                  size: 36,
                ),
              ),
              const SizedBox(width: AppSpacing.md - AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _relativeTime(context, entry.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (entry.body.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        entry.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (expired) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.lang.notificationInboxInactive,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actionable)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: NotificationActionButtons(
                actions: actions,
                choices: notificationInputChoicesFor(event),
                dialogContext: () => context.mounted ? context : null,
                onAction: (action, input) async {
                  await center.respond(
                    id: entry.id,
                    event: event,
                    action: action,
                    input: input,
                  );
                },
              ),
            )
          else
            const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

String _relativeTime(BuildContext context, DateTime at) {
  final lang = context.lang;
  final elapsed = clock.now().difference(at);
  if (elapsed.inMinutes < 1) return lang.notificationInboxJustNow;
  if (elapsed.inMinutes < 60) {
    return lang.notificationInboxMinutesAgo(elapsed.inMinutes);
  }
  if (elapsed.inHours < 12) {
    return lang.notificationInboxHoursAgo(elapsed.inHours);
  }
  final material = MaterialLocalizations.of(context);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${material.formatShortMonthDay(at)}, $time';
}
