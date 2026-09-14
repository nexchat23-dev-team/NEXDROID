import express from 'express';
import * as chatController from '../controllers/chatController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// GET /conversations - List user's conversations (paginated)
router.get('/conversations', chatController.listConversations);

// POST /conversations - Create conversation
router.post('/conversations', validateBody, chatController.createConversation);

// GET /conversations/:id - Get conversation details
router.get('/conversations/:id', chatController.getConversation);

// PUT /conversations/:id - Update conversation
router.put('/conversations/:id', validateBody, chatController.updateConversation);

// DELETE /conversations/:id - Delete conversation
router.delete('/conversations/:id', chatController.deleteConversation);

// GET /conversations/:id/messages - Get messages (paginated, cursor-based)
router.get('/conversations/:id/messages', chatController.getMessages);

// POST /conversations/:id/messages - Send message
router.post('/conversations/:id/messages', validateBody, chatController.sendMessage);

// DELETE /conversations/:id/messages/:msgId - Delete message
router.delete('/conversations/:id/messages/:msgId', chatController.deleteMessage);

// POST /conversations/:id/messages/:msgId/react - React to message
router.post('/conversations/:id/messages/:msgId/react', validateBody, chatController.reactToMessage);

export default router;
