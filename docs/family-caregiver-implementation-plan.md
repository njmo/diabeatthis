# Family caregiver implementation plan

Status: patient startup regression baseline committed; step-based setup UI implemented with explicit session-only simulations for new features. Caregiver runtime and cloud integration remain pending.
Date: 2026-11-06.

## Purpose and agreed scope

Support parents of a child at school through one DiaBeatThis application with a patient/child device mode and a caregiver device mode. Provide a private shared family conversation, read-only access to the child's ingredients and execution state, and remote planning of meals and activities. The immediate communication scope is text and discreet quick replies, including questions with parent-defined answer options. Voice calls are outside the initial scope.

The feature addresses the need for school contact without relying on SMS notifications, which may contain AAPS commands, or requiring WhatsApp for this contact. Ordinary telephone capabilities remain independent of this feature.

This document records the decisions and proposed implementation boundaries from the planning conversation. Stage completion criteria describe future validation, not checks already performed.

## Non-negotiable behavior

- The child's local database remains the source of truth for ingredients, accepted plans, meal execution, and activity execution.
- Existing local meals, activities, ingredient editing, reminders, and monitoring work without internet, Firebase availability, or an authenticated online session.
- Starting or progressing a meal or activity never requires reading or validating its state in Firebase.
- Google authentication is required on both sides to activate and use family sharing. Expired authentication pauses cloud exchange; it does not disable local patient functionality.
- Local edits commit immediately. Cloud synchronization is asynchronous and recoverable after interruption.
- Caregivers cannot edit the child's ingredient catalog, meal execution states, activity execution states, or therapy execution facts.
- Caregivers can create plans, approve proposed activity plans, and request changes to the planned start of activities that have not started.
- A chat reply is communication, never automatic evidence of eating, bolus delivery, activity start, or activity completion.
- Authorization is enforced by Firestore Rules and backend checks, independently of visible buttons or knowledge of document IDs.
- Existing tests must not be edited or deleted without the user's explicit approval. Add regression coverage for the new behavior.
- Code and commit messages are in English; commits use the `codex:` prefix. UI strings use the existing l10n files. Format Dart only at the end of implementation work.

## Current repository findings

- Firebase Core, AI, and App Check exist; Firebase Auth, client Firestore, and FCM integration for this feature do not exist yet.
- `lib/core/data/provider/parent_controller_provider.dart` is a local UI flag, not authenticated remote caregiver functionality. Its semantics must not become the authorization model.
- `lib/app/bootstrap.dart` initializes Android alarm/foreground communication facilities. `lib/app/app.dart` currently couples lifecycle handling, permissions, and foreground initialization.
- `lib/app/lifecycle/app_foreground_bridge.dart` directly constructs `ForegroundServiceController`; it is not currently an interchangeable interface. Its provider returns that concrete bridge.
- `lib/foreground/bootstrap/foreground_plugin_init.dart` enables automatic restart after boot and package replacement. The foreground entry point starts patient monitors in its own provider container.
- `lib/core/notifications/handlers/notification_response_handler.dart` routes replies to the patient foreground task. Family reply delivery must also work without that task.
- The onboarding assumes patient data sources and monitoring. Caregivers need a separate route through initial configuration.
- Meal creation already has a transactional local use case. Remote plan import should reuse patient-side validation and creation rather than create a second execution engine.
- Meal data spans main rows, ingredients, snapshots, status history, and other linked facts. A status-only listener is insufficient for mirroring changes.
- Existing synchronization events are not a durable cloud outbox or a complete immutable history.
- Ingredient and ingredient-portion tables have `is_synced` fields, but these do not establish that data exists in the future family mirror.
- `ingredient_any_change_marks_unsynced` currently resets `is_synced` to zero on any update whose new value is nonzero, including setting it to one. Synchronization bookkeeping must address this behavior.
- Firebase options currently support Android only. Supporting a caregiver on iOS requires explicit Firebase, notifications, and platform startup work.

