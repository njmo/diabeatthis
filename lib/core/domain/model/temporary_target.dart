import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'temporary_target.freezed.dart';
part 'temporary_target.g.dart';

@Freezed(unionKey: 'kind')
abstract class TemporaryTarget with _$TemporaryTarget implements Treatment {
  const TemporaryTarget._();

  const factory TemporaryTarget({
    required int id,
    required String nightscoutId,
    required DateTime createdAt,
    required int durationInMiliseconds,
    required int duration,
    required int targetBottom,
    required int targetTop,
  }) = _TemporaryTarget;

  factory TemporaryTarget.fromJson(Map<String, dynamic> json) =>
      _$TemporaryTargetFromJson(json);

  @override
  String getParts() => "⏳ ${duration}min";

  @override
  IconData getIcon() => Icons.timer;

  @override
  Color getColor() => Colors.blue;

  bool isActive() =>
      clock.now().isBefore(createdAt.add(Duration(minutes: duration)));
}
