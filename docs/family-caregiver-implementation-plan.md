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

Bootstrap the first managing caregiver through an explicit one-time setup/pairing ceremony. Once established, new invitations and membership changes require management approval. A caregiver may explicitly unlink their own account, including the last caregiver. In that case invalidate pending invitations and require a fresh QR and first-caregiver approval before a new account can join. Define account-loss and device-replacement recovery before external rollout.

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

- Five fixed progress markers: basics, features, access, configuration, summary. Marker 4 shows the current configuration module only while inside it; on the summary it returns to Configuration. The header shows the current configuration count and supports previous-module navigation. Data sources are the first configuration module rather than a separate top-level stage.
- Reusable feature catalog and requirement aggregation in `common/setup/domain`, filtered by a person/device-mode model. Shared requirements preserve their dependent feature IDs.
- Full-screen initial setup and a separate settings preview entry that uses the same wizard. Mode/feature selections, permission grants, AI checks, Google sign-in, QR pairing, and Firebase sharing are explicitly simulated and kept in session memory.
- Horizontal dependency/permission chip rails with overflow controls; feature information bottom sheets with requirements and links to maintained Wiki pages where available.
- Pairing preview can generate a fresh invitation code while retaining linked accounts below it. Account names and membership come through a repository stream, currently an in-memory demo adapter with distinct membership roles. Invitation failures and membership verification failures are independent; stale callbacks after mode changes/disposal are ignored. Firebase remains a future adapter, not an active integration.
- The feature-selection screen also introduces the app through grouped capabilities: everyday tools, history/analysis, monitors, family and AI. Meal/activity planning, low treatment recording, ingredients/portions, meal history/analysis and day overview are always-enabled descriptive capabilities in both modes, without adding permissions, modules, runtime tasks or new connection side effects. Caregiver descriptions explicitly refer to shared child data, read-only ingredients/execution states and the preview pairing scope. Feature documentation targets live in catalog metadata; maintained wiki pages cover the added tools and are published through the existing develop-branch workflow. Only configurable features retain switches.
- Data and meals is a mandatory patient feature at the top of the catalog. Its source controls are the first configuration module, followed by activity options, low treatment options, family, AI and the final Nightscout connection when needed. The typed `SetupStep` enum defines five top-level stages. Caregiver setup retains only its applicable modules.
- Source configuration and monitor tuning require no separate confirmation/test buttons. Next runs a reusable asynchronous `ValidateSetupModuleUseCase`. Nightscout checks required values and URL format, then invokes an optional connection-validator adapter with trimmed credentials and a write-access requirement. The default preview performs no network request. Successful validation marks Nightscout configured before entering summary; errors, pending duplicate actions and stale responses after edits/session changes/navigation/disposal cannot advance the wizard.
- Nightscout URL and token each show their required-by caption and dependent-feature chips directly below the matching input. Cloud data sources require a URL through the core Data and meals feature; optional monitor uploads also require a token. Summary uses Configured rather than Ready in preview. The default language selection follows the full system language preference list, with English as fallback, while explicit saved choices are retained.
- Family data sharing is selected in Features through one shared family feature (the stable `familyChat` identifier), instead of a separate Data-step switch. Its information sheet explains the planned automatic Firebase mirror of new/changed ingredients, meals and activities, the family chat, child-only ingredient edits, Google/pairing prerequisites and offline local operation. `shareData` is derived from the same mode-scoped selection, so disabling or skipping the family feature cannot leave sharing enabled independently. This remains preview state and starts neither synchronization nor messaging.
- Features and their optional tuning settings declare typed required configuration fields independently from system permissions. `CollectSetupConfigurationFieldsUseCase` deduplicates active dependencies while preserving dependent feature IDs; `ValidateSetupConfigurationUseCase` rejects missing/blank required values. Feature help and tuning screens show required-field chips, and the Nightscout screen identifies which monitors require its URL/token. Completion flags alone cannot bypass missing fields; editing credentials invalidates the check, and final submission redirects to incomplete required configuration.
- Patient setup includes activity tuning and low treatment tuning before the shared Nightscout module. Low treatment monitoring is always included and cannot be disabled or skipped; it requires background execution and notifications, consistent with the existing foreground AAPS carbohydrate-request, handoff and upload tasks. Foreground runtime behavior is unchanged in this increment.
- Temp target uploads are an option of the activity monitor, and carbohydrate uploads are an option of the low treatment monitor. Both preview options default to off and are scoped to device mode. Only enabled options of active parent features require a Nightscout URL/token; read-only setup retains its optional token. Local data sources remain local even when the optional upload demonstration adds a Nightscout step. Skipping that optional connection disables the dependent upload options without removing either monitor. If data sources require Nightscout, the existing source guard still prevents skipping it.
- All tuning remains session-only preview state: no new upload preference is enabled or persisted. With local sources, a dedicated notice explains that entered Nightscout credentials are also not persisted by the unchanged initial-save use case. Token presence is checked locally; the simulated check does not verify server write permissions. Future backend/settings integration must validate real write capabilities before enabling upload options. Existing regression tests were updated with explicit user approval for the added configuration modules.
- Access preview places an I agree action beside each permission heading; after approval it remains disabled with a check mark. Shared horizontal chip rails reserve a separate `+N` control for partially or fully hidden features instead of covering labels; counts refresh when content changes.
- Family management preview uses one Caregivers/Children card with Add caregiver/Add child in the header, the settings/protection notice above Linked accounts, and a shared account list. Create invitation, watch members, simulated pairing, and disconnect operations run through reusable use cases in `common/family/use_cases`.
- A session-scoped `FamilyManagementContext` distinguishes initial setup from later settings. Initial setup allows undoing an accidentally paired account after confirmation. In settings, the child cannot disconnect caregivers; the caregiver can disconnect its child association. The use case and demo data boundary both enforce this rule. Existing repository adapters without disconnection support remain read-only. Stream membership stays authoritative; duplicate actions, operation failures, disposal and mode changes are guarded. Consumed demo invitations cannot reconnect removed members. A real backend must validate bootstrap/management authority independently; this demo context is not authorization for Firebase.
- Pairing direction: the patient/child device displays the invitation QR; the caregiver scans it. The caregiver preview shows a simulated scanner with no visible invitation code, camera access, or permission request. Its pairing button simulates scanning and connection; Add child reopens the scanner while preserving linked accounts. The shared demo adapter still uses an internal invitation ID to simulate stream membership; real QR consumption belongs to the Firebase integration.
- Successful demo pairing replaces the QR with a confirmation for 500 ms, collapses the invitation over 240 ms, then reveals the linked account. The compact card offers Add caregiver (or Add child in caregiver mode); there is no separate regenerate-code button. Reduced motion reveals membership immediately, and presentation timing never delays authoritative membership state. Timers are cancelled on disposal and existing accounts remain visible while adding another. Validation: 113 targeted tests passed; Terra high-reasoning review completed.
- Existing initial patient save delegates to the original use case for name, language, sources, and Nightscout credentials. Profile photo selection remains available in actual patient initialization and saves independently as before. Simulated feature selections are not persisted and do not toggle running monitors.
- Settings preview does not write configuration, request permissions, contact AI, authenticate, pair accounts, or start/stop services. Completing a caregiver demo never invokes the patient save path; initial setup returns to mode choice, while a settings preview returns to settings.
- Session-local language changes apply immediately, including overlays and the device-language option, without changing saved application language in preview. Actual save errors use the language of the submitted draft.
- Terra high-reasoning review findings were addressed. Validation: 102 targeted tests passed, analysis of changed Dart files passed, and debug APK builds succeeded. Widget rendering and narrow/large-text layouts were checked; installation on the available emulator was prevented by insufficient storage. This increment is UI scaffolding, not completion of Stage 1 runtime separation or the family pilot.

