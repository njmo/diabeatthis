'use strict';
const fs = require('node:fs'); const test = require('node:test');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, deleteDoc} = require('firebase/firestore');
test('only an active owner can listen to their own metadata signal; data and writes remain closed', async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-diabeatthis-family', firestore: {host: '127.0.0.1', port: 8087, rules: fs.readFileSync('firestore.rules', 'utf8')}});
  try {
    await env.withSecurityRulesDisabled(async context => {
      const db = context.firestore(); await setDoc(doc(db, 'familyAccounts/signal-parent'), {familyId: 'test-family', role: 'managingCaregiver'});
      await setDoc(doc(db, 'familyMirrorSignals/signal-parent'), {ownerUid: 'signal-child', sequence: 1, mealHeadersRevision: 1});
      await setDoc(doc(db, 'userMirrors/signal-child/mealHeaders/1'), {record: {id: '1'}});
    });
    const claims = {email_verified: true, firebase: {sign_in_provider: 'google.com'}};
    const parent = env.authenticatedContext('signal-parent', claims).firestore(); const stranger = env.authenticatedContext('signal-stranger', claims).firestore();
    await assertSucceeds(getDoc(doc(parent, 'familyMirrorSignals/signal-parent')));
    await assertFails(getDoc(doc(stranger, 'familyMirrorSignals/signal-parent')));
    await assertFails(setDoc(doc(parent, 'familyMirrorSignals/signal-parent'), {sequence: 500}));
    await assertFails(getDoc(doc(parent, 'userMirrors/signal-child/entities/portions_1')));
    await assertFails(getDoc(doc(parent, 'userMirrors/signal-child/mealHeaders/1')));
    await env.withSecurityRulesDisabled(context => deleteDoc(doc(context.firestore(), 'familyAccounts/signal-parent')));
    await assertFails(getDoc(doc(parent, 'familyMirrorSignals/signal-parent')));
  } finally { await env.cleanup(); }
});
