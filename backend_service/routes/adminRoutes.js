import express from 'express';
import adminController from '../controllers/adminController.js';
import { authenticate, requireAdmin } from '../middleware/auth.js';

const router = express.Router();

// Public admin login (returns JWT)
router.post('/login', adminController.adminLogin);

// Protected admin routes
router.get('/dashboard', authenticate, requireAdmin, adminController.getDashboard);
router.get('/users', authenticate, requireAdmin, adminController.listAllUsers);
router.patch('/users/:uid/role', authenticate, requireAdmin, adminController.updateUserRole);
router.patch('/users/:uid/ban', authenticate, requireAdmin, adminController.banUser);
router.patch('/users/:uid/unban', authenticate, requireAdmin, adminController.unbanUser);
router.get('/reports', authenticate, requireAdmin, adminController.listReports);
router.patch('/reports/:id', authenticate, requireAdmin, adminController.handleReport);
router.get('/health', authenticate, requireAdmin, adminController.getSystemHealth);
router.post('/announcements', authenticate, requireAdmin, adminController.createAnnouncement);
router.get('/announcements', authenticate, requireAdmin, adminController.getAnnouncements);
router.get('/logs', authenticate, requireAdmin, adminController.getSystemLogs);
router.get('/feature-flags', authenticate, requireAdmin, adminController.getFeatureFlags);
router.put('/feature-flags', authenticate, requireAdmin, adminController.updateFeatureFlags);
router.get('/config', authenticate, requireAdmin, adminController.getAppConfig);
router.put('/config', authenticate, requireAdmin, adminController.updateAppConfig);
router.get('/stats', authenticate, requireAdmin, adminController.getDetailedStats);

// New Token Management & User Moderation Routes
router.post('/tokens/mine', authenticate, requireAdmin, adminController.mineToken);
router.post('/tokens/send', authenticate, requireAdmin, adminController.sendToken);
router.patch('/users/:uid/suspend', authenticate, requireAdmin, adminController.suspendUser);
router.patch('/users/:uid/block', authenticate, requireAdmin, adminController.blockUser);
router.delete('/reels/:id', authenticate, requireAdmin, adminController.deleteReelAdmin);
router.delete('/status/:id', authenticate, requireAdmin, adminController.deleteStatusAdmin);

export default router;
