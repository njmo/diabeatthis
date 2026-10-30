import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Only the fixed-size button participates in Scaffold's FAB geometry.
class AnchoredFabMenu extends HookWidget {
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;
  final List<Widget> actions;

  const AnchoredFabMenu({
    super.key,
    required this.open,
    required this.onToggle,
    required this.onDismiss,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final controller = useMemoized(OverlayPortalController.new);
    final link = useMemoized(LayerLink.new);
    useEffect(() {
      var active = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!active || !context.mounted) return;
        if (open) {
          controller.show();
        } else {
          controller.hide();
        }
      });
      return () => active = false;
    }, [open]);
    return CompositedTransformTarget(
      link: link,
      child: OverlayPortal(
        controller: controller,
        overlayChildBuilder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: const ColoredBox(color: Colors.black26),
              ),
            ),
            CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -16),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 250,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: actions,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            backgroundColor: dark
                ? const Color(0xFF343D44)
                : theme.colorScheme.primary,
            foregroundColor: dark ? Colors.white : theme.colorScheme.onPrimary,
            elevation: 0,
            highlightElevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            shape: const CircleBorder(),
            onPressed: onToggle,
            child: Icon(open ? Icons.close : Icons.add),
          ),
        ),
      ),
    );
  }
}
