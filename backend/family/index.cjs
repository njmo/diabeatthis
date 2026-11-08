'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getMessaging} = require('firebase-admin/messaging');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {createDecisionNotifications} = require('./common/decision_notifications.cjs');
const {createMealDecisionService} = require('./common/meal_decision_service.cjs');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {requireGoogle, profile, FamilyError} = require('./common/security.cjs');
const {createFamilyService} = require('./common/family_service.cjs');
const {createPlanService} = require('./common/plan_service.cjs');
const {createMirrorService} = require('./common/mirror_service.cjs');
initializeApp();
const auth = getAuth();
const mirror = createMirrorService({store: getFirestore()});
const plans = createPlanService({store: getFirestore()});
const notifications = createDecisionNotifications({store: getFirestore(), messaging: getMessaging()});
const decisions = createMealDecisionService({store: getFirestore()});
const service = {mealDecision: decisions.execute, registerMealDecisionNotifications: notifications.register, claimPlan:plans.claim,submitPlan:plans.submit,fetchPlans:plans.fetch,acknowledgePlan:plans.acknowledge,...createFamilyService({store: getFirestore(), auth}), registerMirror: mirror.register, publishMirror: mirror.publish, fetchMirror: mirror.fetch};
for (const [name, operation] of Object.entries({
  mealDecision: 'mealDecision', registerMealDecisionNotifications: 'registerMealDecisionNotifications',
  claimFamilyPlan:'claimPlan', submitFamilyPlan:'submitPlan', fetchFamilyPlans:'fetchPlans', acknowledgeFamilyPlan:'acknowledgePlan',
  registerFamilyMirror: 'registerMirror', publishFamilyMirror: 'publishMirror', fetchFamilyMirror: 'fetchMirror',
  createFamilyInvite: 'createInvite', requestFamilyJoin: 'requestJoin', decideFamilyJoin: 'decide',
  getFamilyStatus: 'status', disconnectFamilyMember: 'disconnect', finalizeFamilySetup: 'finalize',
})) {
  exports[name] = onCall({region: 'europe-west1', enforceAppCheck: true, maxInstances: 4, concurrency: 20, timeoutSeconds: 20}, async request => {
    try {
      const uid = requireGoogle(request);
      // Check revocation and disabled accounts, not only the callable's cached token validation.
      const bearer = request.rawRequest.headers.authorization;
      if (typeof bearer !== 'string' || !bearer.startsWith('Bearer ')) throw new FamilyError('unauthenticated');
      const verified = await auth.verifyIdToken(bearer.slice(7), true);
      if (verified.uid !== uid) throw new FamilyError('unauthenticated');
      profile(await auth.getUser(uid));
      return await service[operation](uid, request.data);
    } catch (error) {
      if (error instanceof FamilyError) throw new HttpsError(error.code, error.message);
      // Never return tokens, profiles, credentials or backend exception details.
      throw new HttpsError('unavailable', 'Family service is temporarily unavailable');
    }
  });
}
// There is deliberately no client-addressable send-notification or messaging endpoint.
// Those features must derive recipients from current membership server-side when introduced.

exports.dispatchMealDecisionNotification = onDocumentCreated({document: 'familyMealDecisionNotifications/{jobId}', region: 'europe-west1', retry: true}, async event => {
  await notifications.dispatch(event.params.jobId, event.data?.data());
});