## Architecture decision: caregiver runtime and foreground bridge

Use one application with separate patient and caregiver navigation, onboarding, and runtime composition. Set the installation mode during initial configuration. Keep installation mode distinct from account membership roles and the identity of the device authorized to publish patient state.

The caregiver does not need the patient's persistent Android foreground service. It needs authenticated data access, cached views, foreground listeners while the application is open, FCM notification handling, and bounded background work where required for durable replies. It must not initialize patient monitors, AAPS integration, exact alarms for patient monitoring, activity-recognition collection, or battery-exemption requests.

Prefer an explicit runtime abstraction, composed by mode, over a production mock of `AppForegroundBridge`:

- Patient runtime owns the actual foreground bridge, patient permissions, event subscriptions, and recovery of patient operations.
- Caregiver runtime owns family authentication/session handling, authorized projections, notification setup, and family synchronization.
- The application shell depends on runtime lifecycle behavior, not a concrete foreground controller.
- Patient-specific screens and commands remain behind patient capabilities and routes.
- If incremental migration requires a bridge interface, a deliberately disabled implementation can be a temporary adapter. It must report monitoring as unavailable and must not pretend that start/restart commands succeeded or swallow required family work.
- Mocks/fakes belong in tests. A production caregiver runtime should express real behavior explicitly.

Guard patient service startup both in the UI startup path and inside the service entry point, including boot/package-replacement paths. Merely overriding a UI provider is insufficient because the task uses a separate container. Initially avoid live switching between installation modes; switching later requires service shutdown, alarm/receiver cleanup, and account/data isolation.

A single binary still declares patient-related permissions in its manifest. A separate caregiver build can be considered later if permission footprint, distribution, or platform needs justify it; shared modules should make that possible without copying business logic.

## Common code and feature boundaries

Start each implementation change by checking reusable code in `common`. Extract shared primitives where both modes actually need them; avoid moving the entire patient engine into `common`.

Proposed responsibilities, with names subject to repository conventions:

- `common/app_mode`: persisted installation mode and capability contracts.
- `common/synchronization`: durable operation identifiers, version/acknowledgement contracts, retry primitives, and queue interfaces.
- Existing `common/meal`, `common/nutrition`, and small common widgets: shared calculations, presentation models, formatting, and reusable form components.
- `app/runtime`: patient and caregiver lifecycle composition.
- `features/family`: activation, invitations, membership, roles, and access removal.
- `features/messaging`: conversation history, questions, replies, receipts, and notification actions.
- `features/caregiver`: caregiver home, upcoming meals/activities, catalog browsing, and planning flows.
- `core/firebase`: concrete authenticated cloud adapters and notification transport.
- `foreground`: patient monitoring and execution only.

Keep widgets small and in separate files. Read-only projections must not expose local patient mutation controllers merely to reuse their UI.

## Identity, roles, and caregiver management

Model a care group around one child initially, supporting the child and two or more caregivers, with one shared conversation. A second parent joins the same group and history rather than creating another pairwise chat. Multi-child navigation is a future extension, not an implicit sharing permission across siblings.

Roles:

| Role | Permissions |
| --- | --- |
| Managing caregiver | Approve membership changes, revoke caregivers, transfer management, and use enabled caregiver functions. |
| Caregiver | Read shared catalog/state, communicate, create plans, and perform specifically granted planning approvals/changes. |
| Child | Use the local patient application and publish its data; view caregivers and initiate an invitation flow, without independently granting access or removing a parent. |

The child's phone continuously exposes the caregiver-management area. Sensitive actions require authenticated approval by a managing caregiver; showing that screen or possessing the child's unlocked phone is not authorization. Do not store a parent's Google session on the child's phone merely to unlock a management screen. Prefer approval on the caregiver's device through the backend.

Bootstrap the first managing caregiver through an explicit one-time setup/pairing ceremony. Once established, new invitations and membership changes require management approval. Do not permit removing the last managing caregiver without transferring management or completing an explicit recovery process. Define account-loss and device-replacement recovery before external rollout.

