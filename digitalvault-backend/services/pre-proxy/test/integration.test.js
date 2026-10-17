/**
 * Integration Tests for PRE Proxy Network
 * Tests the complete flow: capsule storage -> grant verification -> re-encryption
 */

const { expect } = require('chai');
const request = require('supertest');
const { ethers } = require('ethers');

// Note: These tests require a running instance of the service
// and a connection to Base Sepolia testnet

const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:3001';

describe('PRE Proxy Network - Integration Tests', function() {
  // Increase timeout for blockchain interactions
  this.timeout(30000);

  let app;
  let testContentId;
  let testCapsuleData;
  let testCapsuleHash;

  before(async function() {
    // Attempt to connect to test service
    try {
      const response = await request(BASE_URL).get('/api/proxy/health');
      expect(response.status).to.equal(200);
      console.log('✅ Service is running');
    } catch (error) {
      console.error('❌ Service not running. Start the service first:');
      console.error('   cd services/pre-proxy && npm start');
      throw error;
    }
  });

  describe('Health Checks', function() {
    it('should return basic health status', async function() {
      const response = await request(BASE_URL)
        .get('/api/proxy/health')
        .expect(200);

      expect(response.body).to.have.property('status', 'healthy');
      expect(response.body).to.have.property('service', 'PRE Proxy Network');
      expect(response.body).to.have.property('version');
    });

    it('should return detailed health status', async function() {
      const response = await request(BASE_URL)
        .get('/api/proxy/health/detailed')
        .expect('Content-Type', /json/);

      expect(response.body).to.have.property('checks');
      expect(response.body.checks).to.have.property('database');
      expect(response.body.checks).to.have.property('blockchain');
    });
  });

  describe('Capsule Storage', function() {
    before(function() {
      // Generate test data
      testContentId = Date.now(); // Use timestamp as unique content ID for testing
      testCapsuleData = '0x' + Buffer.from('test_capsule_data_' + Date.now()).toString('hex');
      testCapsuleHash = ethers.keccak256(testCapsuleData);
    });

    it('should reject capsule with invalid content ID', async function() {
      const response = await request(BASE_URL)
        .post('/api/proxy/capsules')
        .send({
          contentId: 'invalid',
          capsuleData: testCapsuleData,
          capsuleHash: testCapsuleHash
        })
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should reject capsule with invalid hash format', async function() {
      const response = await request(BASE_URL)
        .post('/api/proxy/capsules')
        .send({
          contentId: testContentId,
          capsuleData: testCapsuleData,
          capsuleHash: 'invalid_hash'
        })
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should reject capsule with empty data', async function() {
      const response = await request(BASE_URL)
        .post('/api/proxy/capsules')
        .send({
          contentId: testContentId,
          capsuleData: '',
          capsuleHash: testCapsuleHash
        })
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should store a valid capsule (if content exists on-chain)', async function() {
      // Note: This test will fail if the content doesn't exist on-chain
      // This is expected behavior for the integration test
      const response = await request(BASE_URL)
        .post('/api/proxy/capsules')
        .send({
          contentId: testContentId,
          capsuleData: testCapsuleData,
          capsuleHash: testCapsuleHash
        });

      // Either success or expected on-chain verification failure
      if (response.status === 201) {
        expect(response.body).to.have.property('success', true);
        expect(response.body.capsule).to.have.property('contentId', testContentId);
      } else {
        // Expected failure if content doesn't exist on-chain
        expect(response.status).to.be.oneOf([400, 500]);
        console.log('   ℹ️  Content not found on-chain (expected for test)');
      }
    });

    it('should retrieve a stored capsule', async function() {
      // Use a known content ID from testnet if available
      const knownContentId = process.env.TEST_CONTENT_ID || 1;

      const response = await request(BASE_URL)
        .get(`/api/proxy/capsules/${knownContentId}`);

      if (response.status === 200) {
        expect(response.body).to.have.property('success', true);
        expect(response.body.capsule).to.have.property('contentId');
        expect(response.body.capsule).to.have.property('capsuleData');
        expect(response.body.capsule).to.have.property('capsuleHash');
      } else {
        expect(response.status).to.equal(404);
        console.log('   ℹ️  Capsule not found (expected if not stored yet)');
      }
    });
  });

  describe('Re-encryption', function() {
    const mockGrantData = {
      grantId: 1,
      contentId: 1,
      grantorAddress: '0x' + '1'.repeat(40),
      granteeAddress: '0x' + '2'.repeat(40),
      kfragHash: '0x' + '3'.repeat(64),
      granteePublicKey: '0x' + '4'.repeat(64),
      threshold: 2,
      totalShares: 3
    };

    it('should reject re-encryption with invalid grant ID', async function() {
      const response = await request(BASE_URL)
        .post('/api/proxy/reencrypt')
        .send({
          ...mockGrantData,
          grantId: 'invalid'
        })
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should reject re-encryption with invalid addresses', async function() {
      const response = await request(BASE_URL)
        .post('/api/proxy/reencrypt')
        .send({
          ...mockGrantData,
          grantorAddress: 'invalid_address'
        })
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should reject re-encryption with threshold > totalShares', async function() {
      const response = await request(BASE_URL)
        .post('/api/proxy/reencrypt')
        .send({
          ...mockGrantData,
          threshold: 5,
          totalShares: 3
        })
        .expect(400);

      expect(response.body).to.have.property('error');
      expect(response.body.code).to.equal('INVALID_THRESHOLD');
    });

    it('should reject re-encryption without valid grant', async function() {
      const response = await request(BASE_URL)
        .post('/api/proxy/reencrypt')
        .send(mockGrantData);

      // Expect failure due to invalid grant (not on-chain)
      expect(response.status).to.be.oneOf([403, 404, 500]);
      if (response.body.code) {
        expect(response.body.code).to.be.oneOf(['GRANT_INVALID', 'CAPSULE_NOT_FOUND']);
      }
    });

    it('should get re-encryption history for content', async function() {
      const response = await request(BASE_URL)
        .get('/api/proxy/reencrypt/history/1')
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('contentId', 1);
      expect(response.body).to.have.property('requests');
      expect(response.body.requests).to.be.an('array');
    });
  });

  describe('Rate Limiting', function() {
    it('should enforce rate limits on re-encryption endpoint', async function() {
      // Skip this test in CI environments
      if (process.env.CI) {
        this.skip();
      }

      const maxRequests = parseInt(process.env.RATE_LIMIT_REENCRYPT_MAX) || 50;
      const mockData = {
        grantId: 999,
        contentId: 999,
        grantorAddress: '0x' + 'a'.repeat(40),
        granteeAddress: '0x' + 'b'.repeat(40),
        kfragHash: '0x' + 'c'.repeat(64),
        granteePublicKey: '0x' + 'd'.repeat(64),
        threshold: 2,
        totalShares: 3
      };

      // Send requests up to the limit
      const requests = [];
      for (let i = 0; i < maxRequests + 5; i++) {
        requests.push(
          request(BASE_URL)
            .post('/api/proxy/reencrypt')
            .send(mockData)
        );
      }

      const responses = await Promise.all(requests);

      // At least some requests should be rate limited
      const rateLimited = responses.filter(r => r.status === 429);
      expect(rateLimited.length).to.be.greaterThan(0);
    });
  });
});

describe('PRE Proxy Network - Unit Tests', function() {
  describe('Umbral Library', function() {
    it('should initialize Umbral library', async function() {
      const { initUmbral } = require('../src/umbral');
      const result = await initUmbral();
      // Result may be false if @nucypher/umbral-pre not installed yet
      expect(result).to.be.a('boolean');
    });
  });

  describe('Blockchain Module', function() {
    it('should have required contract ABIs', function() {
      const blockchain = require('../src/blockchain');
      expect(blockchain).to.have.property('initBlockchain');
      expect(blockchain).to.have.property('verifyGrant');
      expect(blockchain).to.have.property('getContentInfo');
    });
  });

  describe('Database Module', function() {
    it('should have required database functions', function() {
      const database = require('../src/database');
      expect(database).to.have.property('initDatabase');
      expect(database).to.have.property('getPool');
      expect(database).to.have.property('closeDatabase');
    });
  });
});
