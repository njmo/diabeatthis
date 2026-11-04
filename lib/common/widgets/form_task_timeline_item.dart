import 'package:flutter/material.dart';

import 'form_timeline_marker.dart';

/// A task keeps its complete input available when expanded, with compact status
/// and an edit action once completed. Optional tasks may remain pending.
class FormTaskTimelineItem extends StatelessWidget {
  const FormTaskTimelineItem({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.completed = false,
    this.active = false,
    this.optional = false,
    this.isLast = false,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final bool completed;
  final bool active;
  final bool optional;
  final bool isLast;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = optional && !active && !completed;
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 17,
            top: 32,
            bottom: 0,
            child: Container(width: 1, color: theme.colorScheme.outlineVariant),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 48, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                selected: active,
                button: onTap != null,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (active
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.titleMedium)
                                  ?.copyWith(
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: muted
                                        ? theme.colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                        ),
                        if (subtitle != null && !active)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (active)
                Padding(padding: const EdgeInsets.only(top: 8), child: child),
            ],
          ),
        ),
        Positioned(
          left: active && !completed ? 0 : 2,
          top: 3,
          child: FormTimelineMarker(
            optional: optional,
            diameter: active && !completed ? 34 : 30,
            status: completed
                ? FormTimelineStatus.completed
                : active
                ? FormTimelineStatus.active
                : FormTimelineStatus.pending,
          ),
        ),
      ],
    );
  }
}