Google Sign-In establishes identity; backend-validated Firebase UID and active group membership authorize access. Never trust a UID, role, group ID, or publishing-device ID supplied only in request data.

## Pairing protocol

1. An authenticated, authorized installation requests a scoped invitation. Initial setup has a separate bootstrap authorization path.
2. Backend generates a strong random secret and stores its hash, group, issuer, allowed role, expiry, and consumption state. Suggested validity: 5–10 minutes.
3. QR contains an invitation ID and secret. A child UID does not need to be exposed in the QR.
4. The recipient signs in with Google and scans the QR. Backend validates the invitation, expiry using server time, account, and permitted operation, with rate limiting.
5. Display the joining identity and obtain the required setup/management approval.
6. Atomically consume the invitation and create membership. Retries must not duplicate membership; concurrent redemption must not grant unintended access.
7. Additional parents join the existing group and conversation.

Firestore TTL cleans up invitations but does not enforce their validity at redemption. Revocation prevents future authorized reads, writes, and notifications. Clear application-managed account/group caches on logout or unlinking; previously viewed/copied data cannot be recalled remotely.

## Cloud data boundaries

Indicative structure:

- `careGroups/{groupId}`: child profile reference and group settings.
- `careGroups/{groupId}/members/{uid}`: role, active membership, permissions; managed through authorized backend operations.
- `careGroups/{groupId}/ingredients/{ingredientId}`: child-published catalog projections, including versions and deletion markers.
- `careGroups/{groupId}/messages/{messageId}`: conversation messages and structured questions/replies.
- `careGroups/{groupId}/mealRequests/{requestId}`: caregiver plans and their processing results.
- `careGroups/{groupId}/activityRequests/{requestId}`: activity proposals, approvals, and scheduling changes.
- `careGroups/{groupId}/meals/{mealId}` and `activities/{activityId}`: child-published execution projections.
- `users/{uid}/devices/{deviceId}`: private notification/device registration information.
- `pairingInvites/{inviteId}`: backend-only invitation material.

Caregivers cannot write patient projection documents. Rules must validate field-level permissions, authenticated authorship, and relationships. Admin SDK bypasses Firestore Rules, so callable functions must independently validate authorization. Do not use guess-resistant IDs, FCM topics, or App Check as substitutes for membership checks.

Initially register one active patient publishing device, with an explicit source generation when replacing it. Prevent an old device's delayed uploads from overwriting the replacement's data. Define how that registration is verified rather than trusting an arbitrary client-supplied device ID.

## Offline-first synchronization

Commit local patient changes and durable synchronization work in the same local transaction. Network calls never belong inside that transaction. Handle writes from both UI and foreground isolates through the same durable mechanism.

- Give shared entities and requests stable global IDs; local auto-increment IDs remain local implementation details.
- Use monotonic revisions and source generations. Do not resolve patient execution conflicts using wall-clock last-write-wins behavior.
- Upload immediately when possible; persist failed work and retry after reconnect, restart, and authentication recovery.
- Acknowledge only the exact uploaded revision. A new local edit during upload remains pending.
- Preserve deletion markers until they can be synchronized; deleting only the local row would leave stale cloud records.
- Show pending/error states and the last patient update time. Cached data must not imply current connectivity.
- Cloud triggers and pushes may duplicate or arrive out of order. Operation handling and notifications must be idempotent.
- Use FCM for notification/wakeup opportunities, not as the authoritative queue or the only record of a plan/message.
- Keep family caches isolated from writable patient tables and across logout, different accounts, and group changes.

For initial ingredient sharing, reconcile/export the entire local catalog, including rows previously marked synced. The old flag does not prove presence in the family namespace. Subsequent synchronization processes pending revisions. Prefer dedicated synchronization bookkeeping if that avoids coupling transport acknowledgements to business-data triggers.

## Ingredients and portions

