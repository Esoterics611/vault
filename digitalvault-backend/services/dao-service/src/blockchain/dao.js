/**
 * DAO Blockchain Module
 * Handles interaction with DAOGovernor smart contract
 */

const { ethers } = require('ethers');
const cron = require('node-cron');
const logger = require('../utils/logger');
const { getPool } = require('../database');

// Contract ABIs (OpenZeppelin Governor standard)
const DAO_ABI = [
  // Proposal functions
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)',
  'function castVote(uint256 proposalId, uint8 support) returns (uint256)',
  'function castVoteWithReason(uint256 proposalId, uint8 support, string reason) returns (uint256)',
  'function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) payable returns (uint256)',
  'function queue(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) returns (uint256)',

  // View functions
  'function state(uint256 proposalId) view returns (uint8)',
  'function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)',
  'function hasVoted(uint256 proposalId, address account) view returns (bool)',
  'function getVotes(address account, uint256 timepoint) view returns (uint256)',
  'function quorum(uint256 timepoint) view returns (uint256)',
  'function votingDelay() view returns (uint256)',
  'function votingPeriod() view returns (uint256)',
  'function proposalThreshold() view returns (uint256)',
  'function proposalSnapshot(uint256 proposalId) view returns (uint256)',
  'function proposalDeadline(uint256 proposalId) view returns (uint256)',

  // Events
  'event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)',
  'event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason)',
  'event ProposalQueued(uint256 proposalId, uint256 eta)',
  'event ProposalExecuted(uint256 proposalId)'
];

const VAULT_TOKEN_ABI = [
  'function balanceOf(address account) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function getVotes(address account) view returns (uint256)',
  'function getPastVotes(address account, uint256 timepoint) view returns (uint256)'
];

let provider = null;
let daoContract = null;
let vaultTokenContract = null;
let eventListener = null;

/**
 * Initialize blockchain connection
 */
async function initBlockchain() {
  try {
    const rpcUrl = process.env.RPC_URL || 'https://sepolia.base.org';
    const chainId = parseInt(process.env.CHAIN_ID) || 84532;

    provider = new ethers.JsonRpcProvider(rpcUrl, chainId);

    const network = await provider.getNetwork();
    logger.info(`Connected to blockchain: ${network.name} (Chain ID: ${network.chainId})`);

    const daoAddress = process.env.DAO_CONTRACT_ADDRESS;
    const vaultTokenAddress = process.env.VAULT_TOKEN_ADDRESS;

    if (!daoAddress || !vaultTokenAddress) {
      logger.warn('DAO or VaultToken address not configured - some features may not work');
      return;
    }

    daoContract = new ethers.Contract(daoAddress, DAO_ABI, provider);
    vaultTokenContract = new ethers.Contract(vaultTokenAddress, VAULT_TOKEN_ABI, provider);

    logger.info('DAO contract instances initialized');
    logger.info(`DAOGovernor: ${daoAddress}`);
    logger.info(`VaultToken: ${vaultTokenAddress}`);

    return { provider, daoContract, vaultTokenContract };
  } catch (error) {
    logger.error('Failed to initialize blockchain:', error);
    throw error;
  }
}

/**
 * Get proposal state
 */
async function getProposalState(proposalId) {
  try {
    const stateNum = await daoContract.state(proposalId);
    const states = ['Pending', 'Active', 'Canceled', 'Defeated', 'Succeeded', 'Queued', 'Expired', 'Executed'];
    return states[Number(stateNum)] || 'Unknown';
  } catch (error) {
    logger.error(`Error getting proposal state for ${proposalId}:`, error);
    throw error;
  }
}

/**
 * Get proposal votes
 */
async function getProposalVotes(proposalId) {
  try {
    const votes = await daoContract.proposalVotes(proposalId);
    return {
      against: votes.againstVotes.toString(),
      for: votes.forVotes.toString(),
      abstain: votes.abstainVotes.toString()
    };
  } catch (error) {
    logger.error(`Error getting votes for proposal ${proposalId}:`, error);
    throw error;
  }
}

/**
 * Get voting power for address
 */
async function getVotingPower(address, blockNumber = null) {
  try {
    let votes;
    if (blockNumber) {
      votes = await vaultTokenContract.getPastVotes(address, blockNumber);
    } else {
      votes = await vaultTokenContract.getVotes(address);
    }
    return votes.toString();
  } catch (error) {
    logger.error(`Error getting voting power for ${address}:`, error);
    throw error;
  }
}

/**
 * Check if address has voted
 */
async function hasVoted(proposalId, address) {
  try {
    return await daoContract.hasVoted(proposalId, address);
  } catch (error) {
    logger.error(`Error checking vote for ${address} on proposal ${proposalId}:`, error);
    return false;
  }
}

