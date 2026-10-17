/**
 * Database Module
 * Handles PostgreSQL connection for IPFS upload tracking
 */

const { Pool } = require('pg');
const logger = require('../utils/logger');

let pool = null;

/**
 * Initialize database connection pool
 */
async function initDatabase() {
  try {
    pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT) || 5432,
      database: process.env.DB_NAME || 'digitalvault_ipfs',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD,
      max: parseInt(process.env.DB_POOL_MAX) || 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    });

    // Test connection
    const client = await pool.connect();
    await client.query('SELECT NOW()');
    client.release();

    logger.info('Database connection pool initialized');

    // Create tables if they don't exist
    await createTables();

    return pool;
  } catch (error) {
    logger.error('Failed to initialize database:', error);
    throw error;
  }
}

/**
 * Create database tables if they don't exist
 */
async function createTables() {
  const createUploadsTable = `
    CREATE TABLE IF NOT EXISTS uploads (
      id SERIAL PRIMARY KEY,
      cid VARCHAR(100) NOT NULL UNIQUE,
      content_id INTEGER,
      uploader_address VARCHAR(42),
      file_name VARCHAR(255),
      file_size BIGINT NOT NULL,
      mime_type VARCHAR(100),
      is_encrypted BOOLEAN DEFAULT true,
      is_pre_content BOOLEAN DEFAULT false,
      metadata_cid VARCHAR(100),
      pin_status VARCHAR(20) DEFAULT 'pinned',
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW(),
      accessed_at TIMESTAMP,
      access_count INTEGER DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_uploads_cid ON uploads(cid);
    CREATE INDEX IF NOT EXISTS idx_uploads_content_id ON uploads(content_id);
    CREATE INDEX IF NOT EXISTS idx_uploads_uploader ON uploads(uploader_address);
    CREATE INDEX IF NOT EXISTS idx_uploads_created ON uploads(created_at);
  `;

  const createPinsTable = `
    CREATE TABLE IF NOT EXISTS pins (
      id SERIAL PRIMARY KEY,
      cid VARCHAR(100) NOT NULL,
      pin_type VARCHAR(20) NOT NULL,
      status VARCHAR(20) DEFAULT 'pinned',
      size BIGINT,
      pinned_at TIMESTAMP DEFAULT NOW(),
      unpinned_at TIMESTAMP,
      metadata JSONB,
      UNIQUE(cid, pin_type)
    );

    CREATE INDEX IF NOT EXISTS idx_pins_cid ON pins(cid);
    CREATE INDEX IF NOT EXISTS idx_pins_status ON pins(status);
  `;

  const createAccessLogsTable = `
    CREATE TABLE IF NOT EXISTS access_logs (
      id SERIAL PRIMARY KEY,
      cid VARCHAR(100) NOT NULL,
      accessor_address VARCHAR(42),
      access_type VARCHAR(20) NOT NULL,
      ip_address VARCHAR(45),
      user_agent TEXT,
      accessed_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_access_cid ON access_logs(cid);
    CREATE INDEX IF NOT EXISTS idx_access_time ON access_logs(accessed_at);
  `;

  try {
    await pool.query(createUploadsTable);
    logger.info('Uploads table ready');

    await pool.query(createPinsTable);
    logger.info('Pins table ready');

    await pool.query(createAccessLogsTable);
    logger.info('Access logs table ready');
  } catch (error) {
    logger.error('Failed to create tables:', error);
    throw error;
  }
}

/**
 * Get database pool
 */
function getPool() {
  if (!pool) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return pool;
}

/**
 * Close database connection
 */
async function closeDatabase() {
  if (pool) {
    await pool.end();
    logger.info('Database connection closed');
  }
}

module.exports = {
  initDatabase,
  getPool,
  closeDatabase
};
