/**
 * Content Routes
 * Handles content retrieval from IPFS
 */

const express = require('express');
const router = express.Router();
const { param, validationResult } = require('express-validator');
const { getPool } = require('../database');
const { getContentFromIPFS } = require('../services/pinata');
const logger = require('../utils/logger');

/**
 * GET /api/ipfs/content/:cid
 * Retrieve content by CID
 */
router.get('/:cid', [
  param('cid').isString().notEmpty().withMessage('Valid CID required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { cid } = req.params;
    const accessorAddress = req.query.address || req.headers['x-wallet-address'];

    logger.info('Retrieving content', { cid, accessor: accessorAddress });

    // Get content from IPFS
    const result = await getContentFromIPFS(cid);

    // Update access tracking
    const pool = getPool();
    await pool.query(
      `UPDATE uploads SET accessed_at = NOW(), access_count = access_count + 1, updated_at = NOW()
       WHERE cid = $1`,
      [cid]
    );

    // Log access
    await pool.query(
      `INSERT INTO access_logs (cid, accessor_address, access_type, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        cid,
        accessorAddress || null,
        'retrieval',
        req.ip,
        req.headers['user-agent']
      ]
    );

    // Set appropriate headers
    res.set('Content-Type', result.contentType);
    res.send(result.data);
  } catch (error) {
    logger.error('Content retrieval error:', error);
    res.status(500).json({
      error: 'Failed to retrieve content',
      code: 'RETRIEVAL_ERROR',
      details: error.message
    });
  }
});

/**
 * GET /api/ipfs/content/:cid/info
 * Get content information without downloading
 */
router.get('/:cid/info', async (req, res) => {
  try {
    const { cid } = req.params;
    const pool = getPool();

    const result = await pool.query(
      `SELECT cid, content_id, file_name, file_size, mime_type, is_encrypted, is_pre_content,
              metadata_cid, created_at, accessed_at, access_count
       FROM uploads
       WHERE cid = $1`,
      [cid]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Content not found',
        code: 'NOT_FOUND'
      });
    }

    res.json({
      success: true,
      content: result.rows[0]
    });
  } catch (error) {
    logger.error('Content info error:', error);
    res.status(500).json({
      error: 'Failed to get content info',
      code: 'INFO_ERROR'
    });
  }
});

/**
 * GET /api/ipfs/content/by-content-id/:contentId
 * Get uploads for a specific content ID
 */
router.get('/by-content-id/:contentId', async (req, res) => {
  try {
    const contentId = parseInt(req.params.contentId);

    if (isNaN(contentId)) {
      return res.status(400).json({ error: 'Valid content ID required' });
    }

    const pool = getPool();
    const result = await pool.query(
      `SELECT cid, file_name, file_size, mime_type, is_encrypted, is_pre_content,
              metadata_cid, created_at, accessed_at, access_count
       FROM uploads
       WHERE content_id = $1
       ORDER BY created_at DESC`,
      [contentId]
    );

    res.json({
      success: true,
      contentId,
      uploads: result.rows
    });
  } catch (error) {
    logger.error('Content lookup error:', error);
    res.status(500).json({
      error: 'Failed to lookup content',
      code: 'LOOKUP_ERROR'
    });
  }
});

module.exports = router;
