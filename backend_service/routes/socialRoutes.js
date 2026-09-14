import express from 'express';
import * as socialController from '../controllers/socialController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// GET /posts - Get social feed (paginated)
router.get('/posts', socialController.getFeed);

// POST /posts - Create post
router.post('/posts', validateBody, socialController.createPost);

// GET /posts/:id - Get post
router.get('/posts/:id', socialController.getPost);

// DELETE /posts/:id - Delete post
router.delete('/posts/:id', socialController.deletePost);

// POST /posts/:id/like - Like post
router.post('/posts/:id/like', socialController.likePost);

// DELETE /posts/:id/like - Unlike post
router.delete('/posts/:id/like', socialController.unlikePost);

// POST /posts/:id/comment - Comment on post
router.post('/posts/:id/comment', validateBody, socialController.commentOnPost);

// GET /reels - Get reels feed
router.get('/reels', socialController.getReels);

// POST /reels - Upload reel
router.post('/reels', validateBody, socialController.uploadReel);

// DELETE /reels/:id - Delete reel
router.delete('/reels/:id', socialController.deleteReel);

// POST /friends/request - Send friend request
router.post('/friends/request', validateBody, socialController.sendFriendRequest);

// PUT /friends/request/:id - Accept/reject
router.put('/friends/request/:id', validateBody, socialController.respondToFriendRequest);

// GET /friends - List friends
router.get('/friends', socialController.listFriends);

// DELETE /friends/:id - Remove friend
router.delete('/friends/:id', socialController.removeFriend);

export default router;