Only the child-side application edits the child's ingredients. Caregivers browse a read-only mirror and use it to construct plans. Include nutrition values, labeling mode, names, relevant identity metadata, portions, and grams-per-portion conversions. Do not rely on local ingredient/portion IDs on another phone.

A single-writer catalog still allows stale caregiver reads. Every submitted meal plan includes ingredient identities, expected revisions, and a self-contained snapshot of the nutrition/portion values used for its calculations. Patient-side import compares with its local catalog without contacting Firebase. A mismatch produces an explicit update/review result; do not silently change planned macros or overwrite current ingredients with an old caregiver snapshot.

Historical accepted meals retain their relevant nutrition/portion facts when ingredients change later. Uploading full ingredient edit history is a separate scope decision; current catalog mirroring must not rewrite historical meal facts.

## Meal plans and execution projections

Caregiver creates an immutable, globally identified request with the intended child, author, schema version, schedule, ingredients, amounts, and portion facts. Do not accept arbitrary execution status, bolus evidence, therapy commands, or advisor decisions from the request.

Patient processing: verify authorized provenance and input, check request ID, validate against local data, create the local planned meal through existing use cases, and record the request result/mapping plus outgoing acknowledgement atomically. A duplicate request yields the previous result rather than a second meal.

Caregiver request states distinguish pending local submission, stored on server/awaiting patient, accepted on patient, and rejected/requires review. A server write is not patient acceptance. Define expiration/late arrival behavior so an old school lunch request is not silently imported after its useful time.

Publish a coherent meal projection covering relevant ingredients/amounts, status, timing, progress, and history needed by the caregiver. Capture dependent-table changes as well as main-row changes. Current status history is not a complete immutable log of every edit. Decide separately whether every intermediate edit needs audit retention; initial scope is current projection plus meaningful execution history.

First planning release supports new meals. Editing/canceling an already submitted meal needs a later explicit versioned request protocol and a race policy against patient execution.

## Activity planning and execution

Caregivers can create activities with planned start and duration, approve plans proposed by the child, and request a new planned start for an upcoming activity. Track planning approval separately from actual execution status; existing local child planning must continue working offline without mandatory cloud approval.

Use stable request IDs and expected activity revisions. The patient validates the request locally and accepts it only if still applicable. A started/completed activity rejects delayed scheduling changes with a clear result. Upon acceptance, recalculate relevant local reminders, including temporary-target reminders, through the existing activity mechanisms.

Show the requested new time as pending until the child phone confirms it. A chat response such as “training moved” does not directly mutate the schedule; an explicit planning operation does.

## Messaging, quick replies, and receipts

Provide full shared conversation history in both application modes. Both parents see the same questions and responses, including responses sent from notifications. Paginate older history and support cached browsing. Initial scope is plain text, structured questions, and replies; no calls or attachments are required.

A question contains a stable ID and 2–3 short parent-defined answers. Offer reusable templates and custom questions. Examples: “Do you have breakfast?” with “Yes / No / Later”; “Can you reply?” with “Yes / In class”. Each reply references its question and selected option, and uses a stable operation ID to deduplicate double taps/retries.

Provide discreet notification configuration and a separate Family channel. Avoid repeated reminders solely because the child has not replied. Update/remove answered question actions and handle answers from stale notifications explicitly. Preserve question context in history. Built-in labels/templates use l10n; user-authored content stays as authored.

Family notification replies must use durable delivery independently of the patient foreground service. Notification handlers can perform bounded work and schedule supported background work as necessary; do not assume a persistent listener will run indefinitely on a caregiver phone. Persist a reply before reporting successful submission to the user.

Receipt meanings:

| Receipt | Evidence |
| --- | --- |
| Pending | Persisted locally, awaiting upload. |
| Sent | Stored by the backend. |
| Received on phone | Recipient application acknowledged the message. |
| Received on watch | A supported watch integration explicitly acknowledged receipt; unavailable from ordinary phone receipt alone. |
| Conversation opened | Recipient explicitly opened the conversation containing the message; do not claim human comprehension. |
| Replied | Recipient submitted a reply or selected answer. |

