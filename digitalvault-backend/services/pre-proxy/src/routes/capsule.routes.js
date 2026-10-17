/**
 * Capsule Storage Routes
 * Handles storage and retrieval of Umbral capsules
 */

const express = require('express');
const router = express.Router();
const { body, param, validationResult } = require('express-validator');
const { getPool } = require('../database');
const { getContentInfo } = require('../blockchain');
const logger = require('../utils/logger');

/**
 * POST /api/proxy/capsules
 * Store a new capsule
 *
 * Body:
 * {
 *   contentId: number,
 *   capsuleData: string (hex),
 *   capsuleHash: string (hex)
 * }
 */
router.post(
  '/',
  [
    body('contentId').isInt({ min: 1 }).withMessage('Valid content ID required'),
    body('capsuleData').isString().notEmpty().withMessage('Capsule data required'),
    body('capsuleHash').isString().matches(/^0x[a-fA-F0-9]{64}$/).withMessage('Valid capsule hash required')
  ],
  async (req, res) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const { contentId, capsuleData, capsuleHash } = req.body;

      // Verify content exists on-chain and uses PRE
      const contentInfo = await getContentInfo(contentId);
      if (!contentInfo.usesPRE) {
        return res.status(400).json({
          error: 'Content does not use PRE',
          code: 'NOT_PRE_CONTENT'
        });
      }

      if (!contentInfo.isActive) {
        return res.status(400).json({
          error: 'Content is not active',
          code: 'CONTENT_INACTIVE'
        });
      }

      // Verify capsule hash matches on-chain
      if (contentInfo.capsuleHash !== capsuleHash) {
        return res.status(400).json({
          error: 'Capsule hash mismatch',
          code: 'CAPSULE_HASH_MISMATCH'
        });
      }

      // Store capsule in database
      const pool = getPool();
      const result = await pool.query(
        `INSERT INTO capsules (content_id, owner_address, capsule_data, capsule_hash)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (content_id)
         DO UPDATE SET
           capsule_data = EXCLUDED.capsule_data,
           capsule_hash = EXCLUDED.capsule_hash,
           updated_at = NOW()
         RETURNING id, content_id, created_at, updated_at`,
        [contentId, contentInfo.owner, Buffer.from(capsuleData.replace('0x', ''), 'hex'), capsuleHash]
      );

      logger.info('Capsule stored', {
        contentId,
        capsuleId: result.rows[0].id,
        owner: contentInfo.owner
      });

      res.status(201).json({
        success: true,
        capsule: {
          id: result.rows[0].id,
          contentId: result.rows[0].content_id,
          createdAt: result.rows[0].created_at,
          updatedAt: result.rows[0].updated_at
        }
      });
    } catch (error) {
      logger.error('Error storing capsule:', error);
      res.status(500).json({
        error: 'Failed to store capsule',
        code: 'STORAGE_ERROR'
      });
    }
  }
);

/**
 * GET /api/proxy/capsules/:contentId
 * Retrieve a capsule by content ID
 */
router.get(
  '/:contentId',
  [
    param('contentId').isInt({ min: 1 }).withMessage('Valid content ID required')
  ],
  async (req, res) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const contentId = parseInt(req.params.contentId);

      // Retrieve capsule from database
      const pool = getPool();
      const result = await pool.query(
        `UPDATE capsules
         SET accessed_at = NOW(), access_count = access_count + 1
         WHERE content_id = $1
         RETURNING id, content_id, owner_address, capsule_data, capsule_hash, created_at, access_count`,
        [contentId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          error: 'Capsule not found',
          code: 'CAPSULE_NOT_FOUND'
        });
      }

      const capsule = result.rows[0];

      logger.info('Capsule retrieved', {
        contentId,
        capsuleId: capsule.id,
        accessCount: capsule.access_count
      });

      res.json({
        success: true,
        capsule: {
          id: capsule.id,
          contentId: capsule.content_id,
          ownerAddress: capsule.owner_address,
          capsuleData: '0x' + capsule.capsule_data.toString('hex'),
          capsuleHash: capsule.capsule_hash,
          createdAt: capsule.created_at,
          accessCount: capsule.access_count
        }
      });
    } catch (error) {
      logger.error('Error retrieving capsule:', error);
      res.status(500).json({
        error: 'Failed to retrieve capsule',
        code: 'RETRIEVAL_ERROR'
      });
    }
  }
);

module.exports = router;
