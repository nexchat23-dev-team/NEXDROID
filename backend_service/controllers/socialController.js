import { db } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success, paginated } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

export const getPosts = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  
  const snapshot = await db.collection('socialPosts')
    .orderBy('createdAt', 'desc')
    .offset((page - 1) * limit)
    .limit(limit)
    .get();

  return paginated(res, 200, snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })), page, limit);
});

export const getFeed = getPosts;

export const createPost = catchAsync(async (req, res) => {
  const { text, mediaUrls } = req.body;
  const data = { authorId: req.user.uid, text, mediaUrls, createdAt: FieldValue.serverTimestamp() };
  const docRef = await db.collection('socialPosts').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getPost = catchAsync(async (req, res) => {
  const doc = await db.collection('socialPosts').doc(req.params.id).get();
  if (!doc.exists) throw new AppError('Post not found', 404);
  return success(res, 200, { id: doc.id, ...doc.data() });
});

export const deletePost = catchAsync(async (req, res) => {
  const docRef = db.collection('socialPosts').doc(req.params.id);
  const doc = await docRef.get();
  if (!doc.exists || (doc.data().authorId !== req.user.uid)) throw new AppError('Forbidden', 403);
  await docRef.delete();
  return success(res, 200, null, 'Post deleted');
});

export const likePost = catchAsync(async (req, res) => {
  await db.collection('postLikes').doc(`${req.params.id}_${req.user.uid}`).set({
    postId: req.params.id, userId: req.user.uid, createdAt: FieldValue.serverTimestamp()
  });
  return success(res, 200, null, 'Post liked');
});

export const unlikePost = catchAsync(async (req, res) => {
  await db.collection('postLikes').doc(`${req.params.id}_${req.user.uid}`).delete();
  return success(res, 200, null, 'Post unliked');
});

export const commentOnPost = catchAsync(async (req, res) => {
  const { text } = req.body;
  await db.collection('postComments').add({
    postId: req.params.id, authorId: req.user.uid, text, createdAt: FieldValue.serverTimestamp()
  });
  return success(res, 201, null, 'Comment added');
});

export const getReels = catchAsync(async (req, res) => {
  const snapshot = await db.collection('reels').orderBy('createdAt', 'desc').limit(10).get();
  return success(res, 200, snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
});

export const uploadReel = catchAsync(async (req, res) => {
  const { mediaUrl, caption } = req.body;
  const docRef = await db.collection('reels').add({ authorId: req.user.uid, mediaUrl, caption, createdAt: FieldValue.serverTimestamp() });
  return success(res, 201, { id: docRef.id });
});

export const deleteReel = catchAsync(async (req, res) => {
  const docRef = db.collection('reels').doc(req.params.id);
  const doc = await docRef.get();
  if (!doc.exists || doc.data().authorId !== req.user.uid) throw new AppError('Forbidden', 403);
  await docRef.delete();
  return success(res, 200, null, 'Reel deleted');
});

export const sendFriendRequest = catchAsync(async (req, res) => {
  await db.collection('friendRequests').add({ from: req.user.uid, to: req.body.userId, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  return success(res, 201, null, 'Friend request sent');
});

export const respondToFriendRequest = catchAsync(async (req, res) => {
  const { action } = req.body;
  const docRef = db.collection('friendRequests').doc(req.params.id);
  const doc = await docRef.get();
  if (!doc.exists || doc.data().to !== req.user.uid) throw new AppError('Forbidden', 403);

  if (action === 'accept') {
    await db.collection('friends').add({ user1: doc.data().from, user2: req.user.uid });
  }
  await docRef.delete();
  return success(res, 200, null, `Request ${action}ed`);
});

export const listFriends = catchAsync(async (req, res) => {
  const snapshot = await db.collection('friends').where('user1', '==', req.user.uid).get();
  const snapshot2 = await db.collection('friends').where('user2', '==', req.user.uid).get();
  return success(res, 200, [...snapshot.docs, ...snapshot2.docs].map(doc => doc.data()));
});

export const removeFriend = catchAsync(async (req, res) => {
  await db.collection('friends').doc(req.params.id).delete();
  return success(res, 200, null, 'Friend removed');
});
