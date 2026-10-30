import 'dart:io';

class FoodIconGenerationResult {
  const FoodIconGenerationResult({
    required this.file,
    required this.path,
    required this.generationTime,
    required this.saveTime,
    required this.byteCount,
    this.backgroundRemoved = false,
    this.originalFile,
    this.originalPath,
  });

  final File file;
  final String path;
  final Duration generationTime;
  final Duration saveTime;
  final int byteCount;
  final bool backgroundRemoved;
  final File? originalFile;
  final String? originalPath;

  Future<void> discardUnused({String? keepPath}) async {
    for (final entry in [
      (file: file, path: path),
      if (originalFile != null && originalPath != null)
        (file: originalFile!, path: originalPath!),
    ]) {
      if (entry.path == keepPath) continue;
      try {
        await entry.file.delete();
      } on FileSystemException {
        // A failed cleanup must not prevent using or canceling the preview.
      }
    }
  }
}
