import express from 'express';
import * as userController from '../controllers/userController.js';
import { authenticate, requireAdmin } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

// Apply authenticate middleware to all routes except where noted otherwise
router.use(authenticate);

// GET / - List users (admin, paginated)
router.get('/', requireAdmin, userController.listUsers);

// GET /me - Get current user profile
router.get('/me', userController.getCurrentUser);

// GET /:uid - Get user by ID
router.get('/:uid', userController.getUserById);

// PUT /me - Update current user profile
router.put('/me', validateBody, userController.updateCurrentUser);

// DELETE /me - Delete/deactivate account
router.delete('/me', userController.deleteCurrentUser);

// GET /:uid/stats - Get user stats
router.get('/:uid/stats', userController.getUserStats);

// POST /me/daily-bonus - Claim daily bonus tokens
router.post('/me/daily-bonus', userController.claimDailyBonus);

export default router;
