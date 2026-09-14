import { db, storage } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success, paginated } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

export const listConversations = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const offset = (page - 1) * limit;

  const snapshot = await db.collection('conversations')
    .where('participants', 'array-contains', req.user.uid)
    .orderBy('createdAt', 'desc')
    .offset(offset)
    .limit(limit)
    .get();

  const convos = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return paginated(res, 200, convos, page, limit);
});

export const createConversation = catchAsync(async (req, res) => {
  const { participants, isGroup, name } = req.body;
  if (!participants.includes(req.user.uid)) participants.push(req.user.uid);

  const data = {
    participants,
    isGroup: isGroup || false,
    name: name || '',
    createdBy: req.user.uid,
    createdAt: FieldValue.serverTimestamp(),
    lastMessage: null
  };

  const docRef = await db.collection('conversations').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getConversation = catchAsync(async (req, res) => {
  const convoId = req.params.id || req.params.chatId;
  const doc = await db.collection('conversations').doc(convoId).get();
  if (!doc.exists) throw new AppError('Conversation not found', 404);
  const data = doc.data();
  if (!data.participants.includes(req.user.uid)) throw new AppError('Forbidden', 403);
  return success(res, 200, { id: doc.id, ...data });
});

export const updateConversation = catchAsync(async (req, res) => {
  const { name, avatar } = req.body;
  const convoId = req.params.id || req.params.chatId;
  const docRef = db.collection('conversations').doc(convoId);
  const doc = await docRef.get();
  
  if (!doc.exists) throw new AppError('Conversation not found', 404);
  if (!doc.data().isGroup) throw new AppError('Can only update groups', 400);
  
  await docRef.update({ name, avatar, updatedAt: FieldValue.serverTimestamp() });
  return success(res, 200, null, 'Updated');
});

export const deleteConversation = catchAsync(async (req, res) => {
  const convoId = req.params.id || req.params.chatId;
  const docRef = db.collection('conversations').doc(convoId);
  const doc = await docRef.get();
  if (!doc.exists) throw new AppError('Not found', 404);
  if (doc.data().createdBy !== req.user.uid) throw new AppError('Forbidden', 403);

  await docRef.delete();
  return success(res, 200, null, 'Deleted');
});

export const getMessages = catchAsync(async (req, res) => {
  const convoId = req.params.id || req.params.chatId;
  const { lastMessageId, limit = 20 } = req.query;
  let query = db.collection('conversations').doc(convoId).collection('messages')
    .orderBy('createdAt', 'desc')
    .limit(parseInt(limit));

  if (lastMessageId) {
    const lastDoc = await db.collection('conversations').doc(convoId).collection('messages').doc(lastMessageId).get();
    if (lastDoc.exists) query = query.startAfter(lastDoc);
  }

  const snapshot = await query.get();
  const messages = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return success(res, 200, messages);
});

export const sendMessage = catchAsync(async (req, res) => {
  const convoId = req.params.id || req.params.chatId;
  const { text, type = 'text', fileUrl, fileName, fileSize } = req.body;
  const convoRef = db.collection('conversations').doc(convoId);
  
  const msgData = {
    senderId: req.user.uid,
    text,
    type,
    fileUrl: fileUrl || null,
    fileName: fileName || null,
    fileSize: fileSize || null,
    createdAt: FieldValue.serverTimestamp()
  };

  const msgRef = await convoRef.collection('messages').add(msgData);
  await convoRef.update({ lastMessage: msgData });
  
  return success(res, 201, { id: msgRef.id, ...msgData });
});

export const deleteMessage = catchAsync(async (req, res) => {
  const convoId = req.params.id || req.params.chatId;
  const msgId = req.params.msgId || req.params.messageId;
  const msgRef = db.collection('conversations').doc(convoId).collection('messages').doc(msgId);
  const doc = await msgRef.get();
  if (!doc.exists || doc.data().senderId !== req.user.uid) throw new AppError('Forbidden', 403);

  await msgRef.delete();
  return success(res, 200, null, 'Deleted');
});

export const reactToMessage = catchAsync(async (req, res) => {
  const msgId = req.params.msgId || req.params.messageId;
  const { emoji } = req.body;
  const reactionRef = db.collection('messageReactions').doc(`${msgId}_${req.user.uid}`);
  await reactionRef.set({
    messageId: msgId,
    userId: req.user.uid,
    emoji,
    createdAt: FieldValue.serverTimestamp()
  }, { merge: true });

  return success(res, 200, null, 'Reacted');
});

export default {
  listConversations, createConversation, getConversation, updateConversation,
  deleteConversation, getMessages, sendMessage, deleteMessage, reactToMessage
};
