/**
 * Health Check Routes
 * Provides service health status and connectivity checks
 */

const express = require('express');
const router = express.Router();
const { getPool } = require('../database');
const { getProvider } = require('../blockchain');
const logger = require('../utils/logger');

/**
 * GET /api/proxy/health
 * Basic health check
 */
router.get('/', async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'PRE Proxy Network',
      version: '1.0.0',
      uptime: process.uptime()
    };

    res.json(health);
  } catch (error) {
    logger.error('Health check error:', error);
    res.status(503).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});

/**
 * GET /api/proxy/health/detailed
 * Detailed health check including database and blockchain
 */
router.get('/detailed', async (req, res) => {
  const checks = {
    service: 'healthy',
    database: 'unknown',
    blockchain: 'unknown'
  };

  // Check database
  try {
    const pool = getPool();
    const result = await pool.query('SELECT NOW()');
    checks.database = 'healthy';
  } catch (error) {
    logger.error('Database health check failed:', error);
    checks.database = 'unhealthy';
  }

  // Check blockchain
  try {
    const provider = getProvider();
    const blockNumber = await provider.getBlockNumber();
    checks.blockchain = 'healthy';
    checks.blockNumber = blockNumber;
  } catch (error) {
    logger.error('Blockchain health check failed:', error);
    checks.blockchain = 'unhealthy';
  }

  // Overall status
  const isHealthy = checks.database === 'healthy' && checks.blockchain === 'healthy';
  const statusCode = isHealthy ? 200 : 503;

  res.status(statusCode).json({
    status: isHealthy ? 'healthy' : 'degraded',
    timestamp: new Date().toISOString(),
    checks,
    uptime: process.uptime()
  });
});

module.exports = router;
