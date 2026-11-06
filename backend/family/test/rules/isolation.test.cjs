'use strict';
const test = require('node:test'); const fs = require('node:fs');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, collection, getDocs} = require('firebase/firestore');
let env;
test.before(async () => { env = await initializeTestEnvironment({projectId: 'demo-diabeatthis-family', firestore: {host: '127.0.0.1', port: 8087, rules: fs.readFileSync('firestore.rules', 'utf8')}}); });
test.after(async () => { await env?.cleanup(); });
test('all client identities are denied family reads, forged membership, messages and arbitrary recipients', async () => {
  for (const uid of [null, 'child', 'parent', 'stranger']) {
    const db = uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
    for (const path of ['families/other', 'families/other/members/stranger', 'families/other/messages/message', 'pairingInvites/secret', 'familyAccounts/child', 'familyDevices/victim/devices/token', 'familyNotificationJobs/job']) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), {role: 'managingCaregiver', recipientUid: 'victim', token: 'attacker'}));
    }
    await assertFails(getDocs(collection(db, 'families')));
  }
});
