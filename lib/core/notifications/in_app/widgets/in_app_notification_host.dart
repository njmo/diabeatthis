import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/providers/app_router_provider.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/theme/app_design_tokens.dart';
import '../in_app_notification_center.dart';
import 'notification_inbox.dart';
import 'notification_visuals.dart';

/// Draws in-app notification banners above every route, dialog and sheet.
///
/// Placed in `MaterialApp.builder`, so it sits outside the navigator: it has
/// theme, localizations and media query, but no Overlay of its own (no
/// tooltips here) and asks for text input through the navigator's context.
class InAppNotificationHost extends StatelessWidget {
  const InAppNotificationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const Positioned(top: 0, left: 0, right: 0, child: _BannerSlot()),
      ],
    );
  }
}

class _BannerSlot extends ConsumerWidget {
  const _BannerSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(
      inAppNotificationCenterProvider.select((state) => state.banners),
    );
    final current = banners.isEmpty ? null : banners.first;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm + AppSpacing.xs,
          0,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              reverseDuration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, if (current != null) current],
              ),
              child: current == null
                  ? const SizedBox(key: ValueKey('no-banner'), width: 0)
                  : _InAppBannerCard(
                      key: ValueKey(current.id),
                      banner: current,
                      queued: banners.length - 1,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InAppBannerCard extends ConsumerStatefulWidget {
  const _InAppBannerCard({
    super.key,
    required this.banner,
    required this.queued,
  });

  final InAppBanner banner;
  final int queued;

  @override
  ConsumerState<_InAppBannerCard> createState() => _InAppBannerCardState();
}

class _InAppBannerCardState extends ConsumerState<_InAppBannerCard> {
  static const _autoDismissAfter = Duration(seconds: 6);
  Timer? _autoDismiss;

  bool get _informational => widget.banner.actions.isEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(HapticFeedback.lightImpact());
    // Informational banners leave on their own; anything awaiting an answer
    // stays until the user acts on it or closes it.
    if (_informational) {
      _autoDismiss = Timer(_autoDismissAfter, _dismiss);
    }
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _autoDismiss?.cancel();
    unawaited(
      ref
          .read(inAppNotificationCenterProvider.notifier)
          .dismiss(widget.banner.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final banner = widget.banner;
    final event = banner.event;

    return Dismissible(
      key: ValueKey('dismiss-${banner.id}'),
      direction: DismissDirection.up,
      onDismissed: (_) => _dismiss(),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorderRadius,
            boxShadow: AppShadows.floating,
          ),
          child: Material(
            type: MaterialType.card,
            color: scheme.surfaceContainerHigh,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.cardBorderRadius,
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _informational
                  ? _dismiss
                  : banner.opensOnTap
                  ? () => unawaited(
                      ref
                          .read(inAppNotificationCenterProvider.notifier)
                          .open(banner.id, event),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md - AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.sm + AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxs),
                          child: NotificationChannelBadge(
                            channel: banner.definition.channelType,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md - AppSpacing.xs),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  event.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (event.body.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    event.body,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: context.lang.inAppNotificationClose,
                          excludeSemantics: true,
                          child: IconButton(
                            onPressed: _dismiss,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: AppSizes.iconSmall,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (banner.actions.isNotEmpty || widget.queued > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.queued > 0)
                              _QueuedChip(
                                count: widget.queued,
                                onTap: () {
                                  final context = ref
                                      .read(appRouterProvider)
                                      .navigatorKey
                                      .currentContext;
                                  if (context != null) {
                                    unawaited(showNotificationInbox(context));
                                  }
                                },
                              ),
                            Expanded(
                              child: NotificationActionButtons(
                                actions: banner.actions,
                                choices: banner.inputChoices,
                                dialogContext: () => ref
                                    .read(appRouterProvider)
                                    .navigatorKey
                                    .currentContext,
                                onAction: (action, input) => ref
                                    .read(
                                      inAppNotificationCenterProvider.notifier,
                                    )
                                    .respond(
                                      id: banner.id,
                                      event: event,
                                      action: action,
                                      input: input,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueuedChip extends StatelessWidget {
  const _QueuedChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xxs,
            vertical: AppSpacing.xs + AppSpacing.xxs,
          ),
          child: Text(
            context.lang.inAppNotificationMore(count),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
