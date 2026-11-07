import 'package:flutter/material.dart';

import '../../l10n/language.dart';

/// A fixed-height slot: refreshes never move the readings beneath it.
class FamilySyncRibbon extends StatelessWidget {
  const FamilySyncRibbon({
    super.key,
    required this.busy,
    required this.failed,
    required this.ready,
    this.busyLabel,
    this.readyLabel,
    this.failureLabel,
    this.failureIcon = Icons.cloud_off_outlined,
    this.syncIcon = Icons.cloud_download_outlined,
  });
  final bool busy;
  final bool failed;
  final bool ready;
  final String? busyLabel, readyLabel, failureLabel;
  final IconData failureIcon, syncIcon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = failed
        ? failureLabel ?? context.lang.familySyncUnavailable
        : busy
        ? busyLabel ?? context.lang.familySyncDownloading
        : ready
        ? readyLabel ?? context.lang.familySyncUpdated
        : context.lang.familyPlanWaitingForChild;
    return SizedBox(
      height: 32,
      child: Semantics(
        liveRegion: true,
        label: text,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: colors.primary.withValues(alpha: .08)),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      failed
                          ? failureIcon
                          : busy
                          ? syncIcon
                          : Icons.cloud_done_outlined,
                      size: 16,
                      color: failed ? colors.error : colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (busy)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}
