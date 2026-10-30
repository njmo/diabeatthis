import 'dart:io';

import 'package:flutter/material.dart';

import '../storage/local_image_store.dart';

class LocalStoredImage extends StatefulWidget {
  const LocalStoredImage({
    super.key,
    required this.path,
    required this.size,
    required this.placeholder,
  });

  final String path;
  final double size;
  final Widget placeholder;

  @override
  State<LocalStoredImage> createState() => LocalStoredImageState();
}

class LocalStoredImageState extends State<LocalStoredImage> {
  late Future<File> file;

  @override
  void initState() {
    super.initState();
    file = const LocalImageStore().resolve(widget.path);
  }

  @override
  void didUpdateWidget(covariant LocalStoredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      file = const LocalImageStore().resolve(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: file,
    builder: (context, snapshot) => snapshot.hasData
        ? Image.file(
            snapshot.requireData,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context))
                .ceil(),
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => widget.placeholder,
          )
        : widget.placeholder,
  );
}
