import { db } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

export const getActiveStatuses = catchAsync(async (req, res) => {
  const now = Timestamp.now();
  const snapshot = await db.collection('statuses')
    .where('isActive', '==', true)
    .where('expiresAt', '>', now)
    .orderBy('expiresAt', 'asc')
    .get();

  const statuses = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return success(res, 200, statuses);
});

export const createStatus = catchAsync(async (req, res) => {
  const { text, mediaUrl, mediaType } = req.body;
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + 24);

  const data = {
    userId: req.user.uid,
    text: text || '',
    mediaUrl: mediaUrl || '',
    mediaType: mediaType || 'text',
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(expiresAt)
  };

  const docRef = await db.collection('statuses').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getStatus = catchAsync(async (req, res) => {
  const doc = await db.collection('statuses').doc(req.params.id).get();
  if (!doc.exists) throw new AppError('Status not found', 404);
  return success(res, 200, { id: doc.id, ...doc.data() });
});

export const deleteStatus = catchAsync(async (req, res) => {
  const docRef = db.collection('statuses').doc(req.params.id);
  const doc = await docRef.get();
  
  if (!doc.exists) throw new AppError('Status not found', 404);
  if (doc.data().userId !== req.user.uid) throw new AppError('Forbidden', 403);

  await docRef.delete();
  return success(res, 200, null, 'Deleted');
});

export const markStatusViewed = catchAsync(async (req, res) => {
  const data = {
    statusId: req.params.id,
    userId: req.user.uid,
    viewedAt: FieldValue.serverTimestamp()
  };
  await db.collection('statusViews').add(data);
  return success(res, 200, null, 'Status viewed');
});

export const reactToStatus = catchAsync(async (req, res) => {
  const { emoji } = req.body;
  const data = {
    statusId: req.params.id,
    userId: req.user.uid,
    emoji,
    reactedAt: FieldValue.serverTimestamp()
  };
  await db.collection('statusReactions').add(data);
  return success(res, 201, null, 'Reacted to status');
});
