/**
 * PRE Proxy Network Service
 * Handles proxy re-encryption operations for secure content ownership transfer
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
const { initBlockchain } = require('./src/blockchain');
const { initUmbral } = require('./src/umbral');

// Import routes
const capsuleRoutes = require('./src/routes/capsule.routes');
const reencryptRoutes = require('./src/routes/reencrypt.routes');
const healthRoutes = require('./src/routes/health.routes');

const app = express();
const PORT = process.env.PORT || 3001;

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
app.use(express.json({ limit: process.env.MAX_CAPSULE_SIZE || '1mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting (global)
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: { error: 'Too many requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// ===================================
// Routes
// ===================================

app.use('/api/proxy/health', healthRoutes);
app.use('/api/proxy/capsules', capsuleRoutes);
app.use('/api/proxy/reencrypt', reencryptRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'PRE Proxy Network',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      health: '/api/proxy/health',
      capsules: '/api/proxy/capsules',
      reencrypt: '/api/proxy/reencrypt'
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
  try {
    logger.info('🚀 Starting PRE Proxy Network service...');

    // Initialize database
    logger.info('📊 Connecting to database...');
    await initDatabase();
    logger.info('✅ Database connected');

    // Initialize blockchain connection
    logger.info('⛓️  Connecting to blockchain...');
    await initBlockchain();
    logger.info('✅ Blockchain connected');

    // Initialize Umbral PRE library
    logger.info('🔐 Initializing Umbral PRE...');
    const umbralReady = await initUmbral();
    if (umbralReady) {
      logger.info('✅ Umbral PRE initialized');
    } else {
      logger.warn('⚠️  Umbral PRE not available - install @nucypher/umbral-pre package');
    }

    // Start server
    app.listen(PORT, () => {
      logger.info(`🎉 PRE Proxy Network running on port ${PORT}`);
      logger.info(`📍 Environment: ${process.env.NODE_ENV}`);
      logger.info(`🔗 RPC: ${process.env.RPC_URL}`);
    });
  } catch (error) {
    logger.error('❌ Failed to start service:', error);
    process.exit(1);
  }
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