Receipts identify the relevant recipient/device and time; a group receipt must not imply every member read a message. FCM acceptance or delivery metrics are not application-level read receipts.

For Wear OS, begin with bridged phone notifications, MessagingStyle, RemoteInput, and predefined choices/actions. Actual tap count and rendering require testing on the child's watch, whose model is not yet specified. Starting a new conversation directly on a watch without an existing notification and independent watch connectivity are additional scope.

Reliable watch-specific receipt requires evaluating a small watch app that receives messages, posts notifications, and acknowledges them. Posting a notification does not prove that it appeared visibly, vibrated, or was noticed. Do not label ordinary mirrored notifications as confirmed watch delivery.

## Delivery stages and acceptance gates

### Stage 0 — Patient regression baseline

Before runtime refactoring, run existing configuration/runtime/service coverage and add missing tests against current behavior. Keep existing test files unchanged.

Progress on 2026-11-06:

- Added `test/features/settings/application/patient_configuration_startup_regression_test.dart` with four regression cases: default patient monitoring for configured installations, local setup without a cloud connectivity check and with a real startup acknowledgement barrier, rejection of a duplicate initial service start, and failed-start suppression of premature startup synchronization.
- Added a controlled service-boundary test helper in `test/helpers/regression/controlled_app_foreground_bridge.dart`; the production startup acknowledgement provider remains in use.
- Existing focused baseline: 13 tests passed before adding coverage.
- Configuration, foreground runtime, and foreground service suite including the new cases: 77 tests passed.
- This baseline does not yet cover the full application widget startup/resume or boot/package-replacement entry points. Add coverage for those boundaries when extracting runtime composition in Stage 1, before changing their patient behavior.
- Reviewed by GPT-6.1 Terra at high reasoning. Fixed the startup test scheduling barrier and kept its auto-dispose provider subscribed for the operation. A controlled mutation confirmed the test fails if startup readiness waiting is removed; production source was restored. Follow-up review reported no further findings.
- No existing test or application implementation file was changed in this step.

### Stage 1 — Installation mode and runtime separation

Deliver initial-configuration mode choice, persisted mode, separate caregiver onboarding/navigation, and explicit patient/caregiver runtime composition. Preserve existing configured installations as patient mode through migration. Start with no live mode toggle.

Gate: caregiver starts/resumes without patient monitoring, AAPS execution paths, patient permission prompts, or persistent foreground service. Boot/update entry points cannot start patient monitoring in caregiver mode. Existing patient behavior remains operational.

### Stage 1 UI increment — Full-screen setup with simulated new features

Implemented on 2026-11-06:

