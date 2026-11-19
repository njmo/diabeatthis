import 'child_ingredient_search_repository.dart';
import 'family_plan_submission_store.dart';
import 'submit_family_plan_use_case.dart';

class EditFamilyQuickTreatmentUseCase {
  EditFamilyQuickTreatmentUseCase(this.child, FamilyPlanSubmissionStore store)
    : _submit = SubmitFamilyPlanUseCase(
        child.transport,
        store,
        (uid) => uid == child.caregiverUid && child.isCurrent(),
      );

  static const _type = 'replaceQuickTreatmentItems';
  final ChildIngredientSearchRepository child;
  final SubmitFamilyPlanUseCase _submit;

  Future<({String sourceId, List<Map<String, dynamic>> rows, bool pending})>
  load() async {
    final uid = child.caregiverUid;
    final reserved = await _submit.submissions.pending(uid);
    if (reserved != null) await _submit.sendReserved(uid, reserved);
    final snapshot = await child.quickTreatmentEditorRows();
    final plans = await child.transport.call(
      'fetchFamilyPlans',
      {},
      expectedUid: uid,
      allowRequest: () async => child.isCurrent(),
    );
    if (!child.isCurrent() ||
        plans['ownerUid'] != child.childUid ||
        plans['sourceId'] != snapshot.sourceId) {
      throw StateError('The selected child mirror changed');
    }
    return (
      sourceId: snapshot.sourceId,
      rows: snapshot.rows,
      pending: (plans['plans'] as List).any(
        (plan) => plan['type'] == _type && plan['status'] == 'pending',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> ingredientRows(
    int id,
    String sourceId,
  ) async {
    final snapshot = await child.quickTreatmentEditorRows(ingredientId: id);
    if (snapshot.sourceId != sourceId) {
      throw StateError('The selected child mirror changed');
    }
    return snapshot.rows;
  }

  Future<void> save({
    required String sourceId,
    required List<Map<String, dynamic>> rows,
    required List<Map<String, Object?>> items,
  }) async {
    await _submit(
      type: _type,
      targetId: null,
      values: {'items': items},
      baseRows: rows,
      expectedSource: sourceId,
      expectedUid: child.caregiverUid,
    );
  }
}
