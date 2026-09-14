import { db } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success, paginated } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

export const listSessions = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  
  let query = db.collection('gameSessions').orderBy('createdAt', 'desc');
  if (req.query.status) query = query.where('status', '==', req.query.status);
  if (req.query.game) query = query.where('game', '==', req.query.game);

  const snapshot = await query.offset((page - 1) * limit).limit(limit).get();
  const sessions = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return paginated(res, 200, sessions, page, limit);
});

export const createSession = catchAsync(async (req, res) => {
  const { title, game, maxPlayers } = req.body;
  const data = {
    title,
    game,
    creatorId: req.user.uid,
    participants: [req.user.uid],
    maxPlayers: maxPlayers || 4,
    status: 'waiting',
    createdAt: FieldValue.serverTimestamp()
  };

  const docRef = await db.collection('gameSessions').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getSession = catchAsync(async (req, res) => {
  const doc = await db.collection('gameSessions').doc(req.params.id).get();
  if (!doc.exists) throw new AppError('Session not found', 404);
  return success(res, 200, { id: doc.id, ...doc.data() });
});

export const updateSession = catchAsync(async (req, res) => {
  const docRef = db.collection('gameSessions').doc(req.params.id);
  const doc = await docRef.get();
  if (!doc.exists || doc.data().creatorId !== req.user.uid) throw new AppError('Forbidden', 403);

  await docRef.update({ ...req.body, updatedAt: FieldValue.serverTimestamp() });
  return success(res, 200, null, 'Updated');
});

export const joinSession = catchAsync(async (req, res) => {
  const docRef = db.collection('gameSessions').doc(req.params.id);
  await docRef.update({ participants: FieldValue.arrayUnion(req.user.uid) });
  return success(res, 200, null, 'Joined');
});

export const leaveSession = catchAsync(async (req, res) => {
  const docRef = db.collection('gameSessions').doc(req.params.id);
  await docRef.update({ participants: FieldValue.arrayRemove(req.user.uid) });
  return success(res, 200, null, 'Left');
});

export const getLeaderboards = catchAsync(async (req, res) => {
  const snapshot = await db.collection('leaderboards').orderBy('score', 'desc').limit(50).get();
  return success(res, 200, snapshot.docs.map(doc => doc.data()));
});

export const getGameLeaderboard = catchAsync(async (req, res) => {
  const snapshot = await db.collection('leaderboards').where('game', '==', req.params.game).orderBy('score', 'desc').limit(50).get();
  return success(res, 200, snapshot.docs.map(doc => doc.data()));
});

export const submitScore = catchAsync(async (req, res) => {
  const { game, score, kills = 0, won = false, level = 1 } = req.body;
  await db.collection('leaderboards').add({
    userId: req.user.uid,
    game,
    score,
    kills,
    won,
    level,
    createdAt: FieldValue.serverTimestamp()
  });

  return success(res, 201, null, 'Score submitted');
});

export const listClans = catchAsync(async (req, res) => {
  const snapshot = await db.collection('clans').limit(20).get();
  return success(res, 200, snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
});

export const createClan = catchAsync(async (req, res) => {
  const { name, tag } = req.body;
  const data = { name, tag, founderId: req.user.uid, members: [req.user.uid], admins: [req.user.uid], createdAt: FieldValue.serverTimestamp() };
  const docRef = await db.collection('clans').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getClan = catchAsync(async (req, res) => {
  const doc = await db.collection('clans').doc(req.params.id).get();
  if (!doc.exists) throw new AppError('Clan not found', 404);
  return success(res, 200, { id: doc.id, ...doc.data() });
});

export const joinClan = catchAsync(async (req, res) => {
  await db.collection('clans').doc(req.params.id).update({ members: FieldValue.arrayUnion(req.user.uid) });
  return success(res, 200, null, 'Joined clan');
});

export const leaveClan = catchAsync(async (req, res) => {
  await db.collection('clans').doc(req.params.id).update({ members: FieldValue.arrayRemove(req.user.uid) });
  return success(res, 200, null, 'Left clan');
});

export default {
  listSessions, createSession, getSession, updateSession, joinSession,
  leaveSession, getLeaderboards, getGameLeaderboard, submitScore,
  listClans, createClan, getClan, joinClan, leaveClan
};
