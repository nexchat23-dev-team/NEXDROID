import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

import config from './config/index.js';
import logger from './utils/logger.js';
import { error as errorResponse } from './utils/response.js';

// Route imports
import healthRoutes from './routes/healthRoutes.js';
import userRoutes from './routes/userRoutes.js';
import chatRoutes from './routes/chatRoutes.js';
import callRoutes from './routes/callRoutes.js';
import statusRoutes from './routes/statusRoutes.js';
import gamingRoutes from './routes/gamingRoutes.js';
import clonerRoutes from './routes/clonerRoutes.js';
import defenderRoutes from './routes/defenderRoutes.js';
import firewallRoutes from './routes/firewallRoutes.js';
import marketplaceRoutes from './routes/marketplaceRoutes.js';
import socialRoutes from './routes/socialRoutes.js';
import adminRoutes from './routes/adminRoutes.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();

// Security — disable CSP for admin panel
app.use(helmet({ contentSecurityPolicy: false }));

// CORS
const corsOptions = {
  origin: config.cors.allowedOrigins.length > 0 ? config.cors.allowedOrigins : '*',
  optionsSuccessStatus: 200,
  credentials: true
};
app.use(cors(corsOptions));

// Body parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Morgan logging
app.use(morgan(config.server.isProduction ? 'combined' : 'dev', {
  stream: { write: (msg) => logger.info(msg.trim()) }
}));

// Global Rate Limiter
const globalLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later.' }
});
app.use('/api', globalLimiter);

// ── Serve Admin Dashboard ─────────────────────────────────────
app.use('/admin', express.static(join(__dirname, 'admin')));
app.get('/', (req, res) => res.redirect('/admin'));

// ── API Routes ───────────────────────────────────────────────
app.use('/api/v1/health', healthRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/chat', chatRoutes);
app.use('/api/v1/calls', callRoutes);
app.use('/api/v1/status', statusRoutes);
app.use('/api/v1/gaming', gamingRoutes);
app.use('/api/v1/cloner', clonerRoutes);
app.use('/api/v1/defender', defenderRoutes);
app.use('/api/v1/firewall', firewallRoutes);
app.use('/api/v1/marketplace', marketplaceRoutes);
app.use('/api/v1/social', socialRoutes);
app.use('/api/v1/admin', adminRoutes);

// ── Error Handling ───────────────────────────────────────────
app.use((req, res, next) => {
  errorResponse(res, 'Route Not Found', 404);
});

app.use((err, req, res, next) => {
  logger.error(`Unhandled Error: ${err.message}`, { stack: err.stack });
  const statusCode = err.statusCode || 500;
  const message = config.server.isProduction ? 'Internal Server Error' : err.message;
  errorResponse(res, message, statusCode, config.server.isProduction ? null : err.stack);
});

process.on('uncaughtException', (err) => {
  logger.error(`Uncaught Exception: ${err.message}`, { stack: err.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.error(`Unhandled Rejection: ${reason}`);
});

// ── Start Server ─────────────────────────────────────────────
app.listen(config.server.port, () => {
  logger.info('=================================');
  logger.info(`🚀 NEX-APP Backend on port ${config.server.port}`);
  logger.info(`🌍 Environment: ${config.server.env}`);
  logger.info(`🔧 Admin Panel: http://localhost:${config.server.port}/admin`);
  logger.info('=================================');
});