- Six fixed progress markers: basics, features, data, access, per-feature configuration, summary. Marker 5 changes its caption (Family / AI / NS); the header shows the current configuration count and supports previous-feature navigation. Marker 6 stays visible.
- Reusable feature catalog and requirement aggregation in `common/setup/domain`, filtered by a person/device-mode model. Shared requirements preserve their dependent feature IDs.
- Full-screen initial setup and a separate settings preview entry that uses the same wizard. Mode/feature selections, permission grants, AI checks, Google sign-in, QR pairing, and Firebase sharing are explicitly simulated and kept in session memory.
- Horizontal dependency/permission chip rails with overflow controls; feature information bottom sheets with requirements and links to maintained Wiki pages where available.
- Pairing preview can generate a fresh invitation code while retaining linked accounts below it. Account names and membership come through a repository stream, currently an in-memory demo adapter with distinct membership roles. Invitation failures and membership verification failures are independent; stale callbacks after mode changes/disposal are ignored. Firebase remains a future adapter, not an active integration.
- Pairing direction: the patient/child device displays the invitation QR; the caregiver scans it. The caregiver preview shows a simulated scanner with no visible invitation code, camera access, or permission request. Its pairing button simulates scanning and connection; Add child reopens the scanner while preserving linked accounts. The shared demo adapter still uses an internal invitation ID to simulate stream membership; real QR consumption belongs to the Firebase integration.
- Successful demo pairing replaces the QR with a confirmation for 500 ms, collapses the invitation over 240 ms, then reveals the linked account. The compact card offers Add caregiver (or Add child in caregiver mode); there is no separate regenerate-code button. Reduced motion reveals membership immediately, and presentation timing never delays authoritative membership state. Timers are cancelled on disposal and existing accounts remain visible while adding another. Validation: 113 targeted tests passed; Terra high-reasoning review completed.
- Existing initial patient save delegates to the original use case for name, language, sources, and Nightscout credentials. Profile photo selection remains available in actual patient initialization and saves independently as before. Simulated feature selections are not persisted and do not toggle running monitors.
- Settings preview does not write configuration, request permissions, contact AI, authenticate, pair accounts, or start/stop services. Completing a caregiver demo never invokes the patient save path; initial setup returns to mode choice, while a settings preview returns to settings.
- Session-local language changes apply immediately, including overlays and the device-language option, without changing saved application language in preview. Actual save errors use the language of the submitted draft.
- Terra high-reasoning review findings were addressed. Validation: 102 targeted tests passed, analysis of changed Dart files passed, and debug APK builds succeeded. Widget rendering and narrow/large-text layouts were checked; installation on the available emulator was prevented by insufficient storage. This increment is UI scaffolding, not completion of Stage 1 runtime separation or the family pilot.

### Stage 2 — Google authentication and care-group lifecycle

Deliver optional family activation in patient settings, required Google login for family functions in both modes, initial management bootstrap, QR pairing, additional caregiver invitations, roster, approval/revocation, and access rules. Keep Google login out of the offline local patient prerequisite path.

Gate: test a real supervised Google account with Family Link. Unrelated users cannot access data by substituting IDs. A child cannot remove a caregiver or self-approve membership. Expired/reused/concurrently redeemed invitations fail safely. Account loss and last-manager recovery policy are documented.

### Stage 3 — Durable synchronization and read-only ingredient mirror

Build reusable local queue/version/acknowledgement primitives; address existing synced-flag triggers through a migration or dedicated bookkeeping. Reconcile the full initial ingredient catalog and portions, then incremental edits/deletions. Expose caregiver read-only browsing with freshness and synchronization status.

Gate: airplane-mode ingredient edits work immediately. Restart/reconnect delivers outstanding changes. Editing during upload does not clear the newer pending revision. Deletions propagate. Parent writes are denied. UI/foreground writers and device replacement cannot regress published versions.

### Stage 4 — Shared text conversation and quick-answer questions

Deliver conversation history on both phones, two-parent shared access, templates/custom questions, quick answers, discreet notification channel, phone acknowledgements, and durable background replies independent of monitoring.

Gate: test the actual phone/watch pair with screen off, locked phone, battery saving, and lost connectivity. Double taps and repeated delivery do not duplicate messages. History preserves question context. Ordinary receipts never claim watch delivery. Explain the system force-stop limitation during pilot setup.

This is the first useful limited family pilot: pairing, ingredient visibility, and school communication, without remote patient-state mutation.

### Stage 5 — Read-only day view

Publish current meal/activity projections and meaningful execution history. Reuse small common presentation widgets through read-only models. Display last patient synchronization and pending/offline state.

Gate: changes in ingredients/amounts, execution status, timing, and deletion appear correctly. No caregiver action can trigger patient execution. Patient workflows remain fully operational with cloud unavailable.

### Stage 6 — Caregiver meal and activity planning

Deliver new meal requests using the child's mirrored catalog, activity proposals/approval, and versioned changes to upcoming activity start. Provide pending/accepted/rejected/review-required feedback and local patient import.

Gate: duplicate/late requests, stale ingredient versions, patient restart during import, and concurrent activity start are handled deterministically. Accepted activities rearm reminders correctly. Meal execution never requires Firebase. Existing local child-created plans remain available offline.

### Stage 7 — Optional watch-specific integration

