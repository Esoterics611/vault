/**
 * Pin Management Routes
 * Handles pin status, listing, and unpinning
 */

const express = require('express');
const router = express.Router();
const { param, query, validationResult } = require('express-validator');
const { getPinList, unpinContent } = require('../services/pinata');
const { getPool } = require('../database');
const logger = require('../utils/logger');

/**
 * GET /api/ipfs/pin/status/:cid
 * Check pin status of content
 */
router.get('/status/:cid', async (req, res) => {
  try {
    const { cid } = req.params;

    const result = await getPinList({ cid, pageLimit: 1 });
    const isPinned = result.count > 0;

    res.json({
      success: true,
      cid,
      isPinned,
      pinCount: result.count,
      pins: result.pins
    });
  } catch (error) {
    logger.error('Pin status error:', error);
    res.status(500).json({
      error: 'Failed to check pin status',
      code: 'PIN_STATUS_ERROR'
    });
  }
});

/**
 * GET /api/ipfs/pin/list
 * List all pins
 */
router.get('/list', [
  query('status').optional().isIn(['pinned', 'unpinned', 'all']),
  query('pageLimit').optional().isInt({ min: 1, max: 1000 }),
  query('pageOffset').optional().isInt({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const filters = {
      status: req.query.status || 'pinned',
      pageLimit: parseInt(req.query.pageLimit) || 100,
      pageOffset: parseInt(req.query.pageOffset) || 0
    };

    const result = await getPinList(filters);

    res.json({
      success: true,
      count: result.count,
      pins: result.pins,
      filters
    });
  } catch (error) {
    logger.error('Pin list error:', error);
    res.status(500).json({
      error: 'Failed to list pins',
      code: 'PIN_LIST_ERROR'
    });
  }
});

/**
 * DELETE /api/ipfs/pin/:cid
 * Unpin content
 */
router.delete('/:cid', async (req, res) => {
  try {
    const { cid } = req.params;

    // TODO: Add ownership verification

    await unpinContent(cid);

    // Update database
    const pool = getPool();
    await pool.query(
      `UPDATE uploads SET pin_status = 'unpinned', updated_at = NOW()
       WHERE cid = $1`,
      [cid]
    );

    await pool.query(
      `UPDATE pins SET status = 'unpinned', unpinned_at = NOW()
       WHERE cid = $1`,
      [cid]
    );

    logger.info('Content unpinned', { cid });

    res.json({
      success: true,
      message: 'Content unpinned successfully',
      cid
    });
  } catch (error) {
    logger.error('Unpin error:', error);
    res.status(500).json({
      error: 'Failed to unpin content',
      code: 'UNPIN_ERROR',
      details: error.message
    });
  }
});

/**
 * GET /api/ipfs/pin/stats
 * Get pinning statistics
 */
router.get('/stats', async (req, res) => {
  try {
    const pool = getPool();

    // Get upload stats
    const uploadStats = await pool.query(
      `SELECT
         COUNT(*) as total_uploads,
         SUM(file_size) as total_size,
         COUNT(CASE WHEN is_pre_content THEN 1 END) as pre_content_count,
         COUNT(CASE WHEN pin_status = 'pinned' THEN 1 END) as pinned_count
       FROM uploads`
    );

    // Get recent uploads
    const recentUploads = await pool.query(
      `SELECT COUNT(*) as count
       FROM uploads
       WHERE created_at > NOW() - INTERVAL '24 hours'`
    );

    res.json({
      success: true,
      stats: {
        totalUploads: parseInt(uploadStats.rows[0].total_uploads),
        totalSize: parseInt(uploadStats.rows[0].total_size || 0),
        preContentCount: parseInt(uploadStats.rows[0].pre_content_count),
        pinnedCount: parseInt(uploadStats.rows[0].pinned_count),
        uploadsLast24h: parseInt(recentUploads.rows[0].count)
      }
    });
  } catch (error) {
    logger.error('Pin stats error:', error);
    res.status(500).json({
      error: 'Failed to get stats',
      code: 'STATS_ERROR'
    });
  }
});

module.exports = router;
