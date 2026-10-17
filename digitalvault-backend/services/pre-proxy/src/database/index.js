/**
 * Database Module
 * Handles PostgreSQL connection and initialization for capsule storage
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
      database: process.env.DB_NAME || 'digitalvault_pre',
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
  const createCapsuleTable = `
    CREATE TABLE IF NOT EXISTS capsules (
      id SERIAL PRIMARY KEY,
      content_id INTEGER NOT NULL UNIQUE,
      owner_address VARCHAR(42) NOT NULL,
      capsule_data BYTEA NOT NULL,
      capsule_hash VARCHAR(66) NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW(),
      accessed_at TIMESTAMP,
      access_count INTEGER DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_capsules_content_id ON capsules(content_id);
    CREATE INDEX IF NOT EXISTS idx_capsules_owner ON capsules(owner_address);
  `;

  const createReencryptRequestsTable = `
    CREATE TABLE IF NOT EXISTS reencryption_requests (
      id SERIAL PRIMARY KEY,
      grant_id INTEGER NOT NULL,
      content_id INTEGER NOT NULL,
      from_address VARCHAR(42) NOT NULL,
      to_address VARCHAR(42) NOT NULL,
      kfrag_hash VARCHAR(66) NOT NULL,
      new_capsule_hash VARCHAR(66) NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'pending',
      tx_hash VARCHAR(66),
      created_at TIMESTAMP DEFAULT NOW(),
      completed_at TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_reencrypt_grant_id ON reencryption_requests(grant_id);
    CREATE INDEX IF NOT EXISTS idx_reencrypt_content_id ON reencryption_requests(content_id);
    CREATE INDEX IF NOT EXISTS idx_reencrypt_status ON reencryption_requests(status);
  `;

  try {
    await pool.query(createCapsuleTable);
    logger.info('Capsules table ready');

    await pool.query(createReencryptRequestsTable);
    logger.info('Re-encryption requests table ready');
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
