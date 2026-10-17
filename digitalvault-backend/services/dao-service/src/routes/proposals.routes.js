/**
 * Proposal Routes
 * Handles DAO proposal creation and retrieval
 */

const express = require('express');
const router = express.Router();
const { body, param, query, validationResult } = require('express-validator');
const { getPool } = require('../database');
const { getProposalState, getProposalVotes } = require('../blockchain/dao');
const logger = require('../utils/logger');

/**
 * GET /api/dao/proposals
 * List all proposals with pagination
 */
router.get(
  '/',
  [
    query('page').optional().isInt({ min: 1 }).withMessage('Valid page number required'),
    query('pageSize').optional().isInt({ min: 1, max: 100 }).withMessage('Page size must be 1-100'),
    query('status').optional().isIn(['ACTIVE', 'PENDING', 'DEFEATED', 'SUCCEEDED', 'QUEUED', 'EXECUTED', 'ALL']).withMessage('Invalid status filter')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const page = parseInt(req.query.page) || 1;
      const pageSize = parseInt(req.query.pageSize) || 20;
      const status = req.query.status || 'ALL';
      const offset = (page - 1) * pageSize;

      const pool = getPool();

      // Build query
      let whereClause = '';
      let params = [pageSize, offset];

      if (status !== 'ALL') {
        whereClause = 'WHERE status = $3';
        params.push(status);
      }

      // Get total count
      const countQuery = `SELECT COUNT(*) FROM proposal_cache ${whereClause}`;
      const countResult = await pool.query(
        countQuery,
        status !== 'ALL' ? [status] : []
      );
      const total = parseInt(countResult.rows[0].count);

      // Get proposals
      const proposalsQuery = `
        SELECT proposal_id, proposer_address, title, description, proposal_type, status,
               votes_for, votes_against, votes_abstain, start_block, end_block,
               executed, execution_tx_hash, created_at, updated_at
        FROM proposal_cache
        ${whereClause}
        ORDER BY created_at DESC
        LIMIT $1 OFFSET $2
      `;

      const result = await pool.query(proposalsQuery, params);

      const proposals = result.rows.map(row => ({
        id: row.proposal_id,
        proposer: row.proposer_address,
        title: row.title,
        description: row.description,
        proposalType: row.proposal_type,
        status: row.status,
        votesFor: row.votes_for,
        votesAgainst: row.votes_against,
        votesAbstain: row.votes_abstain,
        startBlock: row.start_block,
        endBlock: row.end_block,
        executed: row.executed,
        executionTxHash: row.execution_tx_hash,
        createdAt: row.created_at,
        updatedAt: row.updated_at
      }));

      res.json({
        success: true,
        proposals,
        pagination: {
          page,
          pageSize,
          total,
          totalPages: Math.ceil(total / pageSize)
        }
      });
    } catch (error) {
      logger.error('Error fetching proposals:', error);
      res.status(500).json({
        error: 'Failed to fetch proposals',
        code: 'FETCH_ERROR'
      });
    }
  }
);

/**
 * GET /api/dao/proposals/active
 * Get only active proposals
 */
router.get('/active', async (req, res) => {
  try {
    const pool = getPool();

    const result = await pool.query(
      `SELECT proposal_id, proposer_address, title, description, proposal_type, status,
              votes_for, votes_against, votes_abstain, start_block, end_block, created_at
       FROM proposal_cache
       WHERE status = 'ACTIVE'
       ORDER BY created_at DESC`
    );

    const proposals = result.rows.map(row => ({
      id: row.proposal_id,
      proposer: row.proposer_address,
      title: row.title,
      description: row.description,
      proposalType: row.proposal_type,
      status: row.status,
      votesFor: row.votes_for,
      votesAgainst: row.votes_against,
      votesAbstain: row.votes_abstain,
      startBlock: row.start_block,
      endBlock: row.end_block,
      createdAt: row.created_at
    }));

    res.json({
      success: true,
      proposals
    });
  } catch (error) {
    logger.error('Error fetching active proposals:', error);
    res.status(500).json({
      error: 'Failed to fetch active proposals',
      code: 'FETCH_ERROR'
    });
  }
});

