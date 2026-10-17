/**
 * Health Check Routes
 */

const express = require('express');
const router = express.Router();
const { getPool } = require('../database');
const { testAuthentication, getTotalPinnedSize } = require('../services/pinata');
const logger = require('../utils/logger');

/**
 * GET /api/ipfs/health
 * Basic health check
 */
router.get('/', async (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'IPFS Gateway',
    version: '2.0.0',
    uptime: process.uptime()
  });
});

/**
 * GET /api/ipfs/health/detailed
 * Detailed health check
 */
router.get('/detailed', async (req, res) => {
  const checks = {
    service: 'healthy',
    database: 'unknown',
    pinata: 'unknown'
  };

  // Check database
  try {
    const pool = getPool();
    await pool.query('SELECT NOW()');
    checks.database = 'healthy';
  } catch (error) {
    logger.error('Database health check failed:', error);
    checks.database = 'unhealthy';
  }

  // Check Pinata
  try {
    await testAuthentication();
    const sizeInfo = await getTotalPinnedSize();
    checks.pinata = 'healthy';
    checks.pinnedCount = sizeInfo.count;
    checks.totalSize = sizeInfo.totalSize;
  } catch (error) {
    logger.error('Pinata health check failed:', error);
    checks.pinata = 'unhealthy';
  }

  const isHealthy = checks.database === 'healthy' && checks.pinata === 'healthy';

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'healthy' : 'degraded',
    timestamp: new Date().toISOString(),
    checks,
    uptime: process.uptime()
  });
});

module.exports = router;