If confirmed watch receipt is still required, prototype and validate a small Wear OS application for the actual model. Define connectivity, acknowledgement semantics, duplicate-notification avoidance, and supported quick-action behavior.

Gate: report phone receipt, watch receipt, notification posting, opening, and replying accurately. Verify disconnected-watch behavior and avoid claiming that a child saw a notification merely because the watch posted it.

## Validation strategy

Add targeted tests at the stage that introduces the behavior. Do not postpone offline/retry tests until the final rollout.

- Runtime: caregiver cold start/resume/boot/package update, patient migration defaults, and isolation of patient commands.
- Authorization: stranger access, role escalation, author spoofing, revoked member, invalid publishing device, and backend/Admin validation.
- Pairing: expiry, replay, concurrent redemption, management approval, and last-manager policy.
- Synchronization: crash before/after local commit and acknowledgement, offline restart, authentication expiry, duplicate/out-of-order uploads, edits during upload, deletions, and complete first export.
- Planning: stale ingredients/portions, duplicate IDs, import atomicity, request expiry, rejection visibility, and activity scheduling races.
- Messaging: offline sends/replies, duplicate notification actions, per-question context, receipt accuracy, pagination, and per-account cache isolation.
- Device checks: supervised Google account, real phone/watch behavior, denied notification permission, system force-stop/reopen, battery-saving conditions, and distribution-specific App Check setup.

Existing regression tests remain intact unless the user explicitly approves a stated change. Run checks appropriate to each stage; documentation-only planning requires no Dart formatting or application test run.

## Deployment and open decisions

- Android is the initial configured Firebase platform. Confirm caregiver iOS requirements before promising cross-platform rollout.
- Confirm the watch model. Generic smartwatch support cannot be inferred from Wear OS documentation.
- Validate Family Link login early; supervised accounts may require parental permission for third-party access.
- Configure App Check for the actual pilot distribution method, including APK distribution outside Google Play if used. Do not broadly distribute debug credentials.
- Use App Check alongside authentication/authorization. It does not replace membership checks.
- Cloud Functions deployment requires Blaze. Measure costs, paginate chat history, scope listeners to needed data, and configure cost alerts. Avoid promising a free backend.
- Firebase transport/server-side encryption does not provide automatic end-to-end chat encryption. Decide whether E2EE is a requirement before finalizing message/key architecture.
- Define retention, account/group deletion, membership history visibility, source-device replacement, and manager recovery before external rollout. Choose cloud locations deliberately; the existing catalog functions run in `europe-west1`, but do not infer all data locations from that.
- Initial scope does not promise live glucose/therapy-data mirroring to the caregiver. Add it only through an explicit data contract and freshness requirements.
- Approval UX, plan-expiration policy, full edit-history retention, notifications for plan rejection, and future multi-child support need concrete product decisions during the relevant stage.

## Official reference material

- [Firestore authorization conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Role-based access](https://firebase.google.com/docs/firestore/solutions/role-based-access)
- [Callable functions](https://firebase.google.com/docs/functions/callable)
- [Transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [TTL behavior](https://firebase.google.com/docs/firestore/ttl)
- [Offline caching and conflict behavior](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Firestore trigger ordering and duplicate delivery](https://firebase.google.com/docs/functions/firestore-events)
- [Flutter FCM reception and platform limitations](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [FCM delivery semantics](https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan)
- [Wear OS notifications and predefined replies](https://developer.android.com/training/wearables/notifications)
- [Android RemoteInput choices](https://developer.android.com/reference/android/app/RemoteInput.Builder)
- [Family Link third-party application access](https://support.google.com/families/answer/9204736?hl=en)
- [App Check and Play Integrity distribution settings](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [FCM encryption](https://firebase.google.com/docs/cloud-messaging/encryption)
- [Cloud Functions setup and billing prerequisites](https://firebase.google.com/docs/functions/get-started)
- [Firestore pricing](https://firebase.google.com/docs/firestore/pricing)