### Stage 1 live-services increment

- Initial setup has six main steps: Start, Role, Features, Access, Configuration and Summary. Start contains the local user-name field, an alternative Google sign-in button, and the compact signed-in account panel. Role follows separately and contains only role choices; caregiver is disabled until Google sign-in. Supported device languages resolve automatically across the system preference list with English fallback. A persistent header action shows the resolved language on every setup step, including English fallback. One tap opens a direct list of supported languages without a system-language option. A manual selection remains an explicit preference. Local patient use remains offline-capable; caregiver mode requires Google. A manual name is shown only for local use on Start. Google identity supplies the full display name and HTTPS profile photo, with initials when the image is unavailable. Signing out restores the local profile.
- Google authentication is real on Android and shared with Settings. Android OAuth configuration includes the current development signing fingerprints. Other platforms show an unavailable state until their Firebase/native configuration is supplied. Test actual supervised-account consent on a device before rollout. QR pairing, family memberships, sharing and caregiver completion remain demonstrations; authentication alone does not enable a cloud mirror or messaging.
- The Settings preview entry is removed. AI configuration reuses the real Settings form and saved provider configuration. DiaBeatThis AI explains that access is temporarily free to users and that the author pays usage-based costs. AI-assisted Meal Advisor is temporarily unavailable and cannot be enabled, including through an older saved opt-in.
- Feature selections start enabled, including AI/photo in caregiver mode. Google-dependent family features are disabled and excluded from configuration modules until signed in; local mode cannot expose an invitation module. Existing upload preferences seed monitor tuning; this increment does not silently enable or persist new upload options.
- Startup no longer requests notification, battery exemption or exact-alarm access. The Access step checks existing grants and requests them only after an explicit action. Missing required access blocks progression. Returning from system settings refreshes status. Native notification initialization also disables automatic Apple permission prompts.
- The AI provider is named DiaBeatThis. Setup keeps its saved/default Gemini 2.5 Flash model out of the wizard; the model remains editable in Settings. Next tests the current AI draft, then saves it and advances only after success. Settings retain their separate save/test actions. Choosing ChatGPT subscription starts browser sign-in, shows verified feedback after a valid session, and gates Next until account/model readiness. Android callback pages attempt a fixed, credential-free app-return intent with a manual link if the browser blocks automatic return; they do not claim that receiving a callback verifies the account.
- The actual initial wizard injects the Nightscout status and token-permission checker. Next validates the current URL/token and required treatment-write rights. Final save reuses only a fresh, matching credential fingerprint (five-minute lifetime); changed/expired credentials are checked again. Status checks time out rather than hanging indefinitely.
- Access includes activity-recognition permission required by the declared Android health foreground service. There are no startup permission prompts. Native service start failures propagate; initial setup completes only after service readiness, and running-service retries restart safely. The UI communication port is initialized once to avoid losing readiness messages during resume. Monitoring failures have a distinct final-save error instead of being reported as a Nightscout URL problem.
- Residence context uses an explicit saved override or the device's ISO country code. A language alone is not treated as a country. The Settings card supports changing and restoring the device default; locale changes refresh the derived value. Photo analysis treats this as a weak regional hint, not verified residence or restaurant identity.

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

