import 'package:drift/drift.dart';

import '../../../domain/model/correction_bolus.dart';
import '../../../domain/model/extended_carb.dart';
import '../../../domain/model/manual_bolus.dart';
import '../../../domain/model/meal.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treat.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../drift/database_impl.dart' hide Meal;
import '../../config/data_source_config.dart';

extension LocalTreatmentMirrorMapper on Treatment {
  LocalTreatmentEventCompanion? toLocalMirrorCompanion(EventSource source) {
    final createdAt = this.createdAt;
    if (createdAt == null) return null;

    return LocalTreatmentEventCompanion.insert(
      source: source.storageValue,
      externalId: Value(_externalId(source)),
      treatmentType: _treatmentType,
      createdAt: createdAt.millisecondsSinceEpoch,
      nightscoutId: Value(_nightscoutId),
      carbs: Value(_carbs),
      insulin: Value(_insulin),
      durationMinutes: Value(_durationMinutes),
      targetBottom: Value(_targetBottom),
      targetTop: Value(_targetTop),
      notes: Value(_notes),
    );
  }

  String _externalId(EventSource source) {
    final remoteId = _nightscoutId;
    if (remoteId != null && remoteId.isNotEmpty) return remoteId;

    final timestamp = createdAt?.millisecondsSinceEpoch ?? 0;
    final valueParts = [
      _carbs,
      _insulin,
      _durationMinutes,
      _targetBottom,
      _targetTop,
    ].whereType<num>().join(':');

    return '${source.storageValue}:$_treatmentType:$timestamp:${id ?? 0}:$valueParts';
  }

  String get _treatmentType {
    return switch (this) {
      Meal() => 'Bolus Wizard',
      TemporaryTarget() => 'Temporary Target',
      CorrectionBolus() => 'Correction Bolus',
      ManualBolus() => 'Meal Bolus',
      Treat() => 'Carb Correction',
      ExtendedCarb() => 'Extended Carb',
      _ => runtimeType.toString(),
    };
  }

  String? get _nightscoutId {
    return switch (this) {
      Meal(:final nightscoutObjectId) => nightscoutObjectId,
      TemporaryTarget(:final nightscoutId) => nightscoutId,
      _ => null,
    };
  }

  double? get _carbs {
    return switch (this) {
      Meal(:final carbs) => carbs?.toDouble(),
      Treat(:final carbs) => carbs.toDouble(),
      ExtendedCarb(:final carbs) => carbs.toDouble(),
      _ => null,
    };
  }

  double? get _insulin {
    return switch (this) {
      Meal(:final insulin) => insulin,
      CorrectionBolus(:final insulin) => insulin,
      ManualBolus(:final insulin) => insulin,
      _ => null,
    };
  }

  int? get _durationMinutes {
    return switch (this) {
      TemporaryTarget(:final duration) => duration,
      ExtendedCarb(:final duration) => Duration(
        milliseconds: duration,
      ).inMinutes,
      _ => null,
    };
  }

  double? get _targetBottom {
    return switch (this) {
      TemporaryTarget(:final targetBottom) => targetBottom.toDouble(),
      _ => null,
    };
  }

  double? get _targetTop {
    return switch (this) {
      TemporaryTarget(:final targetTop) => targetTop.toDouble(),
      _ => null,
    };
  }

  String? get _notes {
    return switch (this) {
      Meal(:final notes) => notes,
      _ => null,
    };
  }
}
