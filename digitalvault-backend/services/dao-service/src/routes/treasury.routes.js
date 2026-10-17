/**
 * Treasury Routes
 * Handles DAO treasury balance and transaction queries
 */

const express = require('express');
const router = express.Router();
const { query, validationResult } = require('express-validator');
const { ethers } = require('ethers');
const { getPool } = require('../database');
const { getProvider, getVaultTokenContract } = require('../blockchain/dao');
const logger = require('../utils/logger');

/**
 * GET /api/dao/treasury/balance
 * Get treasury balance
 */
router.get('/balance', async (req, res) => {
  try {
    const treasuryAddress = process.env.TREASURY_ADDRESS || process.env.DAO_CONTRACT_ADDRESS;

    if (!treasuryAddress) {
      return res.status(503).json({
        error: 'Treasury address not configured',
        code: 'NOT_CONFIGURED'
      });
    }

    const provider = getProvider();
    const vaultToken = getVaultTokenContract();

    // Get ETH balance
    const ethBalance = await provider.getBalance(treasuryAddress);

    // Get VLTC balance
    const vltcBalance = await vaultToken.balanceOf(treasuryAddress);

    res.json({
      success: true,
      treasury: treasuryAddress,
      balances: {
        eth: ethBalance.toString(),
        ethFormatted: ethers.formatEther(ethBalance),
        vltc: vltcBalance.toString(),
        vltcFormatted: ethers.formatEther(vltcBalance)
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error fetching treasury balance:', error);
    res.status(500).json({
      error: 'Failed to fetch treasury balance',
      code: 'BALANCE_ERROR'
    });
  }
});

/**
 * GET /api/dao/treasury/transactions
 * Get treasury transaction history
 */
router.get(
  '/transactions',
  [
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be 1-100'),
    query('offset').optional().isInt({ min: 0 }).withMessage('Valid offset required'),
    query('type').optional().isIn(['DEPOSIT', 'WITHDRAWAL', 'ALL']).withMessage('Invalid type filter')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const limit = parseInt(req.query.limit) || 50;
      const offset = parseInt(req.query.offset) || 0;
      const txType = req.query.type || 'ALL';

      const pool = getPool();

      let whereClause = '';
      let params = [limit, offset];

      if (txType !== 'ALL') {
        whereClause = 'WHERE tx_type = $3';
        params.push(txType);
      }

      const result = await pool.query(
        `SELECT tx_hash, tx_type, amount, token_address, token_symbol,
                proposal_id, from_address, to_address, block_number, timestamp
         FROM treasury_transactions
         ${whereClause}
         ORDER BY timestamp DESC
         LIMIT $1 OFFSET $2`,
        params
      );

      const transactions = result.rows.map(row => ({
        txHash: row.tx_hash,
        type: row.tx_type,
        amount: row.amount,
        tokenAddress: row.token_address,
        tokenSymbol: row.token_symbol,
        proposalId: row.proposal_id,
        from: row.from_address,
        to: row.to_address,
        blockNumber: row.block_number,
        timestamp: row.timestamp
      }));

      res.json({
        success: true,
        transactions,
        pagination: {
          limit,
          offset,
          returned: transactions.length
        }
      });
    } catch (error) {
      logger.error('Error fetching treasury transactions:', error);
      res.status(500).json({
        error: 'Failed to fetch transactions',
        code: 'TRANSACTIONS_ERROR'
      });
    }
  }
);

/**
 * GET /api/dao/treasury/stats
 * Get treasury statistics
 */
router.get('/stats', async (req, res) => {
  try {
    const pool = getPool();

    // Get transaction counts by type
    const statsResult = await pool.query(
      `SELECT
         tx_type,
         COUNT(*) as count,
         SUM(CASE WHEN token_symbol = 'VLTC' THEN amount ELSE 0 END) as total_vltc
       FROM treasury_transactions
       GROUP BY tx_type`
    );

    const stats = {
      deposits: {
        count: 0,
        totalVltc: '0'
      },
      withdrawals: {
        count: 0,
        totalVltc: '0'
      }
    };

    statsResult.rows.forEach(row => {
      if (row.tx_type === 'DEPOSIT') {
        stats.deposits.count = parseInt(row.count);
        stats.deposits.totalVltc = row.total_vltc || '0';
      } else if (row.tx_type === 'WITHDRAWAL') {
        stats.withdrawals.count = parseInt(row.count);
        stats.withdrawals.totalVltc = row.total_vltc || '0';
      }
    });

    // Get recent activity
    const recentResult = await pool.query(
      `SELECT tx_type, COUNT(*) as count
       FROM treasury_transactions
       WHERE timestamp > NOW() - INTERVAL '30 days'
       GROUP BY tx_type`
    );

    stats.last30Days = {
      deposits: 0,
      withdrawals: 0
    };

    recentResult.rows.forEach(row => {
      if (row.tx_type === 'DEPOSIT') {
        stats.last30Days.deposits = parseInt(row.count);
      } else if (row.tx_type === 'WITHDRAWAL') {
        stats.last30Days.withdrawals = parseInt(row.count);
      }
    });

    res.json({
      success: true,
      stats
    });
  } catch (error) {
    logger.error('Error fetching treasury stats:', error);
    res.status(500).json({
      error: 'Failed to fetch treasury stats',
        code: 'STATS_ERROR'
    });
  }
});

module.exports = router;
