import express from 'express';
import * as healthController from '../controllers/healthController.js';
import { authenticate, requireAdmin } from '../middleware/auth.js';

const router = express.Router();

// GET / - Basic health check (public)
router.get('/', healthController.getHealth);

// GET /detailed - Detailed health with Firebase status, uptime, memory (admin only)
router.get('/detailed', authenticate, requireAdmin, healthController.getDetailedHealth);

export default router;
