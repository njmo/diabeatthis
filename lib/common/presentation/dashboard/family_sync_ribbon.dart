import 'package:flutter/material.dart';

import '../../l10n/language.dart';

/// A fixed-height compact chip: refreshes never move the readings beneath it.
class FamilySyncRibbon extends StatefulWidget {
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
  State<FamilySyncRibbon> createState() => _FamilySyncRibbonState();
}

class _FamilySyncRibbonState extends State<FamilySyncRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.busy) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(FamilySyncRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy != oldWidget.busy) {
      if (widget.busy) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
        _rotationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final text = widget.failed
        ? widget.failureLabel ?? context.lang.familySyncUnavailable
        : widget.busy
        ? widget.busyLabel ?? context.lang.familySyncDownloading
        : widget.ready
        ? widget.readyLabel ?? context.lang.familySyncUpdated
        : context.lang.familyPlanWaitingForChild;

    final fgColor = widget.failed
        ? colors.error
        : widget.busy
        ? colors.primary
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    final bgColor = widget.failed
        ? colors.error.withValues(alpha: isDark ? 0.2 : 0.08)
        : widget.busy
        ? colors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
        : (isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
            : const Color(0xFFF1F5F9).withValues(alpha: 0.9));

    final borderColor = widget.failed
        ? colors.error.withValues(alpha: 0.3)
        : widget.busy
        ? colors.primary.withValues(alpha: 0.3)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return SizedBox(
      height: 24,
      child: Semantics(
        liveRegion: true,
        label: text,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.busy)
                  RotationTransition(
                    turns: _rotationController,
                    child: Icon(
                      Icons.sync_rounded,
                      size: 13,
                      color: fgColor,
                    ),
                  )
                else
                  Icon(
                    widget.failed
                        ? widget.failureIcon
                        : widget.ready
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_outlined,
                    size: 13,
                    color: fgColor,
                  ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
