import { db } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success, paginated } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

export const getStatus = catchAsync(async (req, res) => {
  const doc = await db.collection('firewallConfig').doc(req.user.uid).get();
  return success(res, 200, doc.exists ? doc.data() : { enabled: true, mode: 'cyber_shield', rulesCount: 12 });
});

export const toggleStatus = catchAsync(async (req, res) => {
  const { enabled } = req.body;
  await db.collection('firewallConfig').doc(req.user.uid).set({
    enabled,
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });
  return success(res, 200, null, `Firewall ${enabled ? 'enabled' : 'disabled'}`);
});

export const toggleFirewall = toggleStatus;

export const listRules = catchAsync(async (req, res) => {
  const snapshot = await db.collection('firewallRules').where('userId', '==', req.user.uid).get();
  return success(res, 200, snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
});

export const addRule = catchAsync(async (req, res) => {
  const { name, type, action, target, priority } = req.body;
  const data = { userId: req.user.uid, name, type, action, target, priority, createdAt: FieldValue.serverTimestamp() };
  const docRef = await db.collection('firewallRules').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const updateRule = catchAsync(async (req, res) => {
  const ruleId = req.params.ruleId || req.params.id;
  const docRef = db.collection('firewallRules').doc(ruleId);
  await docRef.update({ ...req.body, updatedAt: FieldValue.serverTimestamp() });
  return success(res, 200, null, 'Rule updated');
});

export const deleteRule = catchAsync(async (req, res) => {
  const ruleId = req.params.ruleId || req.params.id;
  await db.collection('firewallRules').doc(ruleId).delete();
  return success(res, 200, null, 'Rule deleted');
});

export const getLogs = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  
  const snapshot = await db.collection('firewallLogs')
    .where('userId', '==', req.user.uid)
    .orderBy('timestamp', 'desc')
    .offset((page - 1) * limit)
    .limit(limit)
    .get();

  return paginated(res, 200, snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })), page, limit);
});

export const listBlocked = catchAsync(async (req, res) => {
  const snapshot = await db.collection('firewallBlocked').where('userId', '==', req.user.uid).get();
  return success(res, 200, snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
});

export const getBlocked = listBlocked;

export const blockTarget = catchAsync(async (req, res) => {
  const { target } = req.body;
  await db.collection('firewallBlocked').add({ userId: req.user.uid, target, createdAt: FieldValue.serverTimestamp() });
  return success(res, 201, null, 'Target blocked');
});

export const blockIpOrDomain = blockTarget;

export const unblockTarget = catchAsync(async (req, res) => {
  const targetId = req.params.id || req.params.targetId;
  await db.collection('firewallBlocked').doc(targetId).delete();
  return success(res, 200, null, 'Target unblocked');
});

export const unblockIpOrDomain = unblockTarget;

export default {
  getStatus, toggleStatus, toggleFirewall, listRules, addRule,
  updateRule, deleteRule, getLogs, listBlocked, getBlocked,
  blockTarget, blockIpOrDomain, unblockTarget, unblockIpOrDomain
};
