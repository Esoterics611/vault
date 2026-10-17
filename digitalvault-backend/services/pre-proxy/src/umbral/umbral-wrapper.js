/**
 * Umbral Wrapper
 * Provides a clean interface to @nucypher/umbral-pre operations
 *
 * Note: The @nucypher/umbral-pre package API may vary by version.
 * This wrapper attempts to handle both possible API patterns.
 */

const { ethers } = require('ethers');
const logger = require('../utils/logger');

let umbralLoaded = false;
let Capsule, PublicKey, SecretKey, Signer, reencrypt, generateKFrags;

/**
 * Initialize and load Umbral library
 */
function loadUmbral() {
  if (umbralLoaded) return true;

  try {
    const umbral = require('@nucypher/umbral-pre');

    // Extract classes and functions based on package structure
    // The exact exports depend on the package version
    if (umbral.Capsule) {
      Capsule = umbral.Capsule;
      PublicKey = umbral.PublicKey;
      SecretKey = umbral.SecretKey;
      Signer = umbral.Signer;
      reencrypt = umbral.reencrypt;
      generateKFrags = umbral.generateKFrags;
    } else {
      // Alternative export pattern
      Capsule = umbral.default?.Capsule || umbral;
      PublicKey = umbral.default?.PublicKey;
      SecretKey = umbral.default?.SecretKey;
      Signer = umbral.default?.Signer;
      reencrypt = umbral.default?.reencrypt;
      generateKFrags = umbral.default?.generateKFrags;
    }

    umbralLoaded = true;
    logger.info('Umbral wrapper initialized successfully');
    return true;
  } catch (error) {
    logger.error('Failed to load Umbral library:', error.message);
    return false;
  }
}

/**
 * Parse capsule from bytes
 */
function parseCapsule(capsuleBytes) {
  if (!umbralLoaded) {
    throw new Error('Umbral not loaded');
  }

  try {
    // Handle both Buffer and Uint8Array
    const bytes = Buffer.isBuffer(capsuleBytes)
      ? new Uint8Array(capsuleBytes)
      : capsuleBytes;

    return Capsule.fromBytes ? Capsule.fromBytes(bytes) : new Capsule(bytes);
  } catch (error) {
    logger.error('Failed to parse capsule:', error);
    throw new Error(`Invalid capsule format: ${error.message}`);
  }
}

/**
 * Parse public key from hex string
 */
function parsePublicKey(publicKeyHex) {
  if (!umbralLoaded) {
    throw new Error('Umbral not loaded');
  }

  try {
    const cleanHex = publicKeyHex.replace('0x', '');
    const bytes = new Uint8Array(Buffer.from(cleanHex, 'hex'));

    return PublicKey.fromBytes ? PublicKey.fromBytes(bytes) : new PublicKey(bytes);
  } catch (error) {
    logger.error('Failed to parse public key:', error);
    throw new Error(`Invalid public key format: ${error.message}`);
  }
}

/**
 * Serialize capsule to bytes
 */
function serializeCapsule(capsule) {
  try {
    const bytes = capsule.toBytes ? capsule.toBytes() : capsule.serialize();
    return Buffer.from(bytes);
  } catch (error) {
    logger.error('Failed to serialize capsule:', error);
    throw new Error(`Capsule serialization failed: ${error.message}`);
  }
}

/**
 * Serialize cfrag to bytes
 */
function serializeCFrag(cfrag) {
  try {
    const bytes = cfrag.toBytes ? cfrag.toBytes() : cfrag.serialize();
    return Buffer.from(bytes);
  } catch (error) {
    logger.error('Failed to serialize cfrag:', error);
    throw new Error(`CFrag serialization failed: ${error.message}`);
  }
}

/**
 * Generate test keys for development/testing
 * WARNING: Only for testing! In production, keys come from users' wallets
 */
function generateTestKeys() {
  if (!umbralLoaded) {
    throw new Error('Umbral not loaded');
  }

  try {
    const delegatingKey = SecretKey.random ? SecretKey.random() : SecretKey.generate();
    const receivingKey = SecretKey.random ? SecretKey.random() : SecretKey.generate();
    const signingKey = SecretKey.random ? SecretKey.random() : SecretKey.generate();

    return {
      delegatingSecretKey: delegatingKey,
      delegatingPublicKey: delegatingKey.publicKey ? delegatingKey.publicKey() : PublicKey.fromSecretKey(delegatingKey),
      receivingSecretKey: receivingKey,
      receivingPublicKey: receivingKey.publicKey ? receivingKey.publicKey() : PublicKey.fromSecretKey(receivingKey),
      signingSecretKey: signingKey,
      signer: Signer ? new Signer(signingKey) : signingKey
    };
  } catch (error) {
    logger.error('Failed to generate test keys:', error);
    throw new Error(`Key generation failed: ${error.message}`);
  }
}

module.exports = {
  loadUmbral,
  parseCapsule,
  parsePublicKey,
  serializeCapsule,
  serializeCFrag,
  generateTestKeys,
  // Export for direct access if needed
  get Capsule() { return Capsule; },
  get PublicKey() { return PublicKey; },
  get SecretKey() { return SecretKey; },
  get Signer() { return Signer; },
  get reencrypt() { return reencrypt; },
  get generateKFrags() { return generateKFrags; },
  get isLoaded() { return umbralLoaded; }
};