## Caregiver Nightscout increment (November 2026)

Caregiver setup now saves a persistent device mode and requires a validated, read-only Nightscout connection. Google sign-in remains required. Patient devices without a saved mode retain their existing behavior. Family pairing, messaging, and shared planning remain demonstrations.

The caregiver dashboard fetches glucose entries, pump status, and the current temporary target when opened or resumed, then polls 30 seconds after each completed refresh. The dashboard has no permanent Nightscout heading, refresh status or manual refresh control; a notice appears only on refresh failure. Polling stops when the application leaves the foreground; pending results from an obsolete session or connection are ignored. The last successful values survive temporary failures within the current application session, with freshness and failure indicators. Successful empty responses clear obsolete values.

Caregiver snapshots are isolated from patient caches and scoped to the configured Nightscout connection. Glucose comes from CGM entries rather than pump-status glucose. The caregiver interface exposes no therapy commands or upload switches. Saving caregiver mode disables patient receivers and stops an existing patient service. Application bootstrap, native service start/restart, and automatic service recovery also guard against launching patient monitoring in caregiver mode. No foreground service is needed for this visible-app refresh.

## Secure pairing increment (November 2026)

Production onboarding and the Family settings screen now use authenticated callable operations rather than the preview adapter. Preview-only screens retain the in-memory adapter. Signing in or choosing a role never creates a family; only the patient's explicit Add caregiver action does. The initial scope supports one family per Google account and up to five caregivers.

The deployed schema is `families/{familyId}` with backend-owned `members/{uid}`, `familyAccounts/{uid}` as an immutable active-family lookup, private `pairingInvites/{inviteId}`, and private rate-limit records. All direct Firestore client access is denied, including future message, device-token and notification-job namespaces. There is no messaging or notification-send callable in this increment. Future messaging must authorize the sender and derive recipients from current membership server-side; caller-selected UIDs, tokens or FCM topics must never define routing. Revocation must be rechecked at dispatch time.

