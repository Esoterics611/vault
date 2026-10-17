/**
 * Pinata Service
 * Handles all Pinata API interactions
 */

const axios = require('axios');
const FormData = require('form-data');
const logger = require('../utils/logger');

const PINATA_API_URL = 'https://api.pinata.cloud';
let pinataConfig = null;

/**
 * Initialize Pinata client with credentials
 */
async function initPinata() {
  const apiKey = process.env.PINATA_API_KEY;
  const secretKey = process.env.PINATA_SECRET_KEY;
  const jwt = process.env.PINATA_JWT;

  if (!apiKey && !jwt) {
    logger.warn('Pinata credentials not configured - service will have limited functionality');
    return false;
  }

  pinataConfig = {
    headers: jwt ? {
      'Authorization': `Bearer ${jwt}`
    } : {
      'pinata_api_key': apiKey,
      'pinata_secret_api_key': secretKey
    }
  };

  // Test connection
  try {
    await testAuthentication();
    logger.info('Pinata authentication successful');
    return true;
  } catch (error) {
    logger.error('Pinata authentication failed:', error.message);
    throw error;
  }
}

/**
 * Test Pinata authentication
 */
async function testAuthentication() {
  const response = await axios.get(
    `${PINATA_API_URL}/data/testAuthentication`,
    pinataConfig
  );
  return response.data;
}

/**
 * Upload file buffer to IPFS via Pinata
 */
async function pinFileToIPFS(buffer, options = {}) {
  const { fileName, metadata } = options;

  const formData = new FormData();
  formData.append('file', buffer, {
    filename: fileName || 'file',
    contentType: options.contentType || 'application/octet-stream'
  });

  if (metadata) {
    formData.append('pinataMetadata', JSON.stringify(metadata));
  }

  const response = await axios.post(
    `${PINATA_API_URL}/pinning/pinFileToIPFS`,
    formData,
    {
      maxBodyLength: Infinity,
      headers: {
        ...formData.getHeaders(),
        ...pinataConfig.headers
      }
    }
  );

  return {
    cid: response.data.IpfsHash,
    size: response.data.PinSize,
    timestamp: response.data.Timestamp
  };
}

/**
 * Upload JSON to IPFS via Pinata
 */
async function pinJSONToIPFS(json, metadata = {}) {
  const response = await axios.post(
    `${PINATA_API_URL}/pinning/pinJSONToIPFS`,
    {
      pinataContent: json,
      pinataMetadata: metadata
    },
    pinataConfig
  );

  return {
    cid: response.data.IpfsHash,
    size: response.data.PinSize,
    timestamp: response.data.Timestamp
  };
}

/**
 * Unpin content from Pinata
 */
async function unpinContent(cid) {
  await axios.delete(
    `${PINATA_API_URL}/pinning/unpin/${cid}`,
    pinataConfig
  );
  return true;
}

/**
 * Get pin list from Pinata
 */
async function getPinList(filters = {}) {
  const params = new URLSearchParams();

  if (filters.cid) params.append('hashContains', filters.cid);
  if (filters.status) params.append('status', filters.status);
  if (filters.pageLimit) params.append('pageLimit', filters.pageLimit);
  if (filters.pageOffset) params.append('pageOffset', filters.pageOffset);

  const response = await axios.get(
    `${PINATA_API_URL}/data/pinList?${params.toString()}`,
    pinataConfig
  );

  return {
    count: response.data.count,
    pins: response.data.rows
  };
}

/**
 * Get content from IPFS via Pinata gateway
 */
async function getContentFromIPFS(cid) {
  const gateway = process.env.PINATA_GATEWAY || 'https://gateway.pinata.cloud';
  const response = await axios.get(
    `${gateway}/ipfs/${cid}`,
    { responseType: 'arraybuffer' }
  );

  return {
    data: response.data,
    contentType: response.headers['content-type']
  };
}

/**
 * Update pin metadata
 */
async function updatePinMetadata(cid, metadata) {
  await axios.put(
    `${PINATA_API_URL}/pinning/hashMetadata`,
    {
      ipfsPinHash: cid,
      name: metadata.name,
      keyvalues: metadata.keyvalues
    },
    pinataConfig
  );
  return true;
}

/**
 * Get total pinned size
 */
async function getTotalPinnedSize() {
  const response = await axios.get(
    `${PINATA_API_URL}/data/pinList?status=pinned&pageLimit=1`,
    pinataConfig
  );

  return {
    count: response.data.count,
    totalSize: response.data.rows.reduce((sum, pin) => sum + pin.size, 0)
  };
}

module.exports = {
  initPinata,
  testAuthentication,
  pinFileToIPFS,
  pinJSONToIPFS,
  unpinContent,
  getPinList,
  getContentFromIPFS,
  updatePinMetadata,
  getTotalPinnedSize
};
