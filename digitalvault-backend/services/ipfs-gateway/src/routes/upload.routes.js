/**
 * Upload Routes
 * Handles file and metadata uploads to IPFS
 */

const express = require('express');
const router = express.Router();
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const { getPool } = require('../database');
const { pinFileToIPFS, pinJSONToIPFS } = require('../services/pinata');
const logger = require('../utils/logger');

// Upload rate limiting (stricter)
const uploadLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000,
  max: parseInt(process.env.RATE_LIMIT_UPLOAD_MAX) || 20,
  message: { error: 'Too many uploads, please try again later' }
});

// File upload configuration
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: parseInt(process.env.MAX_FILE_SIZE) || 104857600 // 100MB
  }
});

/**
 * POST /api/ipfs/upload/file
 * Upload encrypted content file
 */
router.post('/file', uploadLimiter, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file provided' });
    }

    const { buffer, originalname, mimetype, size } = req.file;
    const { contentId, uploaderAddress, isPREContent, metadataCid } = req.body;

    logger.info('Uploading file to IPFS', {
      fileName: originalname,
      size,
      contentId,
      isPRE: isPREContent === 'true'
    });

    // Upload to Pinata
    const pinataMetadata = {
      name: originalname,
      keyvalues: {
        contentId: contentId || 'none',
        uploader: uploaderAddress || 'anonymous',
        isPRE: isPREContent === 'true' ? 'true' : 'false',
        uploadedAt: new Date().toISOString()
      }
    };

    const result = await pinFileToIPFS(buffer, {
      fileName: originalname,
      contentType: mimetype,
      metadata: pinataMetadata
    });

    // Store in database
    const pool = getPool();
    
    await pool.query(
      `INSERT INTO uploads (cid, content_id, uploader_address, file_name, file_size, mime_type, is_pre_content, metadata_cid)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        result.cid,
        contentId ? parseInt(contentId) : null,
        uploaderAddress || null,
        originalname,
        size,
        mimetype,
        isPREContent === 'true',
        metadataCid || null
      ]
    );

    logger.info('File uploaded successfully', { cid: result.cid });

    res.status(201).json({
      success: true,
      cid: result.cid,
      size: result.size,
      timestamp: result.timestamp,
      gateway: `${process.env.PINATA_GATEWAY}/ipfs/${result.cid}`
    });
  } catch (error) {
    logger.error('Upload error:', {
      message: error.message,
      stack: error.stack,
      response: error.response?.data,
      status: error.response?.status
    });
    res.status(500).json({
      error: 'Failed to upload file',
      code: 'UPLOAD_ERROR',
      details: error.message,
      pinataError: error.response?.data
    });
  }
});

/**
 * POST /api/ipfs/upload/metadata
 * Upload metadata JSON
 */
router.post('/metadata', uploadLimiter, [
  body('metadata').isObject().withMessage('Metadata must be an object')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { metadata, contentId, uploaderAddress } = req.body;

    logger.info('Uploading metadata to IPFS', { contentId });

    const result = await pinJSONToIPFS(metadata, {
      name: `metadata-${contentId || Date.now()}`,
      keyvalues: {
        type: 'metadata',
        contentId: contentId || 'none',
        uploader: uploaderAddress || 'anonymous'
      }
    });

    // Store reference in database
    const pool = getPool();
    await pool.query(
      `INSERT INTO uploads (cid, content_id, uploader_address, file_name, file_size, mime_type, is_encrypted)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        result.cid,
        contentId ? parseInt(contentId) : null,
        uploaderAddress || null,
        'metadata.json',
        result.size,
        'application/json',
        false
      ]
    );

    logger.info('Metadata uploaded successfully', { cid: result.cid });

    res.status(201).json({
      success: true,
      cid: result.cid,
      size: result.size,
      timestamp: result.timestamp
    });
  } catch (error) {
    logger.error('Metadata upload error:', error);
    res.status(500).json({
      error: 'Failed to upload metadata',
      code: 'METADATA_ERROR',
      details: error.message
    });
  }
});

/**
 * POST /api/ipfs/upload/json
 * Upload arbitrary JSON data
 */
router.post('/json', uploadLimiter, async (req, res) => {
  try {
    const { data, name } = req.body;

    if (!data) {
      return res.status(400).json({ error: 'No data provided' });
    }

    const result = await pinJSONToIPFS(data, {
      name: name || `json-${Date.now()}`
    });

    res.status(201).json({
      success: true,
      cid: result.cid,
      size: result.size
    });
  } catch (error) {
    logger.error('JSON upload error:', error);
    res.status(500).json({
      error: 'Failed to upload JSON',
      code: 'JSON_ERROR'
    });
  }
});

module.exports = router;