Callables require verified Google authentication, revocation checking and App Check. The server generates a 256-bit secret, stores only its SHA-256 hash and enforces a five-minute expiry. Generating a replacement invalidates the previous active invite. Scanning atomically reserves an invitation for one candidate but grants no membership or family-data access. The Google name, email and photo are shown for explicit approval. The child approves the first managing caregiver; existing managing caregivers approve all subsequent candidates. Both parents can manage the family. A managing caregiver may explicitly leave their own family; leaving the last managing account invalidates open invitations. Account recovery and ownership transfer remain future work.

Security review supersedes the earlier proposed initial-setup removal exception: the backend cannot verify a local onboarding context. A child may reject a pending first-caregiver request, but cannot remove an approved caregiver, even during setup. Only managing caregivers may disconnect members. A caregiver can unlink their own account, including when they are the sole caregiver. The child row on the caregiver phone denotes that relationship; it never removes the child account. Client-supplied initialSetup flags are rejected; reinstalling or regenerating an invite changes no permissions.

Family status is polled only while the management UI has listeners and the app is resumed. Normal polling is every three seconds, failures back off to ten seconds, and the per-identity server budget allows multiple devices. No roster is persisted offline. A failed authorization/read hides prior actions and data. Responses after an account switch are discarded. QR secrets are kept in memory only.

Validation includes backend unit tests, actual Firestore emulator transactions for concurrent redemption, denial tests for direct cross-family reads/writes/messages/device tokens/notification jobs, transport identity-switch tests, explicit approval UI tests and existing setup regressions. Backend deployment was completed on 6 November 2026; see the family backend deployment record. Production rejection checks passed. A positive two-device test with the updated application and Google accounts remains required.

## Pairing interface refinement and self-unlink correction

The real QR is compact (168 logical pixels), uses high-contrast dark teal modules on a light themed quiet zone, and is automatically revealed after the layout expansion. Incoming approval cards are revealed similarly. The verified Google name/email remain visible beside one explicit Approve action; the duplicate confirmation dialog is removed.

Disconnect on the child row of a caregiver's phone unlinks the authenticated caregiver. The backend supports both explicit `self` and the previous client payload containing the family's child UID, always resolving the deletion to the caller's membership. A child cannot remove a caregiver, and foreign-family identifiers remain rejected. Leaving as the last caregiver cancels pending invitations and preserves the child and family data; re-pairing requires a fresh invitation.

The caregiver dashboard also omits the separate pump-status age caption while retaining IOB/COB and the glucose-reading age. Visible-app automatic polling and lifecycle handling remain unchanged.

## Data synchronization integration deliveries

The following deliveries implement synchronization incrementally. The child's local database remains authoritative for execution. Every caregiver can submit plans; caregivers use Firebase rather than writing patient domain tables on their phones. There is no implicit restoration of active patient workflows from the cloud.

| Delivery | Scope | Acceptance gate |
| --- | --- | --- |
| S1 | Durable local capture, source ownership, upload receipts and integration status list | Offline edits/deletions survive restart; acknowledging an old revision cannot clear a newer edit; a different Google account cannot upload the old database. |
| S2 | Owner-scoped cloud projections for ingredients, portions/conversions and ingredient origin | Initial full export includes previously saved rows; only family members can fetch; only the child publishes; two caregivers see the same child data. |
| S3 | Meal rows, ingredients, recorded nutrition summaries and state history | A portion/ingredient change and each recorded state reach the caregiver without triggering child execution; stale uploads and deletions are handled. |
| S4 | Activity definitions, recurring schedules, daily occurrences and execution logs | One-off plans, daily confirmation, rescheduling and execution history are represented separately; local scheduling continues offline. |
| S5 | Transactional caregiver-operation inbox and per-record cloud locks | Concurrent caregivers cannot edit the same pending record. Child-offline edits reject stale proposals. A local commit and operation journal are atomic, and retries never repeat the effect. |
| S6 | Caregiver meal planning and read-only execution timeline | Parent creates a meal, child automatically imports a valid plan, then parent sees eating/completed states from the child. Parent cannot submit execution states. |
| S7 | Caregiver activity planning, daily attendance confirmation and upcoming-start changes | Every caregiver can mark a future activity as happening, add a one-off plan or move an eligible future occurrence. Running/completed sessions cannot be altered remotely. |
| S8 | Conflict comparison and explicit retry | Show the caregiver's base, proposed values and current child values; retry creates a new operation against the latest version, retaining the rejected attempt in history. |

### Operation acknowledgement and race contract

