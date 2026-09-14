import express from 'express';
import * as callController from '../controllers/callController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// POST / - Initiate call
router.post('/', validateBody, callController.initiateCall);

// GET /history - Get call history
router.get('/history', callController.getCallHistory);

// PUT /:callId/status - Update call status (answer, reject, end)
router.put('/:callId/status', validateBody, callController.updateCallStatus);

// POST /group - Create group call
router.post('/group', validateBody, callController.createGroupCall);

// PUT /group/:callId/join - Join group call
router.put('/group/:callId/join', callController.joinGroupCall);

// PUT /group/:callId/leave - Leave group call
router.put('/group/:callId/leave', callController.leaveGroupCall);

export default router;
