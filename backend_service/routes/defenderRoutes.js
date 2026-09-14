import express from 'express';
import * as defenderController from '../controllers/defenderController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// POST /scan - Trigger security scan
router.post('/scan', validateBody, defenderController.triggerScan);

// GET /scan/:scanId - Get scan results
router.get('/scan/:scanId', defenderController.getScanResults);

// GET /scans - List past scans
router.get('/scans', defenderController.listScans);

// GET /threats - Get detected threats
router.get('/threats', defenderController.getThreats);

// POST /threats/:threatId/quarantine - Quarantine a threat
router.post('/threats/:threatId/quarantine', defenderController.quarantineThreat);

// POST /threats/:threatId/whitelist - Whitelist a file
router.post('/threats/:threatId/whitelist', defenderController.whitelistFile);

// GET /definitions - Get current threat definition version
router.get('/definitions', defenderController.getDefinitionsVersion);

// POST /definitions/update - Update threat definitions
router.post('/definitions/update', defenderController.updateDefinitions);

// GET /stats - Get defender statistics
router.get('/stats', defenderController.getStats);

export default router;
