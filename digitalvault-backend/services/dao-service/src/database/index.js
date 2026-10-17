/**
 * Database Module
 * Handles PostgreSQL connection and initialization for DAO governance data
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
      database: process.env.DB_NAME || 'digitalvault_dao',
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
  const createProposalCacheTable = `
    CREATE TABLE IF NOT EXISTS proposal_cache (
      id SERIAL PRIMARY KEY,
      proposal_id INTEGER NOT NULL UNIQUE,
      proposer_address VARCHAR(42) NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      proposal_type VARCHAR(50) NOT NULL,
      status VARCHAR(20) NOT NULL,
      votes_for NUMERIC(78,0) DEFAULT 0,
      votes_against NUMERIC(78,0) DEFAULT 0,
      votes_abstain NUMERIC(78,0) DEFAULT 0,
      start_block INTEGER NOT NULL,
      end_block INTEGER NOT NULL,
      executed BOOLEAN DEFAULT FALSE,
      execution_tx_hash VARCHAR(66),
      target_contract VARCHAR(42),
      calldata TEXT,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_proposal_status ON proposal_cache(status);
    CREATE INDEX IF NOT EXISTS idx_proposal_proposer ON proposal_cache(proposer_address);
    CREATE INDEX IF NOT EXISTS idx_proposal_end_block ON proposal_cache(end_block);
  `;

  const createVoteCacheTable = `
    CREATE TABLE IF NOT EXISTS vote_cache (
      id SERIAL PRIMARY KEY,
      proposal_id INTEGER NOT NULL,
      voter_address VARCHAR(42) NOT NULL,
      support SMALLINT NOT NULL,
      voting_power NUMERIC(78,0) NOT NULL,
      tx_hash VARCHAR(66) NOT NULL,
      block_number INTEGER NOT NULL,
      voted_at TIMESTAMP DEFAULT NOW(),
      UNIQUE(proposal_id, voter_address)
    );

    CREATE INDEX IF NOT EXISTS idx_vote_proposal ON vote_cache(proposal_id);
    CREATE INDEX IF NOT EXISTS idx_vote_voter ON vote_cache(voter_address);
  `;

  const createTreasuryTxTable = `
    CREATE TABLE IF NOT EXISTS treasury_transactions (
      id SERIAL PRIMARY KEY,
      tx_hash VARCHAR(66) NOT NULL UNIQUE,
      tx_type VARCHAR(20) NOT NULL,
      amount NUMERIC(78,0) NOT NULL,
      token_address VARCHAR(42) NOT NULL,
      token_symbol VARCHAR(10),
      proposal_id INTEGER,
      from_address VARCHAR(42),
      to_address VARCHAR(42),
      block_number INTEGER NOT NULL,
      timestamp TIMESTAMP NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_treasury_type ON treasury_transactions(tx_type);
    CREATE INDEX IF NOT EXISTS idx_treasury_proposal ON treasury_transactions(proposal_id);
    CREATE INDEX IF NOT EXISTS idx_treasury_timestamp ON treasury_transactions(timestamp);
  `;

  try {
    await pool.query(createProposalCacheTable);
    logger.info('Proposal cache table ready');

    await pool.query(createVoteCacheTable);
    logger.info('Vote cache table ready');

    await pool.query(createTreasuryTxTable);
    logger.info('Treasury transactions table ready');
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
