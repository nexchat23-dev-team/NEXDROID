import admin from 'firebase-admin';
import fs from 'fs';
import config from './index.js';
import logger from '../utils/logger.js';

let app;

try {
  if (fs.existsSync(config.firebase.privateKeyPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(config.firebase.privateKeyPath, 'utf8'));
    app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: config.firebase.projectId || serviceAccount.project_id
    });
    logger.info('Firebase initialized with service account key.');
  } else {
    app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: config.firebase.projectId
    });
    logger.info('Firebase initialized with application default credentials.');
  }
} catch (error) {
  logger.error('Failed to initialize Firebase Admin SDK', { error: error.message });
}

export const db = admin.firestore();
export const auth = admin.auth();
export const storage = admin.storage();
export const adminInstance = admin;

/**
 * Health check function for Firebase Admin SDK
 * @returns {Promise<{status: string, reason?: string}>}
 */
export const getFirebaseHealth = async () => {
  try {
    if (!app) {
      return { status: 'unhealthy', reason: 'Firebase app not initialized' };
    }
    // Attempting a simple auth listing or just returning healthy
    // to keep it fast and non-intrusive.
    return { status: 'healthy' };
  } catch (error) {
    return { status: 'unhealthy', reason: error.message };
  }
};