/**
 * GET /api/dao/proposals/:id
 * Get proposal details by ID
 */
router.get(
  '/:id',
  [
    param('id').isInt({ min: 0 }).withMessage('Valid proposal ID required')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: 'Validation failed', details: errors.array() });
      }

      const proposalId = parseInt(req.params.id);
      const pool = getPool();

      // Get proposal from cache
      const result = await pool.query(
        `SELECT * FROM proposal_cache WHERE proposal_id = $1`,
        [proposalId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          error: 'Proposal not found',
          code: 'PROPOSAL_NOT_FOUND'
        });
      }

      const row = result.rows[0];

      // Get fresh state from blockchain
      try {
        const state = await getProposalState(proposalId);
        const votes = await getProposalVotes(proposalId);

        // Update cache if different
        if (state !== row.status) {
          await pool.query(
            `UPDATE proposal_cache
             SET status = $1, votes_for = $2, votes_against = $3, votes_abstain = $4, updated_at = NOW()
             WHERE proposal_id = $5`,
            [state, votes.for, votes.against, votes.abstain, proposalId]
          );
        }

        res.json({
          success: true,
          proposal: {
            id: row.proposal_id,
            proposer: row.proposer_address,
            title: row.title,
            description: row.description,
            proposalType: row.proposal_type,
            status: state,
            votesFor: votes.for,
            votesAgainst: votes.against,
            votesAbstain: votes.abstain,
            startBlock: row.start_block,
            endBlock: row.end_block,
            executed: row.executed,
            executionTxHash: row.execution_tx_hash,
            targetContract: row.target_contract,
            calldata: row.calldata,
            createdAt: row.created_at,
            updatedAt: new Date()
          }
        });
      } catch (blockchainError) {
        logger.warn('Failed to fetch from blockchain, using cache:', blockchainError);

        // Return cached data
        res.json({
          success: true,
          proposal: {
            id: row.proposal_id,
            proposer: row.proposer_address,
            title: row.title,
            description: row.description,
            proposalType: row.proposal_type,
            status: row.status,
            votesFor: row.votes_for,
            votesAgainst: row.votes_against,
            votesAbstain: row.votes_abstain,
            startBlock: row.start_block,
            endBlock: row.end_block,
            executed: row.executed,
            executionTxHash: row.execution_tx_hash,
            targetContract: row.target_contract,
            calldata: row.calldata,
            createdAt: row.created_at,
            updatedAt: row.updated_at
          },
          cached: true
        });
      }
    } catch (error) {
      logger.error('Error fetching proposal:', error);
      res.status(500).json({
        error: 'Failed to fetch proposal',
        code: 'FETCH_ERROR'
      });
    }
  }
);

/**
 * GET /api/dao/proposals/by-address/:address
 * Get proposals created by specific address
 */
router.get('/by-address/:address', async (req, res) => {
  try {
    const address = req.params.address;

    if (!address.match(/^0x[a-fA-F0-9]{40}$/)) {
      return res.status(400).json({ error: 'Invalid Ethereum address' });
    }

    const pool = getPool();

    const result = await pool.query(
      `SELECT proposal_id, proposer_address, title, description, proposal_type, status,
              votes_for, votes_against, votes_abstain, start_block, end_block, created_at
       FROM proposal_cache
       WHERE proposer_address = $1
       ORDER BY created_at DESC`,
      [address.toLowerCase()]
    );

    const proposals = result.rows.map(row => ({
      id: row.proposal_id,
      proposer: row.proposer_address,
      title: row.title,
      description: row.description,
      proposalType: row.proposal_type,
      status: row.status,
      votesFor: row.votes_for,
      votesAgainst: row.votes_against,
      votesAbstain: row.votes_abstain,
      startBlock: row.start_block,
      endBlock: row.end_block,
      createdAt: row.created_at
    }));

    res.json({
      success: true,
      address,
      proposals
    });
  } catch (error) {
    logger.error('Error fetching proposals by address:', error);
    res.status(500).json({
      error: 'Failed to fetch proposals',
      code: 'FETCH_ERROR'
    });
  }
});

module.exports = router;