/**
 * Start event monitoring
 */
function startEventMonitoring() {
  if (!daoContract) {
    logger.warn('DAO contract not initialized - skipping event monitoring');
    return;
  }

  // Monitor ProposalCreated events
  daoContract.on('ProposalCreated', async (proposalId, proposer, targets, values, signatures, calldatas, voteStart, voteEnd, description, event) => {
    logger.info(`ProposalCreated event: ${proposalId}`);
    try {
      await cacheProposal(proposalId, proposer, description, voteStart, voteEnd);
    } catch (error) {
      logger.error('Error caching proposal:', error);
    }
  });

  // Monitor VoteCast events
  daoContract.on('VoteCast', async (voter, proposalId, support, weight, reason, event) => {
    logger.info(`VoteCast event: ${voter} voted on ${proposalId}`);
    try {
      await cacheVote(proposalId, voter, support, weight, event.log.transactionHash, event.log.blockNumber);
    } catch (error) {
      logger.error('Error caching vote:', error);
    }
  });

  // Monitor ProposalExecuted events
  daoContract.on('ProposalExecuted', async (proposalId, event) => {
    logger.info(`ProposalExecuted event: ${proposalId}`);
    try {
      await markProposalExecuted(proposalId, event.log.transactionHash);
    } catch (error) {
      logger.error('Error marking proposal executed:', error);
    }
  });

  logger.info('Event monitoring started');

  // Also set up periodic cache refresh
  cron.schedule('*/5 * * * *', async () => {
    logger.debug('Running periodic cache refresh');
    await refreshProposalCache();
  });
}

/**
 * Cache proposal in database
 */
async function cacheProposal(proposalId, proposer, description, voteStart, voteEnd) {
  const pool = getPool();

  // Parse title from description (first line)
  const lines = description.split('\n');
  const title = lines[0] || 'Untitled Proposal';
  const fullDescription = lines.slice(1).join('\n') || description;

  await pool.query(
    `INSERT INTO proposal_cache
     (proposal_id, proposer_address, title, description, proposal_type, status, start_block, end_block)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (proposal_id) DO UPDATE SET
       status = EXCLUDED.status,
       updated_at = NOW()`,
    [
      Number(proposalId),
      proposer,
      title,
      fullDescription,
      'GENERAL',
      'ACTIVE',
      Number(voteStart),
      Number(voteEnd)
    ]
  );

  logger.info(`Cached proposal ${proposalId}`);
}

/**
 * Cache vote in database
 */
async function cacheVote(proposalId, voter, support, weight, txHash, blockNumber) {
  const pool = getPool();

  await pool.query(
    `INSERT INTO vote_cache
     (proposal_id, voter_address, support, voting_power, tx_hash, block_number)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (proposal_id, voter_address) DO UPDATE SET
       support = EXCLUDED.support,
       voting_power = EXCLUDED.voting_power,
       tx_hash = EXCLUDED.tx_hash,
       voted_at = NOW()`,
    [
      Number(proposalId),
      voter,
      Number(support),
      weight.toString(),
      txHash,
      blockNumber
    ]
  );

  // Update proposal vote counts
  const votes = await getProposalVotes(proposalId);
  await pool.query(
    `UPDATE proposal_cache
     SET votes_for = $1, votes_against = $2, votes_abstain = $3, updated_at = NOW()
     WHERE proposal_id = $4`,
    [votes.for, votes.against, votes.abstain, Number(proposalId)]
  );

  logger.info(`Cached vote from ${voter} on proposal ${proposalId}`);
}

/**
 * Mark proposal as executed
 */
async function markProposalExecuted(proposalId, txHash) {
  const pool = getPool();

  await pool.query(
    `UPDATE proposal_cache
     SET executed = TRUE, execution_tx_hash = $1, status = 'EXECUTED', updated_at = NOW()
     WHERE proposal_id = $2`,
    [txHash, Number(proposalId)]
  );

  logger.info(`Marked proposal ${proposalId} as executed`);
}

/**
 * Refresh proposal cache from blockchain
 */
async function refreshProposalCache() {
  // This would query recent proposals and update cache
  // For now, we rely on event monitoring
  logger.debug('Cache refresh completed');
}

/**
 * Stop event monitoring
 */
function stopEventMonitoring() {
  if (daoContract) {
    daoContract.removeAllListeners();
    logger.info('Event monitoring stopped');
  }
}

module.exports = {
  initBlockchain,
  startEventMonitoring,
  stopEventMonitoring,
  getProposalState,
  getProposalVotes,
  getVotingPower,
  hasVoted,
  getProvider: () => provider,
  getDAOContract: () => daoContract,
  getVaultTokenContract: () => vaultTokenContract
};
