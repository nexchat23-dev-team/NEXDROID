import { db } from '../config/firebase.js';
import { catchAsync } from '../middleware/errorHandler.js';
import { success } from '../utils/response.js';
import logger from '../utils/logger.js';

export const getHealth = catchAsync(async (req, res) => {
  return success(res, 200, {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '2.0.0'
  });
});

export const getDetailedHealth = catchAsync(async (req, res) => {
  let connected = false;
  let latency = 0;
  try {
    const start = Date.now();
    await db.collection('system').doc('ping').get();
    latency = Date.now() - start;
    connected = true;
  } catch (error) {
    logger.error('Firebase health check failed', error);
  }

  return success(res, 200, {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '2.0.0',
    firebase: { connected, latency },
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development'
  });
});
