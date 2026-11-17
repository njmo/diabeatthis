'use strict';
const {FamilyError, id, exact, secret, hash, matches, profile, randomCrockford8, normalizeCrockford, formatCrockford8, codeDigest} = require('./security.cjs');
const INVITE_MS = 5 * 60 * 1000;
const CODE_GRACE_MS = 60 * 60 * 1000;
const MAX_MEMBERS = 6;
const fail = code => { throw new FamilyError(code); };

function createFamilyService({store, auth, now = Date.now}) {
  const accountRef = uid => store.doc(`familyAccounts/${uid}`);
  const familyRef = fid => store.doc(`families/${fid}`);
  const inviteRef = iid => store.doc(`pairingInvites/${iid}`);
  const codeRef = digest => store.doc(`pairingCodeIndex/${digest}`);
  const joinRef = uid => store.doc(`familyJoinRequests/${uid}`);
  const membersRef = fid => familyRef(fid).collection('members');
  const read = async (tx, ref) => (await tx.get(ref)).data();
  async function active(tx, uid) {
    const account = await read(tx, accountRef(uid));
    if (!account?.familyId) fail('permission-denied');
    const family = await read(tx, familyRef(account.familyId));
    const member = await read(tx, membersRef(account.familyId).doc(uid));
    if (!family || !member || member.role !== account.role || !family.memberUids.includes(uid) || (member.role === 'child' && family.childUid !== uid) || (member.role === 'managingCaregiver' && !family.managerUids.includes(uid))) fail('permission-denied');
    return {account, family, member, fid: account.familyId};
  }
  // One transaction per authenticated identity prevents parallel rate-limit bypass.
  async function rate(uid, action, limit) {
    const ref = store.doc(`familyRateLimits/${hash(uid + ':' + action)}`);
    await store.runTransaction(async tx => {
      const old = await read(tx, ref), time = now();
      const same = old && old.windowStart + 60000 > time;
      const count = same ? old.count + 1 : 1;
      if (count > limit) fail('resource-exhausted');
      tx.set(ref, {windowStart: same ? old.windowStart : time, count});
    });
  }
  async function createInvite(uid, data) {
    exact(data, []);
    await rate(uid, 'invite', 5);
    const identity = profile(await auth.getUser(uid));
    const iid = secret(), token = secret(), newFid = secret(), time = now();
    return store.runTransaction(async tx => {
      const account = await read(tx, accountRef(uid));
      let fid = account?.familyId, family;
      if (fid) {
        const state = await active(tx, uid);
        family = state.family;
        if (state.member.role !== 'child' || family.childUid !== uid) fail('permission-denied');
      } else {
        if (account) fail('permission-denied');
        fid = newFid;
        family = {childUid: uid, managerUids: [], memberUids: [uid]};
      }
      if (family.memberUids.length >= MAX_MEMBERS) fail('resource-exhausted');
      const previous = family.activeInviteId ? await read(tx, inviteRef(family.activeInviteId)) : null;
      let shortCode, codeHash;
      for (let attempt = 0; attempt < 3; attempt++) {
        shortCode = randomCrockford8();
        codeHash = codeDigest(normalizeCrockford(shortCode));
        const existing = await read(tx, codeRef(codeHash));
        if (!existing || existing.expiresAt + CODE_GRACE_MS <= time) break;
        if (attempt === 2) fail('resource-exhausted');
      }
      if (!account) {
        tx.set(accountRef(uid), {familyId: fid, role: 'child'});
        tx.set(membersRef(fid).doc(uid), {...identity, role: 'child', invitationId: '', joinedAt: time});
      }
      if (previous && ['open', 'pending'].includes(previous.state)) tx.update(inviteRef(family.activeInviteId), {state: 'cancelled'});
      const revision = (family.invitationRevision || 0) + 1;
      tx.set(familyRef(fid), {...family, activeInviteId: iid, invitationRevision: revision});
      tx.set(inviteRef(iid), {familyId: fid, childUid: uid, tokenHash: hash(token), expiresAt: time + INVITE_MS, state: 'open'});
      tx.set(codeRef(codeHash), {inviteId: iid, expiresAt: time + INVITE_MS});
      return {id: iid, token, expiresAt: time + INVITE_MS, revision, shortCode: formatCrockford8(shortCode)};
    });
  }
  async function requestJoin(uid, data) {
    exact(data, ['inviteId', 'token']); const iid = id(data.inviteId);
    await rate(uid, 'join', 10);
    const identity = profile(await auth.getUser(uid));
    return store.runTransaction(async tx => {
      const invite = await read(tx, inviteRef(iid));
      if (!invite || !matches(data.token, invite.tokenHash) || invite.expiresAt <= now()) fail('permission-denied');
      if (invite.childUid === uid) fail('permission-denied');
      const account = await read(tx, accountRef(uid));
      if (account) fail('failed-precondition');
      const family = await read(tx, familyRef(invite.familyId));
      if (!family || family.activeInviteId !== iid || family.memberUids.length >= MAX_MEMBERS) fail('permission-denied');
      if (invite.state === 'pending' && invite.candidateUid === uid) return {pending: true};
      if (invite.state !== 'open') fail('permission-denied');
      const previous = await read(tx, joinRef(uid));
      const previousInvite = previous?.inviteId && previous.inviteId !== iid ? await read(tx, inviteRef(previous.inviteId)) : null;
      if (previousInvite?.candidateUid === uid && previousInvite.state === 'pending') tx.update(inviteRef(previous.inviteId), {state: 'cancelled'});
      tx.set(joinRef(uid), {inviteId: iid});
      tx.update(inviteRef(iid), {state: 'pending', candidateUid: uid, candidate: identity});
      // No membership, family details or messages are disclosed at this point.
      return {pending: true};
    });
  }
  async function requestJoinByCode(uid, data) {
    exact(data, ['code']);
    const code = normalizeCrockford(data.code);
    await rate(uid, 'join', 10);
    await rate('global', 'join_code_attempt', 300);
    const identity = profile(await auth.getUser(uid));
    const codeHash = codeDigest(code);
    return store.runTransaction(async tx => {
      const account = await read(tx, accountRef(uid));
      if (account) fail('failed-precondition');
      const index = await read(tx, codeRef(codeHash));
      if (!index || index.expiresAt <= now()) fail('permission-denied');
      const iid = index.inviteId;
      const invite = await read(tx, inviteRef(iid));
      if (!invite || invite.expiresAt <= now()) fail('permission-denied');
      if (invite.state === 'pending' && invite.candidateUid === uid) return {pending: true};
      if (invite.state !== 'open' || invite.childUid === uid) fail('permission-denied');
      const family = await read(tx, familyRef(invite.familyId));
      if (!family || family.activeInviteId !== iid || family.memberUids.length >= MAX_MEMBERS) fail('permission-denied');
      const previous = await read(tx, joinRef(uid));
      const previousInvite = previous?.inviteId && previous.inviteId !== iid ? await read(tx, inviteRef(previous.inviteId)) : null;
      if (previousInvite?.candidateUid === uid && previousInvite.state === 'pending') tx.update(inviteRef(previous.inviteId), {state: 'cancelled'});
      tx.set(joinRef(uid), {inviteId: iid});
      tx.update(inviteRef(iid), {state: 'pending', candidateUid: uid, candidate: identity});
      return {pending: true};
    });
  }
  async function decide(uid, data) {
    exact(data, ['inviteId', 'approve']); const iid = id(data.inviteId);
    if (typeof data.approve !== 'boolean') fail('invalid-argument');
    await rate(uid, 'decide', 15);
    return store.runTransaction(async tx => {
      const state = await active(tx, uid), invite = await read(tx, inviteRef(iid));
      const first = state.family.managerUids.length === 0;
      const allowed = first ? state.member.role === 'child' : state.member.role === 'managingCaregiver';
      if (!allowed || !invite || invite.familyId !== state.fid || state.family.activeInviteId !== iid || invite.state !== 'pending' || invite.expiresAt <= now()) fail('permission-denied');
      const candidate = await read(tx, accountRef(invite.candidateUid));
      if (candidate || state.family.memberUids.length >= MAX_MEMBERS) fail('failed-precondition');
      tx.update(inviteRef(iid), {state: data.approve ? 'accepted' : 'rejected', decidedAt: now()});
      if (data.approve) {
        // Both parents can manage the family; the last manager cannot leave a locked family.
        tx.set(accountRef(invite.candidateUid), {familyId: state.fid, role: 'managingCaregiver'});
        tx.set(membersRef(state.fid).doc(invite.candidateUid), {...invite.candidate, role: 'managingCaregiver', invitationId: iid, joinedAt: now()});
        tx.update(familyRef(state.fid), {memberUids: [...state.family.memberUids, invite.candidateUid], managerUids: [...state.family.managerUids, invite.candidateUid]});
      }
      return {accepted: data.approve};
    });
  }
  async function status(uid, data) {
    exact(data, []); await rate(uid, 'status', 120);
    return store.runTransaction(async tx => {
      const account = await read(tx, accountRef(uid));
      if (!account) {
        const ownRequest = await read(tx, joinRef(uid));
        const invite = ownRequest?.inviteId ? await read(tx, inviteRef(ownRequest.inviteId)) : null;
        const joinState = invite?.candidateUid === uid ? (invite.state === 'accepted' ? 'revoked' : invite.expiresAt <= now() && invite.state === 'pending' ? 'expired' : invite.state) : null;
        return {members: [], pending: null, joinState};
      }
      const state = await active(tx, uid);
      const roster = await tx.get(membersRef(state.fid));
      const invite = state.family.activeInviteId ? await read(tx, inviteRef(state.family.activeInviteId)) : null;
      const manager = state.member.role === 'managingCaregiver';
      const canApprove = manager || (state.member.role === 'child' && state.family.managerUids.length === 0);
      return {
        members: roster.docs.filter(doc => doc.id !== uid).map(doc => {
          const member = doc.data();
          const last = member.role === 'managingCaregiver' && state.family.managerUids.length === 1;
          return {id: doc.id, displayName: member.displayName, photoUrl: member.photoUrl, role: member.role, invitationId: member.invitationId,
            canDisconnect: (manager && (member.role === 'child' || !last))};
        }),
        canLeave: manager,
        activeInvitationRevision: state.member.role === 'child' ? state.family.invitationRevision || 0 : 0,
        activeInvitationId: state.member.role === 'child' ? state.family.activeInviteId || null : null,
        invitationState: state.member.role === 'child' && invite ? (invite.expiresAt <= now() && ['open', 'pending'].includes(invite.state) ? 'expired' : invite.state) : null,
        pending: canApprove && invite?.state === 'pending' && invite.expiresAt > now() ? {id: state.family.activeInviteId, displayName: invite.candidate.displayName, email: invite.candidate.email, photoUrl: invite.candidate.photoUrl, expiresAt: invite.expiresAt} : null,
      };
    });
  }
  async function disconnect(uid, data) {
    exact(data, ['memberId']);
    // Firebase Auth UIDs are used as opaque document IDs, not filesystem paths.
    if (typeof data.memberId !== 'string' || !data.memberId || data.memberId.includes('/') || data.memberId.length > 128) fail('invalid-argument');
    await rate(uid, 'disconnect', 10);
    return store.runTransaction(async tx => {
      const state = await active(tx, uid);
      // A child row on the caregiver's phone represents the caller's own relationship.
      // Never delete the child account when an older client sends that row's UID.
      const leavingSelf = data.memberId === 'self' || data.memberId === state.family.childUid || data.memberId === uid;
      const targetId = leavingSelf ? uid : data.memberId;
      const target = leavingSelf ? state.member : await read(tx, membersRef(state.fid).doc(targetId));
      if (!target || target.role === 'child' || state.member.role !== 'managingCaregiver') fail('permission-denied');
      if (!leavingSelf && target.role === 'managingCaregiver' && state.family.managerUids.length === 1) fail('failed-precondition');
      const lastManagerLeaving = leavingSelf && state.family.managerUids.length === 1;
      const invitation = lastManagerLeaving && state.family.activeInviteId ? await read(tx, inviteRef(state.family.activeInviteId)) : null;
      if (invitation && ['open', 'pending'].includes(invitation.state)) tx.update(inviteRef(state.family.activeInviteId), {state: 'cancelled'});
      tx.delete(membersRef(state.fid).doc(targetId)); tx.delete(accountRef(targetId));
      tx.update(familyRef(state.fid), {memberUids: state.family.memberUids.filter(id => id !== targetId), managerUids: state.family.managerUids.filter(id => id !== targetId), ...(lastManagerLeaving ? {activeInviteId: null} : {})});
      return {disconnected: true};
    });
  }
  async function finalize(uid, data) {
    exact(data, []);
    return store.runTransaction(async tx => {
      const account = await read(tx, accountRef(uid));
      if (!account) return {locked: true};
      const state = await active(tx, uid);
      // Onboarding context never grants or removes membership permissions.
      return {locked: true};
    });
  }
  return {createInvite, requestJoin, requestJoinByCode, decide, status, disconnect, finalize};
}
module.exports = {createFamilyService};
