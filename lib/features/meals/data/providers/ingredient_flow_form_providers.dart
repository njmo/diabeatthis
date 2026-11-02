import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mealIngredientFormKeyProvider = Provider.autoDispose(
  (ref) => GlobalKey<FormState>(),
);
final ingredientSearchFormKeyProvider = Provider.autoDispose(
  (ref) => GlobalKey<FormState>(),
);
final ingredientFormKeyProvider = Provider.autoDispose(
  (ref) => GlobalKey<FormState>(),
);