- Each caregiver operation has an immutable ID, authenticated author, target, expected source/version, before-snapshot and proposed values. Operations are separate from confirmed child projections.
- Cloud creation atomically checks family membership and reserves the target's pending-operation lock. Other caregivers cannot mutate that target until the child responds. Unrelated records remain editable.
- The child handles remote actions through its existing domain use cases, not unrestricted Firebase patches. The same transaction validates the latest local version, applies an eligible plan and records operation idempotency/result. Merely downloading a request never marks it synced.
- Successful local application produces a durable acknowledgement. Only when Firebase accepts this acknowledgement is the operation marked synced/applied. Loss of acknowledgement delivery keeps it unconfirmed; replay must not apply it twice.
- Conflict rejection includes the child's current canonical state. Firebase records rejection and canonical data before releasing the lock. The child's data is never rolled back. Parent UI drops any proposal overlay and shows the child's state.
- Rejected and applied are distinct terminal outcomes. A rejected operation is not falsely marked applied/synced. Its explicit terminal acknowledgement releases the lock, otherwise a conflict would deadlock the target indefinitely.
- Comparison retains base/proposal/current versions. Retry requires review and confirmation, gets a fresh operation ID and expected current version, and never silently overwrites child or another caregiver changes.
- Aggregate versions must cover meal ingredients/portions and other dependent rows, not just the root meal timestamp. Capture of standalone tables alone is not sufficient to enable remote plan edits.

### Initial implementation boundaries

The capture registry covers sixteen projections: ingredients, ingredient nutrition history, portions, ingredient conversions/origin, meals, meal ingredients, meal history/nutrition summaries, activity definitions/schedules/occurrences/logs, meal templates with ingredients, and minimal monitoring lock states. Raw AI responses, photos, credentials, therapy transport queues and notification tokens are excluded. This is a read-model mirror rather than a full database backup.

Local capture uses dedicated revision/acknowledgement bookkeeping and does not rely on the broken legacy `is_synced` triggers. Schema version 48 installs capture triggers for both UI and foreground database writers. The first export seeds all existing rows regardless of old flags; domain writes and capture roll back together. Networking is opt-in via Family synchronization settings. The foreground sender retries independently of monitoring, and source ownership prevents automatically rebinding an existing patient database to another Google account. Caregiver projections remain cloud-backed and are not imported into patient execution tables.

Plan-writing screens require the operation journal, aggregate conflict version and rejection/lock-release gates. The caregiver planning increment below implements these gates for its explicitly listed operations; raw mirror document writes remain forbidden.

### Import synchronization and patient status

- A successful local restore requests mirror publication only after its SQLite transaction commits. Failed imports roll back their outbox changes and do not request publication. Imported legacy `is_synced` flags never acknowledge a cloud revision.
- The wake-up request is durable; a best-effort foreground signal starts publication immediately when the child worker is available. Otherwise the existing 15-second worker/startup pass resumes it. Disabled family synchronization never authorizes networking.
- Backup size is independent of upload size. Publication uses at most 25 records and a bounded encoded request per batch; retries preserve unacknowledged revisions. A roughly 10 MB import is covered by a local integration test, not a guarantee for arbitrary backup sizes or device memory limits.
- The patient dashboard shows active publication, locally saved pending changes, retryable failure, or blocked records. “Synced” appears briefly only after actual acknowledgements and an empty pending queue. The activity lease is renewed before network requests and expires after a stopped worker.
- Local import atomicity does not provide an atomic cloud dataset switch. Current read-only integration diagnostics can observe intermediate batch counts. Before using imported projections for caregiver planning, add dataset-generation staging/publication or explicitly enforce incomplete-dataset handling; do not treat partial projections as a complete snapshot.


### Selective sharing and historical-analysis audit

Family sharing is a selective domain projection, not a 1:1 phone backup. Add a projection only for a concrete caregiver workflow; the registry and backend allowlist must change together.

