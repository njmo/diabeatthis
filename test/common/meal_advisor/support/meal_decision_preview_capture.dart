import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const mealDemoPreviewBoundary = ValueKey('meal-demo-preview');

/// Optional local preview export; ordinary regression runs need no host files.
Future<TextTheme> mealDemoPreviewTextTheme(WidgetTester tester) async {
  const fontPath = String.fromEnvironment('MEAL_DEMO_FONT');
  if (fontPath.isEmpty) return ThemeData.dark().textTheme;
  await tester.runAsync(() async {
    final bytes = await File(fontPath).readAsBytes();
    final loader = FontLoader('MealDemoPreview')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  return ThemeData.dark().textTheme.apply(fontFamily: 'MealDemoPreview');
}

Future<void> captureMealDemo(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('MEAL_DEMO_CAPTURES');
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(mealDemoPreviewBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
