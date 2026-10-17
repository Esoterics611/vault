/**
 * DAO Governance Service
 * Handles proposal creation, voting, and treasury management for DigitalVault DAO
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
const { initBlockchain, startEventMonitoring } = require('./src/blockchain/dao');

// Import routes
const proposalRoutes = require('./src/routes/proposals.routes');
const votingRoutes = require('./src/routes/voting.routes');
const treasuryRoutes = require('./src/routes/treasury.routes');
const healthRoutes = require('./src/routes/health.routes');

const app = express();
const PORT = process.env.PORT || 3002;

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

app.use('/api/dao/health', healthRoutes);
app.use('/api/dao/proposals', proposalRoutes);
app.use('/api/dao/voting', votingRoutes);
app.use('/api/dao/treasury', treasuryRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'DigitalVault DAO Governance',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      health: '/api/dao/health',
      proposals: '/api/dao/proposals',
      voting: '/api/dao/voting',
      treasury: '/api/dao/treasury'
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
    logger.info('🚀 Starting DAO Governance service...');

    // Initialize database
    logger.info('📊 Connecting to database...');
    await initDatabase();
    logger.info('✅ Database connected');

    // Initialize blockchain connection
    logger.info('⛓️  Connecting to blockchain...');
    await initBlockchain();
    logger.info('✅ Blockchain connected');

    // Start event monitoring
    logger.info('👂 Starting event monitoring...');
    startEventMonitoring();
    logger.info('✅ Event monitoring started');

    // Start server
    app.listen(PORT, () => {
      logger.info(`🎉 DAO Governance service running on port ${PORT}`);
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
