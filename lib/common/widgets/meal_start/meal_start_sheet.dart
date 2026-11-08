import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../keyboard_aware_bottom_sheet.dart';
import 'meal_start_header.dart';

class MealStartSheet extends HookWidget {
  const MealStartSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    this.onBack,
    this.onClose,
    this.showClose = true,
    this.maxHeightFactor = .9,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget actions;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final bool showClose;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bodyKey = useMemoized(GlobalKey.new);
    final retainedBody = KeyedSubtree(key: bodyKey, child: body);
    final header = MealStartHeader(
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      onClose: onClose,
      showClose: showClose,
    );
    // Retain the body when space becomes too small for pinned controls.
    final scrollAll =
        media.size.height < 600 ||
        (maxHeightFactor < .9 && media.size.height * maxHeightFactor < 600) ||
        media.size.height * maxHeightFactor - media.viewInsets.bottom < 400 ||
        media.textScaler.scale(16) > 20;
    return Align(
      alignment: Alignment.bottomCenter,
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: !scrollAll
              ? KeyboardAwareBottomSheet(
                  maxHeightFactor: maxHeightFactor,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  header: header,
                  body: retainedBody,
                  actions: actions,
                )
              : Padding(
                  padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                  child: SafeArea(
                    top: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            (media.size.height * maxHeightFactor -
                                    media.viewInsets.bottom)
                                .clamp(160, double.infinity),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            header,
                            const SizedBox(height: 8),
                            retainedBody,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
