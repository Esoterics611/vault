/**
 * Integration Tests for IPFS Gateway
 */

const { expect } = require('chai');
const request = require('supertest');

const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:3000';

describe('IPFS Gateway - Integration Tests', function() {
  this.timeout(30000);

  before(async function() {
    try {
      const response = await request(BASE_URL).get('/health');
      expect(response.status).to.equal(200);
      console.log('✅ Service is running');
    } catch (error) {
      console.error('❌ Service not running');
      throw error;
    }
  });

  describe('Health Checks', function() {
    it('should return basic health status', async function() {
      const response = await request(BASE_URL)
        .get('/api/ipfs/health')
        .expect(200);

      expect(response.body).to.have.property('status', 'healthy');
      expect(response.body).to.have.property('service', 'IPFS Gateway');
    });

    it('should return detailed health status', async function() {
      const response = await request(BASE_URL)
        .get('/api/ipfs/health/detailed');

      expect(response.body).to.have.property('checks');
      expect(response.body.checks).to.have.property('database');
      expect(response.body.checks).to.have.property('pinata');
    });
  });

  describe('Upload Operations', function() {
    it('should reject upload without file', async function() {
      const response = await request(BASE_URL)
        .post('/api/ipfs/upload/file')
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should upload JSON metadata', async function() {
      const response = await request(BASE_URL)
        .post('/api/ipfs/upload/json')
        .send({
          data: { test: 'data', timestamp: Date.now() },
          name: 'test-json'
        });

      if (response.status === 201) {
        expect(response.body).to.have.property('success', true);
        expect(response.body).to.have.property('cid');
      }
    });
  });

  describe('Pin Management', function() {
    it('should list pins', async function() {
      const response = await request(BASE_URL)
        .get('/api/ipfs/pin/list')
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('pins');
    });

    it('should get pin statistics', async function() {
      const response = await request(BASE_URL)
        .get('/api/ipfs/pin/stats')
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('stats');
    });
  });
});
