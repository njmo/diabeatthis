import 'package:flutter/material.dart';

class MealMetricTileData {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  const MealMetricTileData({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });
}

class MealCompactMetricData {
  final String label;
  final String value;

  const MealCompactMetricData({required this.label, required this.value});
}