| Data | Current mirror | Reason / future gate |
| --- | --- | --- |
| Ingredient nutrition history | Included | Historical meal detail uses the pre-edit nutritional values via IngredientNutritionMapper. Current ingredient values alone cannot reproduce these details. This is not a full edit audit of names/brands/barcodes. |
| Meal status history and planned/consumed nutrition snapshots | Included | Preserve execution timeline and recorded totals; caregivers must not recompute accepted totals from today's ingredient values. |
| Activity schedules, occurrences and execution logs | Included | Represent planned and actual activity separately. The current database has no separate full activity-edit audit trail. |
| Low-treatment meals and their ingredient amounts | Included through meals/mealIngredients | Preserve recorded intake. Rich analysis additionally needs an explicit low-treatment context/review projection; this increment does not claim complete analysis parity. |
| Low-treatment context and review associations | Deferred | Required for reasons, meal/activity associations and avoiding duplicate timeline events before enabling caregiver outcome analysis. Never import delivery/handoff queues as domain facts. |
| Meal completion decisions and wizard associations | Deferred | Assess a typed, read-only projection before detailed analysis; avoid copying local event IDs, command context or transport state wholesale. |
| Accepted day summaries and accepted meal/day AI results | Deferred | Separate saved-analysis sharing from re-running analysis; use a versioned bounded projection rather than arbitrary JSON blobs. No automatic paid AI execution on caregiver refresh. |
| Glucose, treatment events and device status | Not duplicated in Firebase | Future visible-screen analysis can fetch the relevant time window from the child's explicitly configured Nightscout source. Missing/stale history must be shown, never replaced with another child's/source's cache. |
| Photos, raw AI/catalog JSON, credentials, notification tokens and therapy transport queues | Excluded | Outside the family read model. Any later media sharing needs a separate opt-in storage/retention design. |

Before enabling caregiver analysis: complete referenced-domain coverage, source identity and time-window validation, explicit missing-data states, and complete-dataset handling after multi-batch imports. Do not run patient workflows, monitoring or AI automatically on the caregiver phone.

Cost controls: an empty/quarantined-only upload queue performs no mirror callable or token initialization. Only changed record revisions are uploaded; repeated edits coalesce until publication. The metadata listener and visible diagnostics still have read/callable overhead; optimize and measure those before wider rollout. Imports remain proportional to record count, and only child-local ingredients are projected, not the complete central catalog. Identical local catalog copies still occupy per-child documents; evaluate shared references before large rollout. Set project budgets/alerts and measure reads/writes/functions/egress in a pilot; alerts are not a hard spending cap. No projection is a promise of unlimited free retention.


## Caregiver planning increment

The caregiver dashboard opens Family plans. Caregivers can create a future meal, replace the plan of an existing still-planned regular meal, create a one-off future activity using a child's activity definition, confirm a pending future occurrence, or move a pending/planned future occurrence. Meals use the shared catalog picker with a child-projection local-search adapter plus the existing Firebase catalog. Amounts in this increment are entered in grams; arbitrary ingredient editing and caregiver execution-state writes are not exposed.

The backend derives the child from active family membership. `submitFamilyPlan` accepts only an explicit typed proposal and aggregate baseline revisions. It reserves a per-meal/per-occurrence lock atomically, preserves base/proposal, and leaves the operation pending. Submission budget is 30/minute per authenticated account, with at most 50 pending operations per child. A duplicate operation ID with the same author and exact payload returns the original result. Caregiver phones persist only a confirmed send intent in separate SQLite bookkeeping so an ambiguous timeout/restart retries the exact operation ID/payload; they never write the child's domain tables.

The child listens to its own metadata-only familyPlanSignals document. Visible caregiver screens listen to their own mirror/plan metadata, with a 60-second recovery refresh. There is no new patient foreground service and no caregiver foreground service. The listener is installed after successful source registration, reconnects after terminal permission errors, and retries failures with a one-minute backoff. On the existing child service, all pending plans (bounded to 50 per child) are fetched through authenticated callables and processed locally, so a failed early request cannot starve a later valid one. An empty child database is registered once after explicit sync opt-in, allowing an initial catalog-based meal.

A fresh `claimFamilyPlan` checks the author's current family membership immediately before local application. Authorization is linearized at that claim: an already authorized in-flight operation may finish within its 30-second lease after a later unlink. The child checks lease expiry both before domain writes and before commit; it does not execute an old downloaded request offline. The operation's claim token is immutable so overlapping runners/expired-lease recovery cannot invalidate a journal awaiting ACK. Server-issued claim data is not exposed to caregivers.

Aggregate validation includes the meal root, existing meal components, status history, nutrition snapshots and referenced local ingredient/portion revisions. Activity edits include occurrence, definition, schedule and linked execution log. Missing/additional child components and unpublished local revisions cause rejection. A new catalog selection carries only its ID/revision; the child fetches canonical catalog facts and reuses the existing identity-aware mirror. A changed revision or newly existing child copy rejects the proposal rather than silently replacing nutrition. Meal category, macro ranges, energy presence and actionable-carbohydrate validation reuse existing domain rules.

