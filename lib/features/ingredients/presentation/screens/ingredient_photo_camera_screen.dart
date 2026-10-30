import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/media/camera_crop_geometry.dart';
import '../../../../core/media/framed_camera_session.dart';
import '../widgets/ingredient_photo_camera_preview.dart';

class IngredientPhotoCameraScreen extends StatefulWidget {
  final String title;
  final String instructions;
  final int maxDimension;

  const IngredientPhotoCameraScreen({
    super.key,
    required this.title,
    required this.instructions,
    required this.maxDimension,
  });

  @override
  State<IngredientPhotoCameraScreen> createState() =>
      IngredientPhotoCameraScreenState();
}

class IngredientPhotoCameraScreenState
    extends State<IngredientPhotoCameraScreen>
    with WidgetsBindingObserver {
  final session = FramedCameraSession();
  bool wholePhoto = false;
  bool wideFrame = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(session.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(session.start());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(session.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    super.dispose();
  }

  Future<void> capture(Rect selection) async {
    final path = await session.capture(
      selection,
      widget.maxDimension,
      wholePhoto: wholePhoto,
    );
    if (path != null) {
      await session.stop();
      if (mounted) Navigator.of(context).pop(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final camera = session.camera;
        final ready = camera != null && camera.value.isInitialized;
        final selection = wholePhoto
            ? const Rect.fromLTWH(0, 0, 1, 1)
            : cameraFrameSelection(
                Size(ready ? 1 / camera.value.aspectRatio : 0.75, 1),
                wideFrame ? 2.5 : 1,
              );
        return PopScope(
          canPop: !session.busy,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) unawaited(session.stop());
          },
          child: Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(widget.instructions),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: Colors.black,
                      child: ready
                          ? IngredientPhotoCameraPreview(
                              controller: camera,
                              selection: selection,
                            )
                          : Center(
                              child: session.failed
                                  ? Text(
                                      lang.ingredientCameraUnavailable,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : const CircularProgressIndicator(),
                            ),
                    ),
                  ),
                  if (session.failed && ready)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(lang.photoCropFailed),
                    ),
                  if (session.failed && !ready)
                    TextButton(
                      onPressed: session.start,
                      child: Text(lang.framedCameraRetry),
                    ),
                  SwitchListTile(
                    title: Text(lang.framedCameraWideText),
                    value: wideFrame,
                    onChanged: session.busy || wholePhoto
                        ? null
                        : (value) => setState(() => wideFrame = value),
                  ),
                  SwitchListTile(
                    title: Text(lang.photoCropUseWhole),
                    value: wholePhoto,
                    onChanged: session.busy
                        ? null
                        : (value) => setState(() => wholePhoto = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: session.busy
                        ? const CircularProgressIndicator()
                        : FilledButton.icon(
                            onPressed: ready ? () => capture(selection) : null,
                            icon: const Icon(Icons.camera_alt),
                            label: Text(lang.framedCameraCapture),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
