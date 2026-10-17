/**
 * IPFS Gateway Service
 * Handles encrypted content storage on IPFS with PRE support
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const logger = require('./src/utils/logger');
const { initDatabase } = require('./src/database');
const { initPinata } = require('./src/services/pinata');

// Import routes
const uploadRoutes = require('./src/routes/upload.routes');
const contentRoutes = require('./src/routes/content.routes');
const pinRoutes = require('./src/routes/pin.routes');
const healthRoutes = require('./src/routes/health.routes');

const app = express();
const PORT = process.env.PORT || 3000;

// ===================================
// Middleware
// ===================================

// Security
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(compression());

// Logging
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting (global)
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: { error: 'Too many requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// ===================================
// Routes
// ===================================

app.use('/api/ipfs/health', healthRoutes);
app.use('/api/ipfs/upload', uploadRoutes);
app.use('/api/ipfs/content', contentRoutes);
app.use('/api/ipfs/pin', pinRoutes);

// Legacy health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'ipfs-gateway' });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'DigitalVault IPFS Gateway',
    version: '2.0.0',
    status: 'running',
    endpoints: {
      health: '/api/ipfs/health',
      upload: '/api/ipfs/upload',
      content: '/api/ipfs/content',
      pin: '/api/ipfs/pin'
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    code: err.code || 'INTERNAL_ERROR'
  });
});

// ===================================
// Startup
// ===================================

async function start() {
  logger.info('🚀 Starting IPFS Gateway service...');

  // Initialize database (non-fatal — DB uploads will fail gracefully)
  try {
    logger.info('📊 Connecting to database...');
    await initDatabase();
    logger.info('✅ Database connected');
  } catch (error) {
    logger.warn('⚠️  Database unavailable — upload tracking disabled. Fix DB config to enable.', error.message);
  }

  // Initialize Pinata client (non-fatal)
  try {
    logger.info('📌 Initializing Pinata client...');
    await initPinata();
    logger.info('✅ Pinata initialized');
  } catch (error) {
    logger.warn('⚠️  Pinata init failed — IPFS pinning disabled.', error.message);
  }

  // Start server regardless
  app.listen(PORT, () => {
    logger.info(`🎉 IPFS Gateway service running on port ${PORT}`);
    logger.info(`📍 Environment: ${process.env.NODE_ENV}`);
    logger.info(`📌 Pinata Gateway: ${process.env.PINATA_GATEWAY}`);
  });
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully...');
  process.exit(0);
});

// Start the service
start();

module.exports = app; // For testing