Domain application and family_plan_journal commit together. Replay finds the journal instead of applying again. The child publishes required canonical revisions, durably cancels an obsolete activity confirmation after commit, then calls acknowledgeFamilyPlan. Firebase marks applied/rejected, stores the canonical outcome and releases the lock atomically. Lost ACK is retried. Rejection never restores an old version onto the child. Previously committed journal entries are drained before new catalog work, and a failing new proposal does not block processing of its siblings.

Caregiver views show actual meal/activity execution states and proposal history separately. Rejected proposals retain before/proposal/canonical-at-decision snapshots. Review and retry opens a form against the currently loaded child data and creates a new operation after explicit confirmation. Catalog picking, remote operations and confirmation statuses require connectivity; child monitoring and normal local writes remain available offline.

This supersedes the earlier S5–S8 prohibition for these specific plan operations. It does not enable caregiver therapy commands, repeating-schedule editing, new activity-definition editing, automatic analysis generation, saved-analysis sharing, or cloud restore. Production deployment was completed after explicit approval on 6 November 2026; a positive two-device acceptance test remains the next gate.

### Later: ask a caregiver about a meal

A child may explicitly request a human decision instead of Meal Advisor. Share a timestamped snapshot of the selected meal/macros and current glucose/trend/IOB/COB, showing missing/stale context. Notify current caregivers using server-derived recipients. The first eligible caregiver response closes the request for others: “You can eat” or “Wait”. The child sees “Caregiver decision” with the authenticated responder's Google name/photo and response time, and may accept or reject it. A response never automatically changes meal execution or issues therapy commands. Meal changes invalidate the request; snapshot freshness and response expiry must be explicit. This is a later messaging/notification increment, not implemented here.


### Monitoring ownership and result-record reservation

A caregiver may not edit a meal/activity once its actual preparation/monitoring or execution is active. The existing child monitor contexts synchronously update a common live guard and persist a minimal workflow-lock projection (kind, entity ID, phase and active flag). Temporary initializing/unavailable states do not clear a known lock. The selected planned/waiting phase is already active monitoring and is locked, even before preparation. Initializing/unavailable states preserve an established lock until the child ends/cancels that workflow. Activity occurrences with a recorded target-preparation request are also protected. Backend submission checks published locks; the child checks live/persisted locks before and after domain application. Cancellation remains exclusively on the child's existing UI; there is no caregiver cancel or therapy endpoint.

New meals and moved/new activity occurrences receive a new local ID. Before any mirror worker can publish these IDs, the journal's prepared acknowledgement reserves a cloud lock for the result record as well as the original target. A mirror worker waits while an applied result is unbound. Only after result reservation does the child publish canonical records and send its final acknowledgement. Final ACK atomically releases both locks. This prevents a second caregiver changing a newly published result during the final-ACK window. Partial comparison payloads are explicitly marked; full current components and recorded nutrition summaries remain in the main read-only view.


Validation note for this increment: the broad meal suite reports 29 failures also present with the exact same test descriptions on clean commit 7be0c620. The complete foreground suite reports 6 failures also present on that clean baseline. These existing tests were not edited. The new plan/capture/security tests are run separately; see the delivery summary for the final counts. No production deployment or device installation is implied by a successful local build.


Deployment outcome: all thirteen family endpoints and both catalog endpoints were confirmed ACTIVE after the approved release. The seven new callable endpoints reject anonymous access (401); a forged credential check is also rejected (401), and direct mirror/plan/metadata document reads reject anonymous access (403). No test plan/family records were created in production, and no device installation was performed.


### Shared caregiver dashboard navigation

The caregiver shell reuses the patient's Home/Day/History/Catalog bottom bar, header, category selector and centered action-menu styling. A single embedded family-planning controller survives tab switches, avoiding duplicate listeners and refresh loops. Home shows Nightscout and current child records; Day filters family records by date; History separates meals and activities; Catalog exposes child ingredient details/Firebase catalog browsing and activity definitions read-only. The center action menu contains only caregiver meal/activity proposals. Saved/AI day analysis sharing remains deferred, and no patient execution controls or foreground service are enabled on the caregiver.
