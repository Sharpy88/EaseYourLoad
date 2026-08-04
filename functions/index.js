const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

function generateCode(length = 8) {
  return crypto.randomBytes(Math.ceil(length/2)).toString('hex').slice(0, length);
}

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
    expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 48 * 60 * 60 * 1000)),
    used: false,
  });

  return { code, inviteId: inviteDoc.id };
});

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

// Set a user's PIN: store salted pbkdf2 hash in users/{uid}
exports.setPin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Only authenticated users may set PIN');
  const pin = data.pin;
  if (!pin || typeof pin !== 'string') throw new functions.https.HttpsError('invalid-argument', 'PIN required');
  if (pin.length < 4) throw new functions.https.HttpsError('invalid-argument', 'PIN must be at least 4 characters');

  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(pin, salt, 100000, 64, 'sha512').toString('hex');
  await db.collection('users').doc(context.auth.uid).set({ pinSalt: salt, pinHash: hash }, { merge: true });
  return { success: true };
});

// Verify PIN
exports.verifyPin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Only authenticated users may verify PIN');
  const pin = data.pin;
  if (!pin || typeof pin !== 'string') throw new functions.https.HttpsError('invalid-argument', 'PIN required');

  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const u = userDoc.data() || {};
  const salt = u.pinSalt;
  const hash = u.pinHash;
  if (!salt || !hash) return { valid: false };
  const computed = crypto.pbkdf2Sync(pin, salt, 100000, 64, 'sha512').toString('hex');
  return { valid: computed === hash };
});
