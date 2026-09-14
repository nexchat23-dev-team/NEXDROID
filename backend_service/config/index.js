import dotenv from 'dotenv';
dotenv.config();

const config = {
  server: {
    port: process.env.PORT || 3000,
    env: process.env.NODE_ENV || 'development',
    isProduction: process.env.NODE_ENV === 'production',
  },
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    privateKeyPath: process.env.FIREBASE_PRIVATE_KEY_PATH || './serviceAccountKey.json',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'your-jwt-secret-key-change-this',
    expiresIn: process.env.JWT_EXPIRES_IN || '1d',
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
    max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
  },
  cors: {
    allowedOrigins: (process.env.ALLOWED_ORIGINS || '').split(',').map(o => o.trim()).filter(Boolean),
  },
  logging: {
    level: process.env.LOG_LEVEL || 'info',
  }
};

export default Object.freeze(config);
