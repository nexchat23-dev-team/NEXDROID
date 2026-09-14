import { db } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

const MAX_CLONES = 10;

export const listApps = catchAsync(async (req, res) => {
  const doc = await db.collection('userDevices').doc(req.user.uid).get();
  const apps = doc.exists ? doc.data().installedApps : [];
  return success(res, 200, apps);
});

export const listCloneableApps = listApps;

export const cloneApp = catchAsync(async (req, res) => {
  const { packageName, config } = req.body;
  
  const existingSnapshot = await db.collection('clones')
    .where('userId', '==', req.user.uid)
    .where('packageName', '==', packageName)
    .get();

  if (existingSnapshot.size >= MAX_CLONES) {
    throw new AppError(`Maximum of ${MAX_CLONES} clones per app reached`, 400);
  }

  const data = {
    userId: req.user.uid,
    packageName,
    cloneIndex: existingSnapshot.size + 1,
    config: config || {},
    createdAt: FieldValue.serverTimestamp()
  };

  const docRef = await db.collection('clones').add(data);
  logger.info(`User ${req.user.uid} cloned app ${packageName}`);
  return success(res, 201, { id: docRef.id, ...data });
});

export const listClones = catchAsync(async (req, res) => {
  const snapshot = await db.collection('clones').where('userId', '==', req.user.uid).get();
  const clones = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return success(res, 200, clones);
});

export const listClonedApps = listClones;

export const removeClone = catchAsync(async (req, res) => {
  const cloneId = req.params.cloneId || req.params.id;
  const docRef = db.collection('clones').doc(cloneId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data().userId !== req.user.uid) throw new AppError('Forbidden', 403);

  await docRef.delete();
  return success(res, 200, null, 'Clone removed');
});

export const getLimits = catchAsync(async (req, res) => {
  const packageName = req.query.packageName;
  if (!packageName) throw new AppError('packageName required', 400);

  const snapshot = await db.collection('clones')
    .where('userId', '==', req.user.uid)
    .where('packageName', '==', packageName)
    .get();

  return success(res, 200, {
    maxClonesPerApp: MAX_CLONES,
    currentClones: snapshot.size,
    remaining: MAX_CLONES - snapshot.size
  });
});

export const getCloningLimits = getLimits;

export const updateCloneConfig = catchAsync(async (req, res) => {
  const cloneId = req.params.cloneId || req.params.id;
  const docRef = db.collection('clones').doc(cloneId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data().userId !== req.user.uid) throw new AppError('Forbidden', 403);

  await docRef.update({ config: req.body.config, updatedAt: FieldValue.serverTimestamp() });
  return success(res, 200, null, 'Config updated');
});

export default {
  listApps, listCloneableApps, cloneApp, listClones, listClonedApps,
  removeClone, getLimits, getCloningLimits, updateCloneConfig
};
