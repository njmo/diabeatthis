'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getMessaging} = require('firebase-admin/messaging');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {createDecisionNotifications} = require('./common/decision_notifications.cjs');
const {createMealDecisionService} = require('./common/meal_decision_service.cjs');
const {defineSecret} = require('firebase-functions/params');
const pairingHmacKey = defineSecret('PAIRING_HMAC_KEY');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {requireGoogle, profile, FamilyError} = require('./common/security.cjs');
const {createFamilyService} = require('./common/family_service.cjs');
const {createPlanService} = require('./common/plan_service.cjs');
const {createMirrorService} = require('./common/mirror_service.cjs');
const {createChatService} = require('./common/chat_service.cjs');
const {createChatNotifications} = require('./common/chat_notifications.cjs');
const {createChatTreatment} = require('./common/chat_treatment.cjs');
const {createChatCleanup} = require('./common/chat_cleanup.cjs');
const {createChatOrphanCleanup} = require('./common/chat_orphan_cleanup.cjs');
initializeApp();
const auth = getAuth();
const mirror = createMirrorService({store: getFirestore()});
const plans = createPlanService({store: getFirestore()});
const notifications = createDecisionNotifications({store: getFirestore(), messaging: getMessaging()});
const decisions = createMealDecisionService({store: getFirestore()});
const chat = createChatService({store: getFirestore()});
const chatTreatment = createChatTreatment({store: getFirestore(), chat});
const chatNotifications = createChatNotifications({store: getFirestore(), chat, messaging: getMessaging()});
const chatCleanup = createChatCleanup({store: getFirestore(), chat});
const chatOrphanCleanup = createChatOrphanCleanup({store: getFirestore(), chat});
exports.cleanupFamilyChatMessages = onSchedule({schedule: 'every 1 minutes', region: 'europe-west1',
  maxInstances: 1, timeoutSeconds: 120, retryCount: 3}, async () => {
  await chatCleanup.run();
  await chatOrphanCleanup.run();
});
exports.revokeFamilyChatNotifications = onCall({region: 'europe-west1', enforceAppCheck: true, maxInstances: 4, timeoutSeconds: 20}, async request => {
  if (!request.app || request.app.alreadyConsumed) throw new HttpsError('failed-precondition', 'Device attestation is required');
  try { return await chatNotifications.revoke(request.data); }
  catch (error) {
    if (error instanceof FamilyError) throw new HttpsError(error.code, error.message, error.details);
    throw new HttpsError('unavailable', 'Device registration is temporarily unavailable');
  }
});
const service = {mealDecision: decisions.execute, registerMealDecisionNotifications: notifications.register, claimPlan:plans.claim,submitPlan:plans.submit,fetchPlans:plans.fetch,acknowledgePlan:plans.acknowledge,...createFamilyService({store: getFirestore(), auth}), registerMirror: mirror.register, publishMirror: mirror.publish, fetchMirror: mirror.fetch, fetchMirrorView: mirror.fetchView, searchMirrorIngredients: mirror.searchIngredients};
for (const [name, operation] of Object.entries({
  registerFamilyChatNotifications: 'chatNotifications',
  claimFamilyChatTreatment: 'chatTreatmentClaim', completeFamilyChatTreatment: 'chatTreatmentComplete',
  fetchFamilyChatShortcuts: 'chatShortcuts', saveFamilyChatShortcuts: 'chatSaveShortcuts', orderFamilyChatShortcuts: 'chatOrderShortcuts',
  getFamilyChatConfig: 'chatConfig', configureFamilyChat: 'chatConfigure', clearFamilyChatHistory: 'chatClearHistory', reserveFamilyChatOperations: 'chatReserve', sendFamilyChatMessage: 'chatSend', fetchFamilyChatMessages: 'chatFetch', fetchFamilyChatConversations: 'chatConversations', acknowledgeFamilyChatMessage: 'chatAcknowledge', fetchFamilyChatMessageStates: 'chatStates', acknowledgeFamilyChatMessages: 'chatAcknowledgeBatch',
  mealDecision: 'mealDecision', registerMealDecisionNotifications: 'registerMealDecisionNotifications',
  claimFamilyPlan:'claimPlan', submitFamilyPlan:'submitPlan', fetchFamilyPlans:'fetchPlans', acknowledgeFamilyPlan:'acknowledgePlan',
  registerFamilyMirror: 'registerMirror', publishFamilyMirror: 'publishMirror', fetchFamilyMirror: 'fetchMirror', fetchFamilyMirrorView: 'fetchMirrorView',
  searchFamilyMirrorIngredients: 'searchMirrorIngredients',
  createFamilyInvite: 'createInvite', requestFamilyJoin: 'requestJoin', requestFamilyJoinByCode: 'requestJoinByCode', decideFamilyJoin: 'decide',
  getFamilyStatus: 'status', disconnectFamilyMember: 'disconnect', finalizeFamilySetup: 'finalize',
})) {
  exports[name] = onCall({secrets: [pairingHmacKey], region: 'europe-west1', enforceAppCheck: true, maxInstances: 4, concurrency: 20, timeoutSeconds: 20,
    ...(name === 'fetchFamilyMirrorView' ? {invoker: 'public'} : {}),
  }, async request => {
    try {
      const uid = requireGoogle(request);
      // Check revocation and disabled accounts, not only the callable's cached token validation.
      const bearer = request.rawRequest.headers.authorization;
      if (typeof bearer !== 'string' || !bearer.startsWith('Bearer ')) throw new FamilyError('unauthenticated');
      const verified = await auth.verifyIdToken(bearer.slice(7), true);
      if (verified.uid !== uid) throw new FamilyError('unauthenticated');
      profile(await auth.getUser(uid));
      const chatOperations = {chatConfig: chat.getConfig, chatConfigure: chat.configure, chatClearHistory: chat.clearHistory, chatReserve: chat.reserve, chatSend: chat.send, chatFetch: chat.fetch, chatConversations: chat.conversations, chatAcknowledge: chat.acknowledge, chatStates: chat.states, chatAcknowledgeBatch: chat.acknowledgeBatch};
      Object.assign(chatOperations, {chatShortcuts: chat.shortcuts, chatSaveShortcuts: chat.saveShortcuts, chatOrderShortcuts: chat.orderShortcuts});
      chatOperations.chatNotifications = chatNotifications.register;
      chatOperations.chatTreatmentClaim = chatTreatment.claim;
      chatOperations.chatTreatmentComplete = chatTreatment.complete;
      return await (chatOperations[operation] ?? service[operation])(uid, request.data);
    } catch (error) {
      if (error instanceof FamilyError) throw new HttpsError(error.code, error.message, error.details);
      // Never return tokens, profiles, credentials or backend exception details.
      throw new HttpsError('unavailable', 'Family service is temporarily unavailable');
    }
  });
}
// Message recipients are always derived and authorized by chat_service.
// There is deliberately no client-addressable arbitrary push endpoint.
exports.dispatchFamilyChatNotification = onDocumentCreated({document: 'familyChatNotificationJobs/{jobId}', region: 'europe-west1', retry: true}, async event => {
  await chatNotifications.dispatch(event.params.jobId);
});

exports.dispatchMealDecisionNotification = onDocumentCreated({document: 'familyMealDecisionNotifications/{jobId}', region: 'europe-west1', retry: true}, async event => {
  await notifications.dispatch(event.params.jobId, event.data?.data());
});
