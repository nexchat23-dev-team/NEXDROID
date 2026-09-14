import { db } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success, paginated } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

export const initiateCall = catchAsync(async (req, res) => {
  const { receiverId } = req.body;
  const data = {
    callerId: req.user.uid,
    receiverId,
    status: 'ringing',
    createdAt: FieldValue.serverTimestamp()
  };

  const docRef = await db.collection('calls').add(data);
  logger.info(`User ${req.user.uid} initiated call to ${receiverId}`);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getCallHistory = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const offset = (page - 1) * limit;

  const snapshot = await db.collection('calls')
    .where('callerId', '==', req.user.uid)
    .orderBy('createdAt', 'desc')
    .offset(offset)
    .limit(limit)
    .get();

  const history = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return paginated(res, 200, history, page, limit);
});

export const updateCallStatus = catchAsync(async (req, res) => {
  const { status } = req.body; // answered, rejected, ended, missed
  const callId = req.params.callId || req.params.id;
  const docRef = db.collection('calls').doc(callId);
  await docRef.update({
    status,
    updatedAt: FieldValue.serverTimestamp()
  });

  return success(res, 200, null, `Call status updated to ${status}`);
});

export const createGroupCall = catchAsync(async (req, res) => {
  const { participants } = req.body;
  if (!participants.includes(req.user.uid)) participants.push(req.user.uid);

  const data = {
    initiatorId: req.user.uid,
    participants,
    status: 'active',
    createdAt: FieldValue.serverTimestamp()
  };

  const docRef = await db.collection('groupCalls').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const joinGroupCall = catchAsync(async (req, res) => {
  const callId = req.params.callId || req.params.id;
  const docRef = db.collection('groupCalls').doc(callId);
  await docRef.update({
    participants: FieldValue.arrayUnion(req.user.uid)
  });
  return success(res, 200, null, 'Joined group call');
});

export const leaveGroupCall = catchAsync(async (req, res) => {
  const callId = req.params.callId || req.params.id;
  const docRef = db.collection('groupCalls').doc(callId);
  await docRef.update({
    participants: FieldValue.arrayRemove(req.user.uid)
  });
  return success(res, 200, null, 'Left group call');
});

export default {
  initiateCall, getCallHistory, updateCallStatus,
  createGroupCall, joinGroupCall, leaveGroupCall
};
