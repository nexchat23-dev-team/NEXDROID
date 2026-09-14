import express from 'express';
import * as gamingController from '../controllers/gamingController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// GET /sessions - List gaming sessions
router.get('/sessions', gamingController.listSessions);

// POST /sessions - Create session
router.post('/sessions', validateBody, gamingController.createSession);

// GET /sessions/:id - Get session details
router.get('/sessions/:id', gamingController.getSession);

// PUT /sessions/:id - Update session
router.put('/sessions/:id', validateBody, gamingController.updateSession);

// POST /sessions/:id/join - Join session
router.post('/sessions/:id/join', gamingController.joinSession);

// POST /sessions/:id/leave - Leave session
router.post('/sessions/:id/leave', gamingController.leaveSession);

// GET /leaderboards - Get leaderboards
router.get('/leaderboards', gamingController.getLeaderboards);

// GET /leaderboards/:game - Get game-specific leaderboard
router.get('/leaderboards/:game', gamingController.getGameLeaderboard);

// POST /scores - Submit score
router.post('/scores', validateBody, gamingController.submitScore);

// GET /clans - List clans (paginated)
router.get('/clans', gamingController.listClans);

// POST /clans - Create clan
router.post('/clans', validateBody, gamingController.createClan);

// GET /clans/:id - Get clan details
router.get('/clans/:id', gamingController.getClan);

// POST /clans/:id/join - Join clan
router.post('/clans/:id/join', gamingController.joinClan);

// POST /clans/:id/leave - Leave clan
router.post('/clans/:id/leave', gamingController.leaveClan);

export default router;
