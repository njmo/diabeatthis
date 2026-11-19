import 'dart:math';

import '../backend/authenticated_callable_transport.dart';
import 'family_plan_scope.dart';
import 'family_plan_submission_store.dart';

class SubmitFamilyPlanUseCase {
  const SubmitFamilyPlanUseCase(
    this.transport,
    this.submissions,
    this.isCurrent,
  );

  final AuthenticatedCallableTransport transport;
  final FamilyPlanSubmissionStore submissions;
  final bool Function(String uid) isCurrent;

  Future<({Map<String, dynamic> plan, Map<String, dynamic> receipt})> call({
    required String type,
    required int? targetId,
    required Map<String, dynamic> values,
    required List<Map<String, dynamic>> baseRows,
    required String expectedSource,
    required String expectedUid,
  }) async {
    if (!isCurrent(expectedUid)) throw StateError('Family changed');
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final plan = <String, dynamic>{
      'id': id,
      'sourceId': expectedSource,
      'type': type,
      'targetId': targetId,
      'values': values,
    };
    plan['expected'] = familyPlanVersions(familyPlanScope(baseRows, plan));
    final reserved = await submissions.reserve(expectedUid, plan);
    final receipt = await sendReserved(expectedUid, reserved);
    return (plan: reserved, receipt: receipt);
  }

  Future<Map<String, dynamic>> sendReserved(
    String account,
    Map<String, dynamic> plan,
  ) async {
    if (!isCurrent(account)) throw StateError('Family changed');
    try {
      final result = await transport.call(
        'submitFamilyPlan',
        plan,
        expectedUid: account,
        allowRequest: () async => isCurrent(account),
      );
      if (result['id'] != plan['id'] ||
          !['pending', 'applied', 'rejected'].contains(result['status'])) {
        throw StateError('Invalid submission receipt');
      }
      await submissions.clear(account, plan['id'] as String);
      return result;
    } on CallableFailure catch (error) {
      if ([
        'invalid-argument',
        'permission-denied',
        'failed-precondition',
        'already-exists',
      ].contains(error.rejectionCode ?? error.code)) {
        await submissions.clear(account, plan['id'] as String);
      }
      rethrow;
    }
  }
}
