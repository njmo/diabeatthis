'use strict';
const test=require('node:test');const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,getDocs,collection}=require('firebase/firestore');
test('meal decision signals are private and all workflow content remains callable-only',async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-diabeatthis-family',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
  try{
    await env.withSecurityRulesDisabled(async context=>{
      const db=context.firestore();
      await setDoc(doc(db,'familyAccounts/decision-parent'),{familyId:'decision-family',role:'managingCaregiver'});
      await setDoc(doc(db,'familyMealDecisionSignals/decision-parent'),{requestId:'opaque'});
    });
    const claims={email_verified:true,firebase:{sign_in_provider:'google.com'}};
    const own=env.authenticatedContext('decision-parent',claims).firestore();
    await assertSucceeds(getDoc(doc(own,'familyMealDecisionSignals/decision-parent')));
    await assertFails(getDoc(doc(own,'familyMealDecisionSignals/other-parent')));
    await assertFails(getDocs(collection(own,'familyMealDecisionSignals')));
    await assertFails(setDoc(doc(own,'familyMealDecisionSignals/decision-parent'),{requestId:'forged'}));
    for (const path of ['userMirrors/child/mealDecisions/request','familyMealDecisionPreferences/decision-parent','familyMealDecisionNotifications/job','familyMealDecisionDispatches/job','familyMealDecisionDeviceBindings/token']) {
      await assertFails(getDoc(doc(own,path)));await assertFails(setDoc(doc(own,path),{forged:true}));
    }
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'familyMealDecisionSignals/decision-parent')));
    await assertFails(getDoc(doc(env.authenticatedContext('decision-parent',{email_verified:true,firebase:{sign_in_provider:'password'}}).firestore(),'familyMealDecisionSignals/decision-parent')));
    await assertFails(getDoc(doc(env.authenticatedContext('decision-stranger',claims).firestore(),'familyMealDecisionSignals/decision-stranger')));
  }finally{await env.cleanup();}
});
