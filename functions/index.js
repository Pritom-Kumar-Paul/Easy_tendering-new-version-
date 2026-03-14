const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

async function isAdmin(uid) {
  const u = await db.collection('users').doc(uid).get();
  return (u.exists && u.data()?.role === 'admin');
}

// Callable: placeBid (deduct 10% hold, create/merge bid)
exports.placeBid = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const uid = context.auth.uid;
  const tenderId = data.tenderId;
  const amount = Number(data.amount);
  const note = (data.note || '').toString().trim();
  const files = Array.isArray(data.files) ? data.files : [];
  const signatureUrl = data.signatureUrl || null;

  if (!tenderId || !(amount > 0)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid tenderId/amount');
  }

  const fee = Math.round(amount * 0.10 * 100) / 100; // 10%, 2 decimals
  const tenderRef = db.collection('tenders').doc(tenderId);
  const bidRef = tenderRef.collection('bids').doc(uid);
  const userRef = db.collection('users').doc(uid);

  await db.runTransaction(async (tx) => {
    const [tenderSnap, userSnap, bidSnap] = await Promise.all([
      tx.get(tenderRef),
      tx.get(userRef),
      tx.get(bidRef),
    ]);

    if (!tenderSnap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'Tender not found');
    }
    const t = tenderSnap.data();
    if ((t.status || 'open') !== 'open') {
      throw new functions.https.HttpsError('failed-precondition', 'Tender is not open');
    }
    const endAt = t.endAt?.toDate ? t.endAt.toDate() : (t.endAt?._seconds ? new Date(t.endAt._seconds*1000) : null);
    if (endAt && endAt <= new Date()) {
      throw new functions.https.HttpsError('failed-precondition', 'Bidding time over');
    }

    const user = userSnap.data() || {};
    const bal = Number(user.walletBalance || 0);
    if (bal < fee) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient wallet balance');
    }

    // Deduct fee from wallet; track held total
    const newBal = Math.round((bal - fee) * 100) / 100;
    const heldTotal = Number(user.heldTotal || 0) + fee;

    tx.set(userRef, {
      walletBalance: newBal,
      heldTotal,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Merge existing files if any
    const existing = bidSnap.exists ? (bidSnap.data() || {}) : {};
    const existingFiles = Array.isArray(existing.files) ? existing.files : [];
    const allFiles = [...new Set([...existingFiles, ...files])];

    const now = admin.firestore.FieldValue.serverTimestamp();
    const payload = {
      bidderId: uid,
      amount,
      note,
      files: allFiles,
      signatureUrl,
      status: 'submitted',
      depositHold: Number(existing.depositHold || 0) + fee,
      depositPct: 0.10,
      depositStatus: 'held', // held by platform
      updatedAt: now,
    };
    if (!bidSnap.exists) {
      payload.createdAt = now;
    }
    tx.set(bidRef, payload, { merge: true });
  });

  return { ok: true, held: fee };
});

// Callable: adminAdjustBalance (credit/debit wallet)
exports.adminAdjustBalance = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const caller = context.auth.uid;
  if (!(await isAdmin(caller))) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }

  const targetUid = data.uid;
  const delta = Number(data.delta); // + credit, - debit
  const reason = (data.reason || '').toString().slice(0, 200);
  if (!targetUid || !Number.isFinite(delta) || delta === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid uid/delta');
  }

  const userRef = db.collection('users').doc(targetUid);
  const txRef = userRef.collection('walletTx').doc();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const bal = Number((snap.data() || {}).walletBalance || 0);
    const newBal = Math.round((bal + delta) * 100) / 100;
    if (newBal < 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient to debit');
    }
    tx.set(userRef, {
      walletBalance: newBal,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(txRef, {
      delta,
      reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      by: caller,
    });
  });

  return { ok: true };
});

// Callable: adminCaptureDeposit (increase hold from wallet for a bid)
exports.adminCaptureDeposit = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const caller = context.auth.uid;
  if (!(await isAdmin(caller))) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }

  const tenderId = data.tenderId;
  const targetUid = data.uid;
  const amount = Number(data.amount);
  if (!tenderId || !targetUid || !(amount > 0)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid data');
  }

  const tenderRef = db.collection('tenders').doc(tenderId);
  const bidRef = tenderRef.collection('bids').doc(targetUid);
  const userRef = db.collection('users').doc(targetUid);

  await db.runTransaction(async (tx) => {
    const [userSnap, bidSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(bidRef),
    ]);

    if (!bidSnap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'Bid not found');
    }

    const bal = Number((userSnap.data() || {}).walletBalance || 0);
    if (bal < amount) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient wallet balance');
    }

    tx.set(userRef, {
      walletBalance: Math.round((bal - amount) * 100) / 100,
      heldTotal: Number((userSnap.data() || {}).heldTotal || 0) + amount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(bidRef, {
      depositHold: Number(bidSnap.data().depositHold || 0) + amount,
      depositStatus: 'held',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { ok: true };
});