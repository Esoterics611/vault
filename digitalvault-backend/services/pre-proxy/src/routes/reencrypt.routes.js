/**
 * Re-encryption Routes
 * Handles proxy re-encryption operations using Umbral PRE
 */

const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const { getPool } = require('../database');
const { verifyGrant, getContentInfo } = require('../blockchain');
const { performReencryption } = require('../umbral');
const logger = require('../utils/logger');

// Stricter rate limiting for re-encryption operations
const reencryptLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_REENCRYPT_MAX) || 50,
  message: { error: 'Too many re-encryption requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * POST /api/proxy/reencrypt
 * Perform proxy re-encryption
 *
 * Body:
 * {
 *   grantId: number,
 *   contentId: number,
 *   grantorAddress: string,
 *   granteeAddress: string,
 *   kfragHash: string (hex),
 *   granteePublicKey: string (hex),
 *   threshold: number,
 *   totalShares: number
 * }
 */
router.post(
  '/',
  reencryptLimiter,
  [
    body('grantId').isInt({ min: 1 }).withMessage('Valid grant ID required'),
    body('contentId').isInt({ min: 1 }).withMessage('Valid content ID required'),
    body('grantorAddress').isEthereumAddress().withMessage('Valid grantor address required'),
    body('granteeAddress').isEthereumAddress().withMessage('Valid grantee address required'),
    body('kfragHash').isString().matches(/^0x[a-fA-F0-9]{64}$/).withMessage('Valid kfrag hash required'),
    body('granteePublicKey').isString().notEmpty().withMessage('Grantee public key required'),
    body('threshold').isInt({ min: 1, max: 10 }).withMessage('Valid threshold required'),
    body('totalShares').isInt({ min: 1, max: 10 }).withMessage('Valid total shares required')
  ],
  async (req, res) => {
    try {
      // Validate request
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const {
        grantId,
        contentId,
        grantorAddress,
        granteeAddress,
        kfragHash,
        granteePublicKey,
        threshold,
        totalShares
      } = req.body;

      // Validate threshold scheme
      if (threshold > totalShares) {
        return res.status(400).json({
          error: 'Threshold cannot exceed total shares',
          code: 'INVALID_THRESHOLD'
        });
      }

      logger.info('Re-encryption request received', {
        grantId,
        contentId,
        grantorAddress,
        granteeAddress
      });

      // Step 1: Verify grant on-chain
      const grantVerification = await verifyGrant(
        grantId,
        grantorAddress,
        granteeAddress,
        kfragHash
      );

      if (!grantVerification.isValid) {
        logger.warn('Grant verification failed', {
          grantId,
          grantorAddress,
          granteeAddress,
          kfragHash
        });
        return res.status(403).json({
          error: 'Grant verification failed',
          code: 'GRANT_INVALID'
        });
      }

      // Verify content ID matches grant
      if (grantVerification.contentId.toString() !== contentId.toString()) {
        return res.status(400).json({
          error: 'Content ID does not match grant',
          code: 'CONTENT_MISMATCH'
        });
      }

      // Step 2: Retrieve capsule from database
      const pool = getPool();
      const capsuleResult = await pool.query(
        'SELECT capsule_data, capsule_hash, owner_address FROM capsules WHERE content_id = $1',
        [contentId]
      );

      if (capsuleResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Capsule not found',
          code: 'CAPSULE_NOT_FOUND'
        });
      }

      const originalCapsule = capsuleResult.rows[0];

      // Verify owner matches grantor
      if (originalCapsule.owner_address.toLowerCase() !== grantorAddress.toLowerCase()) {
        return res.status(403).json({
          error: 'Grantor is not content owner',
          code: 'UNAUTHORIZED_GRANTOR'
        });
      }

      // Step 3: Perform Umbral re-encryption
      logger.info('Performing re-encryption', { contentId, grantId });

      const reencryptionResult = await performReencryption({
        originalCapsule: originalCapsule.capsule_data,
        granteePublicKey,
        threshold,
        totalShares
      });

      // Step 4: Record re-encryption request
      await pool.query(
        `INSERT INTO reencryption_requests
         (grant_id, content_id, from_address, to_address, kfrag_hash, new_capsule_hash, status, completed_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
        [
          grantId,
          contentId,
          grantorAddress,
          granteeAddress,
          kfragHash,
          reencryptionResult.newCapsuleHash,
          'completed'
        ]
      );

      logger.info('Re-encryption completed', {
        grantId,
        contentId,
        newCapsuleHash: reencryptionResult.newCapsuleHash
      });

      res.json({
        success: true,
        reencryption: {
          grantId,
          contentId,
          newCapsule: reencryptionResult.newCapsule,
          newCapsuleHash: reencryptionResult.newCapsuleHash,
          cfrags: reencryptionResult.cfrags,
          threshold,
          totalShares
        }
      });
    } catch (error) {
      logger.error('Re-encryption error:', error);

      // Record failed request if we have enough info
      if (req.body.grantId && req.body.contentId) {
        try {
          const pool = getPool();
          await pool.query(
            `INSERT INTO reencryption_requests
             (grant_id, content_id, from_address, to_address, kfrag_hash, new_capsule_hash, status)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [
              req.body.grantId,
              req.body.contentId,
              req.body.grantorAddress || '',
              req.body.granteeAddress || '',
              req.body.kfragHash || '',
              '',
              'failed'
            ]
          );
        } catch (dbError) {
          logger.error('Failed to record error:', dbError);
        }
      }

      res.status(500).json({
        error: 'Re-encryption failed',
        code: 'REENCRYPTION_ERROR'
      });
    }
  }
);

/**
 * GET /api/proxy/reencrypt/history/:contentId
 * Get re-encryption history for a content item
 */
router.get('/history/:contentId', async (req, res) => {
  try {
    const contentId = parseInt(req.params.contentId);

    if (isNaN(contentId) || contentId < 1) {
      return res.status(400).json({ error: 'Valid content ID required' });
    }

    const pool = getPool();
    const result = await pool.query(
      `SELECT grant_id, from_address, to_address, kfrag_hash, new_capsule_hash, status, created_at, completed_at
       FROM reencryption_requests
       WHERE content_id = $1
       ORDER BY created_at DESC
       LIMIT 100`,
      [contentId]
    );

    res.json({
      success: true,
      contentId,
      requests: result.rows.map(row => ({
        grantId: row.grant_id,
        fromAddress: row.from_address,
        toAddress: row.to_address,
        kfragHash: row.kfrag_hash,
        newCapsuleHash: row.new_capsule_hash,
        status: row.status,
        createdAt: row.created_at,
        completedAt: row.completed_at
      }))
    });
  } catch (error) {
    logger.error('Error fetching re-encryption history:', error);
    res.status(500).json({
      error: 'Failed to fetch history',
      code: 'HISTORY_ERROR'
    });
  }
});

module.exports = router;
