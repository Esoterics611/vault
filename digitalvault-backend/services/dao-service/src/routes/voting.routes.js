/**
 * Voting Routes
 * Handles vote casting and voting power queries
 */

const express = require('express');
const router = express.Router();
const { param, query, validationResult } = require('express-validator');
const { getPool } = require('../database');
const { getVotingPower, hasVoted } = require('../blockchain/dao');
const logger = require('../utils/logger');

/**
 * GET /api/dao/voting/power/:address
 * Get voting power for an address
 */
router.get(
  '/power/:address',
  [
    param('address').isEthereumAddress().withMessage('Valid Ethereum address required'),
    query('blockNumber').optional().isInt({ min: 0 }).withMessage('Valid block number required')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const address = req.params.address;
      const blockNumber = req.query.blockNumber ? parseInt(req.query.blockNumber) : null;

      const votingPower = await getVotingPower(address, blockNumber);

      res.json({
        success: true,
        address,
        votingPower,
        blockNumber: blockNumber || 'current'
      });
    } catch (error) {
      logger.error('Error fetching voting power:', error);
      res.status(500).json({
        error: 'Failed to fetch voting power',
        code: 'VOTING_POWER_ERROR'
      });
    }
  }
);

/**
 * GET /api/dao/voting/has-voted/:proposalId/:address
 * Check if address has voted on proposal
 */
router.get(
  '/has-voted/:proposalId/:address',
  [
    param('proposalId').isInt({ min: 0 }).withMessage('Valid proposal ID required'),
    param('address').isEthereumAddress().withMessage('Valid Ethereum address required')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const proposalId = parseInt(req.params.proposalId);
      const address = req.params.address;

      const voted = await hasVoted(proposalId, address);

      // If voted, get vote details from cache
      let voteDetails = null;
      if (voted) {
        const pool = getPool();
        const result = await pool.query(
          `SELECT support, voting_power, tx_hash, voted_at
           FROM vote_cache
           WHERE proposal_id = $1 AND voter_address = $2`,
          [proposalId, address.toLowerCase()]
        );

        if (result.rows.length > 0) {
          const row = result.rows[0];
          voteDetails = {
            support: row.support,
            supportLabel: row.support === 0 ? 'Against' : row.support === 1 ? 'For' : 'Abstain',
            votingPower: row.voting_power,
            txHash: row.tx_hash,
            votedAt: row.voted_at
          };
        }
      }

      res.json({
        success: true,
        proposalId,
        address,
        hasVoted: voted,
        vote: voteDetails
      });
    } catch (error) {
      logger.error('Error checking vote status:', error);
      res.status(500).json({
        error: 'Failed to check vote status',
        code: 'VOTE_CHECK_ERROR'
      });
    }
  }
);

/**
 * GET /api/dao/voting/history/:address
 * Get voting history for address
 */
router.get(
  '/history/:address',
  [
    param('address').isEthereumAddress().withMessage('Valid Ethereum address required'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be 1-100')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const address = req.params.address;
      const limit = parseInt(req.query.limit) || 50;

      const pool = getPool();

      const result = await pool.query(
        `SELECT v.proposal_id, v.support, v.voting_power, v.tx_hash, v.voted_at,
                p.title, p.status
         FROM vote_cache v
         JOIN proposal_cache p ON v.proposal_id = p.proposal_id
         WHERE v.voter_address = $1
         ORDER BY v.voted_at DESC
         LIMIT $2`,
        [address.toLowerCase(), limit]
      );

      const votes = result.rows.map(row => ({
        proposalId: row.proposal_id,
        proposalTitle: row.title,
        proposalStatus: row.status,
        support: row.support,
        supportLabel: row.support === 0 ? 'Against' : row.support === 1 ? 'For' : 'Abstain',
        votingPower: row.voting_power,
        txHash: row.tx_hash,
        votedAt: row.voted_at
      }));

      res.json({
        success: true,
        address,
        votes,
        total: votes.length
      });
    } catch (error) {
      logger.error('Error fetching voting history:', error);
      res.status(500).json({
        error: 'Failed to fetch voting history',
        code: 'HISTORY_ERROR'
      });
    }
  }
);

/**
 * GET /api/dao/voting/proposal/:proposalId
 * Get all votes for a proposal
 */
router.get(
  '/proposal/:proposalId',
  [
    param('proposalId').isInt({ min: 0 }).withMessage('Valid proposal ID required')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const proposalId = parseInt(req.params.proposalId);
      const pool = getPool();

      const result = await pool.query(
        `SELECT voter_address, support, voting_power, tx_hash, voted_at
         FROM vote_cache
         WHERE proposal_id = $1
         ORDER BY voted_at DESC`,
        [proposalId]
      );

      const votes = result.rows.map(row => ({
        voter: row.voter_address,
        support: row.support,
        supportLabel: row.support === 0 ? 'Against' : row.support === 1 ? 'For' : 'Abstain',
        votingPower: row.voting_power,
        txHash: row.tx_hash,
        votedAt: row.voted_at
      }));

      // Calculate totals
      const totals = {
        for: '0',
        against: '0',
        abstain: '0',
        total: '0'
      };

      votes.forEach(vote => {
        const power = BigInt(vote.votingPower);
        totals.total = (BigInt(totals.total) + power).toString();

        if (vote.support === 0) {
          totals.against = (BigInt(totals.against) + power).toString();
        } else if (vote.support === 1) {
          totals.for = (BigInt(totals.for) + power).toString();
        } else {
          totals.abstain = (BigInt(totals.abstain) + power).toString();
        }
      });

      res.json({
        success: true,
        proposalId,
        votes,
        totals,
        voterCount: votes.length
      });
    } catch (error) {
      logger.error('Error fetching proposal votes:', error);
      res.status(500).json({
        error: 'Failed to fetch proposal votes',
        code: 'VOTES_ERROR'
      });
    }
  }
);

module.exports = router;
