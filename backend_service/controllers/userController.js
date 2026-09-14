import { db, auth } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success, paginated } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

export const listUsers = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const offset = (page - 1) * limit;

  const snapshot = await db.collection('users')
    .orderBy('createdAt', 'desc')
    .offset(offset)
    .limit(limit)
    .get();

  const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return paginated(res, 200, users, page, limit);
});

export const getMe = catchAsync(async (req, res) => {
  const doc = await db.collection('users').doc(req.user.uid).get();
  if (!doc.exists) throw new AppError('User not found', 404);
  return success(res, 200, { id: doc.id, ...doc.data() });
});

export const getCurrentUser = getMe;

export const getUserById = catchAsync(async (req, res) => {
  const uid = req.params.uid || req.params.id;
  const doc = await db.collection('users').doc(uid).get();
  if (!doc.exists) throw new AppError('User not found', 404);
  return success(res, 200, { id: doc.id, ...doc.data() });
});

export const updateMe = catchAsync(async (req, res) => {
  const allowedFields = [
    'username', 'displayName', 'photoUrl', 'photo_url', 'bio', 'name',
    'level', 'rank', 'totalXP', 'onlineSeconds', 'totalWins', 'totalKills', 'totalDeaths',
    'tokenBalance', 'stealthMode', 'auraColor'
  ];
  const updateData = {};
  for (const field of allowedFields) {
    if (req.body[field] !== undefined) updateData[field] = req.body[field];
  }

  await db.collection('users').doc(req.user.uid).set({
    ...updateData,
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });

  logger.info(`User ${req.user.uid} updated profile & stats`);
  return success(res, 200, updateData, 'Profile updated');
});

export const updateCurrentUser = updateMe;

export const deleteMe = catchAsync(async (req, res) => {
  const { hardDelete } = req.body;
  if (hardDelete) {
    await auth.deleteUser(req.user.uid);
    await db.collection('users').doc(req.user.uid).delete();
  } else {
    await db.collection('users').doc(req.user.uid).update({
      status: 'deactivated',
      updatedAt: FieldValue.serverTimestamp()
    });
  }
  logger.info(`User ${req.user.uid} deleted account`);
  return success(res, 200, null, 'Account deleted');
});

export const deleteCurrentUser = deleteMe;

export const getUserStats = catchAsync(async (req, res) => {
  const uid = req.params.uid || req.user.uid;
  const doc = await db.collection('userStats').doc(uid).get();
  return success(res, 200, doc.exists ? doc.data() : {});
});

export const claimDailyBonus = catchAsync(async (req, res) => {
  const docRef = db.collection('users').doc(req.user.uid);
  const doc = await docRef.get();
  if (!doc.exists) throw new AppError('User not found', 404);

  const userData = doc.data();
  const now = new Date();
  const lastClaim = userData.lastBonusClaim ? userData.lastBonusClaim.toDate() : new Date(0);

  if (now.toDateString() === lastClaim.toDateString()) {
    throw new AppError('Bonus already claimed today', 400);
  }

  const newBalance = (userData.tokenBalance || 0) + 100; // 100 Daily Bonus tokens
  await docRef.update({
    tokenBalance: newBalance,
    lastBonusClaim: FieldValue.serverTimestamp()
  });

  logger.info(`User ${req.user.uid} claimed bonus`);
  return success(res, 200, { tokenBalance: newBalance }, 'Bonus claimed');
});

export default {
  listUsers, getMe, getCurrentUser, getUserById, updateMe, updateCurrentUser,
  deleteMe, deleteCurrentUser, getUserStats, claimDailyBonus
};
