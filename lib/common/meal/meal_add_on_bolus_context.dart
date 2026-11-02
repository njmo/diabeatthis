import 'dart:convert';

/// Durable progress for an add-on. Only accepted calculator responses increase
/// [coveredCarbs]; presenting an AAPS instruction never confirms a bolus.
class MealAddOnBolusContext {
  const MealAddOnBolusContext({
    required this.originalStatus,
    required this.eatingStartedAt,
    required this.requestedAt,
    DateTime? bolusWindowStartedAt,
    required this.coveredCarbs,
    required this.statusCoveredCarbs,
    required this.reportedExtendedCarbs,
    required this.requestedCarbs,
    required this.requestedExtendedCarbs,
    required this.awaitingBolus,
    required this.bolusConfirmed,
    this.acceptedWizardKeys = const [],
  }) : bolusWindowStartedAt = bolusWindowStartedAt ?? requestedAt;

  final String originalStatus;
  final DateTime? eatingStartedAt;
  final DateTime requestedAt;
  final DateTime bolusWindowStartedAt;
  final double coveredCarbs;
  final double statusCoveredCarbs;
  // Comparison baseline, never proof of delivery. New food-first meals keep it
  // at zero until final consumption so their first eCarbs suggestion is actual.
  final int reportedExtendedCarbs;
  final int requestedCarbs;
  final int requestedExtendedCarbs;
  final bool awaitingBolus;
  final bool bolusConfirmed;
  final List<String> acceptedWizardKeys;

  /// A completed calculator step leaves eating as the primary action. Retain
  /// eCarbs instructions as data; a carb bolus does not confirm their delivery.
  bool get showCalculatorAction =>
      awaitingBolus ||
      (requestedExtendedCarbs > 0 &&
          !acceptedWizardKeys.any((key) {
            if (!key.startsWith('at:')) return false;
            final at = int.tryParse(key.substring(3));
            return at != null &&
                at ~/ 1000 >= requestedAt.millisecondsSinceEpoch ~/ 1000;
          }));

  static MealAddOnBolusContext? decode(String? value) {
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported meal add-on context version');
    }
    final covered = (json['coveredCarbs'] as num).toDouble();
    final statusCovered = (json['statusCoveredCarbs'] as num).toDouble();
    final requestedCarbs = json['requestedCarbs'] as int;
    final requestedExtendedCarbs = json['requestedExtendedCarbs'] as int;
    final reportedExtendedCarbs = json['reportedExtendedCarbs'] as int;
    if (!covered.isFinite ||
        covered < 0 ||
        !statusCovered.isFinite ||
        statusCovered < 0 ||
        requestedCarbs < 0 ||
        requestedExtendedCarbs < 0 ||
        reportedExtendedCarbs < 0) {
      throw const FormatException('Invalid meal add-on carbohydrate amounts');
    }
    return MealAddOnBolusContext(
      originalStatus: json['originalStatus'] as String,
      eatingStartedAt: json['eatingStartedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['eatingStartedAt'] as int),
      requestedAt: DateTime.fromMillisecondsSinceEpoch(
        json['requestedAt'] as int,
      ),
      bolusWindowStartedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['bolusWindowStartedAt'] ?? json['requestedAt']) as int,
      ),
      coveredCarbs: covered,
      statusCoveredCarbs: statusCovered,
      reportedExtendedCarbs: reportedExtendedCarbs,
      requestedCarbs: requestedCarbs,
      requestedExtendedCarbs: requestedExtendedCarbs,
      awaitingBolus: json['awaitingBolus'] as bool,
      bolusConfirmed: json['bolusConfirmed'] as bool,
      acceptedWizardKeys: (json['acceptedWizardKeys'] as List).cast<String>(),
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'originalStatus': originalStatus,
    'eatingStartedAt': eatingStartedAt?.millisecondsSinceEpoch,
    'requestedAt': requestedAt.millisecondsSinceEpoch,
    'bolusWindowStartedAt': bolusWindowStartedAt.millisecondsSinceEpoch,
    'coveredCarbs': coveredCarbs,
    'statusCoveredCarbs': statusCoveredCarbs,
    'reportedExtendedCarbs': reportedExtendedCarbs,
    'requestedCarbs': requestedCarbs,
    'requestedExtendedCarbs': requestedExtendedCarbs,
    'awaitingBolus': awaitingBolus,
    'bolusConfirmed': bolusConfirmed,
    'acceptedWizardKeys': acceptedWizardKeys,
  });

  MealAddOnBolusContext copyWith({
    DateTime? requestedAt,
    double? coveredCarbs,
    int? reportedExtendedCarbs,
    int? requestedCarbs,
    int? requestedExtendedCarbs,
    bool? awaitingBolus,
    bool? bolusConfirmed,
    List<String>? acceptedWizardKeys,
  }) => MealAddOnBolusContext(
    originalStatus: originalStatus,
    eatingStartedAt: eatingStartedAt,
    requestedAt: requestedAt ?? this.requestedAt,
    bolusWindowStartedAt: bolusWindowStartedAt,
    coveredCarbs: coveredCarbs ?? this.coveredCarbs,
    statusCoveredCarbs: statusCoveredCarbs,
    reportedExtendedCarbs: reportedExtendedCarbs ?? this.reportedExtendedCarbs,
    requestedCarbs: requestedCarbs ?? this.requestedCarbs,
    requestedExtendedCarbs:
        requestedExtendedCarbs ?? this.requestedExtendedCarbs,
    awaitingBolus: awaitingBolus ?? this.awaitingBolus,
    bolusConfirmed: bolusConfirmed ?? this.bolusConfirmed,
    acceptedWizardKeys: acceptedWizardKeys ?? this.acceptedWizardKeys,
  );
}
