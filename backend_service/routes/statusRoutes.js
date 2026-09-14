import express from 'express';
import * as statusController from '../controllers/statusController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// GET / - Get all active statuses from contacts
router.get('/', statusController.getActiveStatuses);

// POST / - Create a status
router.post('/', validateBody, statusController.createStatus);

// GET /:statusId - Get specific status
router.get('/:statusId', statusController.getStatus);

// DELETE /:statusId - Delete status
router.delete('/:statusId', statusController.deleteStatus);

// POST /:statusId/view - Mark status as viewed
router.post('/:statusId/view', statusController.markStatusViewed);

// POST /:statusId/react - React to status
router.post('/:statusId/react', validateBody, statusController.reactToStatus);

export default router;
