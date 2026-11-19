# Family pairing backend

This codebase provides Google-authenticated, App Check-enforced callable endpoints in `europe-west1`:

- `createFamilyInvite`: child-owned family activation and a five-minute, single-use QR secret; explicit UI action only.
- `requestFamilyJoin`: reserve an invitation for the authenticated candidate; no access is granted.
- `decideFamilyJoin`: first manager approved by the child; subsequent managers approved by an active manager.
- `getFamilyStatus`: caller's own roster and approvable candidate only; no family selector accepted.
- `disconnectFamilyMember`: server-authorized unlinking: a caregiver can leave their own family, including when they are the only caregiver.
- `finalizeFamilySetup`: confirm that setup context grants no special removal authority.

Profiles come from Firebase Auth's Google provider, not client data. Both parents are managing caregivers. One family per account, maximum six members including the child. All writes and reads are backend-only. Invitations retain only a secret hash; they contain no child UID in the QR. A stolen QR can cause a pending request or denial of service until replaced, but cannot grant access without explicit approval. Verify the displayed Google email before approving.

Children cannot remove an approved caregiver, including during initial setup. Client-supplied initialSetup flags are rejected. A pending first-caregiver request can be rejected before approval; only managing caregivers may disconnect approved accounts. The child row on a caregiver phone unlinks the caller, never deletes the child. A local setup state, reinstall or regenerated invite never grants removal permissions. When the last caregiver leaves, pending invitations are cancelled; a new caregiver needs a fresh QR and explicit first-caregiver approval. Losing an account without access to sign in still requires a future verified recovery workflow; there is no insecure reset endpoint.

## Test locally

```sh
npm ci
npm test
npm run test:rules
```

The emulator command uses the isolated `demo-diabeatthis-family` project, not production. It tests deny rules and real concurrent Firestore transactions. Node 22 and a compatible Java runtime are required.

## Production release

No deployment is performed automatically. Review the actual deployed Firestore rules before publishing: Firebase rules replace the complete ruleset. The supplied ruleset denies all direct client access, including unrelated paths, and must not be merged with a permissive wildcard. The existing ingredient catalog uses Admin-backed callables and is a separate function codebase.

Confirm the intended Firebase project, Google authentication, App Check registrations (including pilot/debug distribution), billing and service-account permissions before release. Never disable App Check enforcement to make pairing work. Root `firebase.json` defines both function codebases; an approved release can target `functions:family` and the reviewed Firestore rules without replacing the ingredient-catalog functions.

Do not enable production callables while older permissive Firestore rules are deployed. Run a staging two-device test: first approval, second manager approval, rejected/expired/stolen invite, revoked user, Google account switch and app pause/resume. Keep invitations/rate-limit data subject to a defined retention policy; expiry checks use server time independently of cleanup.

## Messages and notifications

### Family chat implementation (source only, not deployed)

The chat service adds `getFamilyChatConfig`, `configureFamilyChat`,
`reserveFamilyChatOperations`, `sendFamilyChatMessage`,
`fetchFamilyChatMessages`, `fetchFamilyChatConversations` and
`acknowledgeFamilyChatMessage`. These retain verified Google, revocation and App
Check checks in the common callable entrypoint. Family membership, message
participant epochs, account/family opt-in, server expiry and bounded operation
tickets are checked by the service; no direct Firestore chat access is granted.

This is an incremental implementation. Push dispatch, physical cleanup and the
production client integration have later gates in
`docs/family-messaging-implementation-plan.md` at the repository root. Do not
roll out the feature before those gates pass. No Firebase deployment is implied
by a source commit. Test with Node 22 and Java 21 or newer; `npm run test:rules`
uses the isolated `demo-diabeatthis-family` emulator project.

The previously deployed pairing increment has no public chat endpoint. Direct message writes, device-token changes and notification jobs are denied. No arbitrary recipient UID, push token or FCM topic is accepted by a pairing callable. Messaging derives recipients from the current family roster server-side and must check revocation again at dispatch. Previously viewed data cannot be recalled from another device.

## Deployment record — 6 November 2026

Deployed all six family callables to `diabeatthis-e634c`, region `europe-west1`, Node.js 22 (second generation), together with the reviewed Firestore rules. The prior production rules already denied all direct client access. The ingredient-catalog functions were retained and remain active. Google authentication and billing were already enabled; existing App Check provider settings were retained, and callable enforcement remains enabled.

Post-deployment checks confirmed all six functions are ACTIVE, all six reject unauthenticated callable requests with HTTP 401, forged credentials are rejected with HTTP 401, and unauthenticated direct Firestore family reads return HTTP 403. The runtime identity has the existing project permissions needed for Auth and Firestore. These checks did not create family records. A positive two-device pairing test using Google accounts and the updated application is still required. No application installation was performed.

### Self-unlink correction — 6 November 2026

The caregiver's child-row Disconnect action resolves to the authenticated caregiver's membership, including for the sole caregiver. Explicit `self`, the caller UID and the caller's own family child UID are supported for compatibility with the previously installed client. Foreign family identifiers remain rejected, and the child's account and data are preserved. Leaving as the sole caregiver cancels open or pending invitations; re-pairing requires a fresh invitation. The corrected `disconnectFamilyMember` and `getFamilyStatus` functions have been deployed after explicit approval.

The compact themed QR is automatically revealed after expansion. An actual emulator-generated code was decoded successfully by the system barcode detector. Approval uses one explicit action alongside the Google identity. The emulator test application was updated while retaining its data; no update was installed on the physical caregiver phone.


## Selective mirror and caregiver plans

The source additionally exports registerFamilyMirror, publishFamilyMirror, fetchFamilyMirror, submitFamilyPlan, fetchFamilyPlans, claimFamilyPlan and acknowledgeFamilyPlan. These seven endpoints and the metadata-only read exceptions for familyMirrorSignals/familyPlanSignals were deployed on 6 November 2026 after explicit approval. All document content stays callable-only, with verified Google, App Check and server-derived family authorization.

`searchFamilyMirrorIngredients` uses the Firestore single-field array index on `entities.ingredientSearchPrefixes`. After deploying the updated `publishFamilyMirror`, run `node tools/backfill_ingredient_search.cjs PROJECT_ID` from `backend/family` to count older ingredient records missing the field, then rerun with `--apply` to index them before releasing the chat client. A concurrent write causes the precondition to fail, so rerun the same command to finish the remaining rows. The search function returns up to 20 results from the authenticated managing caregiver's paired child's mirror.

Plan proposals use per-record locks, bounded typed payloads/aggregate versions and a durable child journal before canonical publication and final ACK. Claim authorization permits only a bounded in-flight lease; claim tokens remain stable for journal recovery. Pending operations are capped at 50 per child, and submissions/reads/claims/ACKs have server-side budgets. No caregiver endpoint accepts execution states or arbitrary notification recipients. See the implementation plan for acceptance gates and limitations.


### Planning deployment record — 6 November 2026

Explicitly approved deployment to diabeatthis-e634c created all seven mirror/planning endpoints, updated the existing six family endpoints from the reviewed codebase, and released the reviewed Firestore rules. All thirteen family functions and both existing catalog functions report ACTIVE in europe-west1. All seven new endpoints reject unauthenticated callable requests with HTTP 401; submitFamilyPlan also rejects forged authentication/App Check credentials with HTTP 401. Unauthenticated direct reads of mirror entities, plan documents and plan metadata return HTTP 403. These checks were read-only and created no family/plan data. A positive two-device acceptance test remains required.

The ARM64 Android profile APK built successfully. No application was installed on either device. Start acceptance testing with family sync enabled on the child and Family plans open on the caregiver.
