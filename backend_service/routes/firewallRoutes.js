import express from 'express';
import * as firewallController from '../controllers/firewallController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// GET /status - Get firewall status
router.get('/status', firewallController.getStatus);

// PUT /status - Toggle firewall on/off
router.put('/status', validateBody, firewallController.toggleFirewall);

// GET /rules - List firewall rules
router.get('/rules', firewallController.listRules);

// POST /rules - Add firewall rule
router.post('/rules', validateBody, firewallController.addRule);

// PUT /rules/:ruleId - Update rule
router.put('/rules/:ruleId', validateBody, firewallController.updateRule);

// DELETE /rules/:ruleId - Delete rule
router.delete('/rules/:ruleId', firewallController.deleteRule);

// GET /logs - Get firewall logs (paginated)
router.get('/logs', firewallController.getLogs);

// GET /blocked - List blocked IPs/domains
router.get('/blocked', firewallController.getBlocked);

// POST /blocked - Block IP/domain
router.post('/blocked', validateBody, firewallController.blockIpOrDomain);

// DELETE /blocked/:id - Unblock
router.delete('/blocked/:id', firewallController.unblockIpOrDomain);

export default router;
