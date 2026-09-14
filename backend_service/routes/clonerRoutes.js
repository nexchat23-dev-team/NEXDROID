import express from 'express';
import * as clonerController from '../controllers/clonerController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// GET /apps - List cloneable apps on device
router.get('/apps', clonerController.listCloneableApps);

// POST /clone - Clone an app
router.post('/clone', validateBody, clonerController.cloneApp);

// GET /clones - List user's cloned apps
router.get('/clones', clonerController.listClonedApps);

// DELETE /clones/:cloneId - Remove clone
router.delete('/clones/:cloneId', clonerController.removeClone);

// GET /limits - Get cloning limits
router.get('/limits', clonerController.getCloningLimits);

// PUT /clones/:cloneId/config - Update clone config
router.put('/clones/:cloneId/config', validateBody, clonerController.updateCloneConfig);

export default router;
