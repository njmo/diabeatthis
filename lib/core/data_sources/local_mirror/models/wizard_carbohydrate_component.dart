import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/model/treat.dart' as domain;
import '../../../drift/database_impl.dart';

/// Original intake retained inside its calculator for replay and invalidation.
class WizardCarbohydrateComponent {
  final String source;
  final String? externalId;
  final DateTime createdAt;
  final double? carbs;
  final int? receivedAt;

  const WizardCarbohydrateComponent({
    required this.source,
    required this.externalId,
    required this.createdAt,
    required this.carbs,
    this.receivedAt,
  });

  factory WizardCarbohydrateComponent.fromCompanion(TreatCompanion record) {
    if (!record.source.present || !record.createdAt.present) {
      throw ArgumentError(
        'A carbohydrate component requires its source and timestamp',
      );
    }
    return WizardCarbohydrateComponent(
      source: record.source.value,
      externalId: record.externalId.present ? record.externalId.value : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(record.createdAt.value),
      carbs: record.carbs.present ? record.carbs.value : null,
      receivedAt: record.receivedAt.present ? record.receivedAt.value : null,
    );
  }

  factory WizardCarbohydrateComponent.fromJson(String encoded) {
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return WizardCarbohydrateComponent(
      source: json['source'] as String,
      externalId: json['externalId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      carbs: (json['carbs'] as num?)?.toDouble(),
      receivedAt: json['receivedAt'] as int?,
    );
  }

  String toJson() => jsonEncode({
    'source': source,
    'externalId': externalId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'carbs': carbs,
    'receivedAt': receivedAt,
  });

  TreatCompanion toCompanion() => TreatCompanion.insert(
    source: source,
    externalId: Value(externalId),
    createdAt: Value(createdAt.millisecondsSinceEpoch),
    carbs: Value(carbs),
    receivedAt: receivedAt == null ? const Value.absent() : Value(receivedAt!),
  );

  domain.Treat get treatment => domain.Treat(
    externalId: externalId,
    createdAt: createdAt,
    carbs: carbs?.round() ?? 0,
  );
}
