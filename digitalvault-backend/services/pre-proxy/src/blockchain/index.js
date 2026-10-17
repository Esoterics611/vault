/**
 * Blockchain Module
 * Handles connection to Base Sepolia and smart contract interactions
 */

const { ethers } = require('ethers');
const logger = require('../utils/logger');

// Contract ABIs (minimal interfaces for what we need)
const CONTENT_REGISTRY_ABI = [
  'function getContentInfo(uint256 contentId) view returns (address owner, bytes32 contentHash, bytes32 metadataHash, uint256 fileSize, uint8 contentType, uint8 accessLevel, bool usesPRE, bool isActive, uint256 createdAt)',
  'function getPREInfo(uint256 contentId) view returns (bytes encryptedKey, bytes32 capsuleHash, bytes ownerPublicKey)',
  'event OwnershipTransferred(uint256 indexed contentId, address indexed previousOwner, address indexed newOwner)'
];

const REKEY_REGISTRY_ABI = [
  'function verifyGrant(uint256 grantId, address grantor, address grantee, bytes32 kfragHash) view returns (bool)',
  'function getGrantInfo(uint256 grantId) view returns (uint256 contentId, address grantor, address grantee, bytes32 kfragHash, uint256 expiresAt, bool isUsed, uint256 createdAt)',
  'event GrantCreated(uint256 indexed grantId, uint256 indexed contentId, address indexed grantee, uint256 expiresAt)',
  'event GrantUsed(uint256 indexed grantId, uint256 indexed contentId, address indexed grantee)'
];

let provider = null;
let contentRegistry = null;
let reKeyRegistry = null;

/**
 * Initialize blockchain connection
 */
async function initBlockchain() {
  try {
    const rpcUrl = process.env.RPC_URL || 'https://sepolia.base.org';
    const chainId = parseInt(process.env.CHAIN_ID) || 84532;

    // Create provider
    provider = new ethers.JsonRpcProvider(rpcUrl, chainId);

    // Test connection
    const network = await provider.getNetwork();
    logger.info(`Connected to blockchain: ${network.name} (Chain ID: ${network.chainId})`);

    // Initialize contract instances
    const contentRegistryAddress = process.env.CONTENT_REGISTRY_ADDRESS;
    const reKeyRegistryAddress = process.env.REKEY_REGISTRY_ADDRESS;

    if (!contentRegistryAddress || !reKeyRegistryAddress) {
      throw new Error('Contract addresses not configured in environment');
    }

    contentRegistry = new ethers.Contract(
      contentRegistryAddress,
      CONTENT_REGISTRY_ABI,
      provider
    );

    reKeyRegistry = new ethers.Contract(
      reKeyRegistryAddress,
      REKEY_REGISTRY_ABI,
      provider
    );

    logger.info('Smart contract instances initialized');
    logger.info(`ContentRegistry: ${contentRegistryAddress}`);
    logger.info(`ReKeyRegistry: ${reKeyRegistryAddress}`);

    return { provider, contentRegistry, reKeyRegistry };
  } catch (error) {
    logger.error('Failed to initialize blockchain:', error);
    throw error;
  }
}

/**
 * Verify a re-encryption grant on-chain
 */
async function verifyGrant(grantId, grantor, grantee, kfragHash) {
  try {
    if (!reKeyRegistry) {
      throw new Error('Blockchain not initialized');
    }

    // Get grant info
    const grantInfo = await reKeyRegistry.getGrantInfo(grantId);

    // Verify grant conditions
    const now = Math.floor(Date.now() / 1000);
    const isValid =
      grantInfo.grantor.toLowerCase() === grantor.toLowerCase() &&
      grantInfo.grantee.toLowerCase() === grantee.toLowerCase() &&
      grantInfo.kfragHash === kfragHash &&
      grantInfo.expiresAt > now &&
      !grantInfo.isUsed;

    if (!isValid) {
      logger.warn('Grant verification failed', {
        grantId,
        grantor,
        grantee,
        kfragHash,
        grantInfo: {
          grantor: grantInfo.grantor,
          grantee: grantInfo.grantee,
          kfragHash: grantInfo.kfragHash,
          expiresAt: grantInfo.expiresAt.toString(),
          isUsed: grantInfo.isUsed
        }
      });
    }

    return {
      isValid,
      contentId: grantInfo.contentId,
      expiresAt: grantInfo.expiresAt,
      isUsed: grantInfo.isUsed
    };
  } catch (error) {
    logger.error('Error verifying grant:', error);
    throw error;
  }
}

/**
 * Get content info from ContentRegistry
 */
async function getContentInfo(contentId) {
  try {
    if (!contentRegistry) {
      throw new Error('Blockchain not initialized');
    }

    const contentInfo = await contentRegistry.getContentInfo(contentId);
    const preInfo = await contentRegistry.getPREInfo(contentId);

    return {
      owner: contentInfo.owner,
      contentHash: contentInfo.contentHash,
      metadataHash: contentInfo.metadataHash,
      fileSize: contentInfo.fileSize,
      usesPRE: contentInfo.usesPRE,
      isActive: contentInfo.isActive,
      encryptedKey: preInfo.encryptedKey,
      capsuleHash: preInfo.capsuleHash,
      ownerPublicKey: preInfo.ownerPublicKey
    };
  } catch (error) {
    logger.error('Error getting content info:', error);
    throw error;
  }
}

/**
 * Get provider instance
 */
function getProvider() {
  if (!provider) {
    throw new Error('Blockchain not initialized. Call initBlockchain() first.');
  }
  return provider;
}

/**
 * Get ContentRegistry contract instance
 */
function getContentRegistry() {
  if (!contentRegistry) {
    throw new Error('Blockchain not initialized. Call initBlockchain() first.');
  }
  return contentRegistry;
}

/**
 * Get ReKeyRegistry contract instance
 */
function getReKeyRegistry() {
  if (!reKeyRegistry) {
    throw new Error('Blockchain not initialized. Call initBlockchain() first.');
  }
  return reKeyRegistry;
}

module.exports = {
  initBlockchain,
  verifyGrant,
  getContentInfo,
  getProvider,
  getContentRegistry,
  getReKeyRegistry
};
