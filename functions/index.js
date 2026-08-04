// Cloud Functions scaffold for invite creation & joining.
// Deploy these functions to your Firebase project (functions package.json below).

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// Helper to create a random invite code
function generateCode(length = 8) {
  return crypto.randomBytes(Math.ceil(length/2)).toString('hex').slice(0, length);
}

// Create an invite: callable by authenticated user (client SDK) and returns the plain code to share.
exports.createInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Only authenticated users may create invites');
  const householdId = data.householdId;
  if (!householdId) throw new functions.https.HttpsError('invalid-argument', 'householdId required');

  const code = generateCode(8);
  const codeHash = crypto.createHash('sha256').update(code).digest('hex');
  const inviteDoc = await db.collection('householdInvites').add({
    householdId,
    codeHash,
    createdBy: context.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 48 * 60 * 60 * 1000)), // 48 hours
    used: false,
  });

  return { code, inviteId: inviteDoc.id };
});

// Join with code: callable by authenticated user. Verifies code, adds user to household members if valid.
exports.joinWithCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Only authenticated users may join');
  const code = data.code;
  if (!code) throw new functions.https.HttpsError('invalid-argument', 'code required');

  const codeHash = crypto.createHash('sha256').update(code).digest('hex');
  const invitesRef = db.collection('householdInvites');
  const snapshot = await invitesRef.where('codeHash', '==', codeHash).limit(1).get();
  if (snapshot.empty) throw new functions.https.HttpsError('not-found', 'Invite not found');

  const inviteDoc = snapshot.docs[0];
  const invite = inviteDoc.data();
  if (invite.used) throw new functions.https.HttpsError('failed-precondition', 'Invite already used');
  if (invite.expiresAt && invite.expiresAt.toDate() < new Date()) {
    throw new functions.https.HttpsError('failed-precondition', 'Invite expired');
  }

  const householdId = invite.householdId;
  const householdRef = db.collection('households').doc(householdId);

  // atomically add member and mark invite used
  await db.runTransaction(async (tx) => {
    const houseSnap = await tx.get(householdRef);
    if (!houseSnap.exists) throw new functions.https.HttpsError('not-found', 'Household not found');
    const members = houseSnap.data().members || [];
    if (members.includes(context.auth.uid)) return; // already a member
    members.push(context.auth.uid);
    tx.update(householdRef, { members });
    tx.update(inviteDoc.ref, { used: true, usedBy: context.auth.uid, usedAt: admin.firestore.FieldValue.serverTimestamp() });
  });

  return { success: true };
});
