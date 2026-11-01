import 'package:flutter/material.dart';

import '../keyboard_aware_bottom_sheet.dart';
import 'meal_start_header.dart';

class MealStartSheet extends StatelessWidget {
  const MealStartSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    this.onBack,
    this.onClose,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget actions;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    widthFactor: 1,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            final header = MealStartHeader(
              title: title,
              subtitle: subtitle,
              onBack: onBack,
              onClose: onClose,
            );
            // Keep every control reachable when fixed actions would crowd out the body.
            if (constraints.maxHeight < 600 ||
                media.textScaler.scale(16) > 20) {
              return Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          (media.size.height * 0.9 - media.viewInsets.bottom)
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
                          body,
                          const SizedBox(height: 12),
                          actions,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return KeyboardAwareBottomSheet(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              header: header,
              body: body,
              actions: actions,
            );
          },
        ),
      ),
    ),
  );
}
