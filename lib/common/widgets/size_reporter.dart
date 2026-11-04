import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({
    super.key,
    required this.onSizeChanged,
    required super.child,
  });
  final ValueChanged<Size> onSizeChanged;
  @override
  RenderSizeReporter createRenderObject(BuildContext context) =>
      RenderSizeReporter(onSizeChanged);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderSizeReporter renderObject,
  ) => renderObject.onSizeChanged = onSizeChanged;
}

class RenderSizeReporter extends RenderProxyBox {
  RenderSizeReporter(this.onSizeChanged);
  ValueChanged<Size> onSizeChanged;
  Size? reportedSize;
  @override
  void performLayout() {
    super.performLayout();
    if (reportedSize == size) return;
    reportedSize = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSizeChanged(measured);
    });
  }
}
