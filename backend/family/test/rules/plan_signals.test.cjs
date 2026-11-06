'use strict';
const test=require('node:test');const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc}=require('firebase/firestore');
test('plan metadata is own-account only; plan contents remain callable-only',async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-diabeatthis-family',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
  try{
    await env.withSecurityRulesDisabled(async context=>{
      const db=context.firestore();await setDoc(doc(db,'familyAccounts/signal-plan-parent'),{familyId:'family',role:'managingCaregiver'});await setDoc(doc(db,'familyPlanSignals/signal-plan-parent'),{operationId:'test'});
    });
    const claims={email_verified:true,firebase:{sign_in_provider:'google.com'}};
    const own=env.authenticatedContext('signal-plan-parent',claims).firestore();
    await assertSucceeds(getDoc(doc(own,'familyPlanSignals/signal-plan-parent')));
    await assertFails(getDoc(doc(own,'familyPlanSignals/another-parent')));
    await assertFails(setDoc(doc(own,'familyPlanSignals/signal-plan-parent'),{operationId:'forged'}));
    await assertFails(getDoc(doc(own,'userMirrors/child/plans/test')));
    const stranger=env.authenticatedContext('stranger-plan-parent',claims).firestore();await assertFails(getDoc(doc(stranger,'familyPlanSignals/stranger-plan-parent')));
  }finally{await env.cleanup();}
});
