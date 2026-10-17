/**
 * Integration Tests for DigitalVault Backend Services
 * Tests individual service health and basic functionality
 */

const { expect } = require('chai');
const axios = require('axios');

const PRE_PROXY_URL = process.env.PRE_PROXY_URL || 'http://localhost:3001';
const DAO_SERVICE_URL = process.env.DAO_SERVICE_URL || 'http://localhost:3002';
const IPFS_GATEWAY_URL = process.env.IPFS_GATEWAY_URL || 'http://localhost:3000';

describe('Service Health Checks', function() {
  this.timeout(10000);

  describe('PRE Proxy Service', function() {
    it('should be running and healthy', async function() {
      try {
        const response = await axios.get(`${PRE_PROXY_URL}/api/proxy/health`);
        expect(response.status).to.equal(200);
        expect(response.data).to.have.property('status', 'healthy');
        expect(response.data).to.have.property('service', 'PRE Proxy Network');
        console.log('✅ PRE Proxy: Healthy');
      } catch (error) {
        console.error('❌ PRE Proxy: Unavailable');
        throw error;
      }
    });

    it('should have database connectivity', async function() {
      const response = await axios.get(`${PRE_PROXY_URL}/api/proxy/health/detailed`);
      expect(response.data.checks).to.have.property('database');
      expect(response.data.checks.database).to.have.property('status', 'healthy');
      console.log('✅ PRE Proxy: Database connected');
    });

    it('should have blockchain connectivity', async function() {
      const response = await axios.get(`${PRE_PROXY_URL}/api/proxy/health/detailed`);
      expect(response.data.checks).to.have.property('blockchain');
      expect(response.data.checks.blockchain).to.have.property('status', 'healthy');
      console.log('✅ PRE Proxy: Blockchain connected');
    });
  });

  describe('DAO Service', function() {
    it('should be running and healthy', async function() {
      try {
        const response = await axios.get(`${DAO_SERVICE_URL}/api/dao/health`);
        expect(response.status).to.equal(200);
        expect(response.data).to.have.property('status', 'healthy');
        expect(response.data).to.have.property('service', 'DAO Governance Service');
        console.log('✅ DAO Service: Healthy');
      } catch (error) {
        console.error('❌ DAO Service: Unavailable');
        throw error;
      }
    });

    it('should have database connectivity', async function() {
      const response = await axios.get(`${DAO_SERVICE_URL}/api/dao/health/detailed`);
      expect(response.data.checks).to.have.property('database');
      expect(response.data.checks.database).to.have.property('status', 'healthy');
      console.log('✅ DAO Service: Database connected');
    });

    it('should have blockchain connectivity', async function() {
      const response = await axios.get(`${DAO_SERVICE_URL}/api/dao/health/detailed`);
      expect(response.data.checks).to.have.property('blockchain');
      expect(response.data.checks.blockchain).to.have.property('status', 'healthy');
      console.log('✅ DAO Service: Blockchain connected');
    });
  });

  describe('IPFS Gateway', function() {
    it('should be running and healthy', async function() {
      try {
        const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health`);
        expect(response.status).to.equal(200);
        expect(response.data).to.have.property('status', 'healthy');
        expect(response.data).to.have.property('service', 'IPFS Gateway');
        console.log('✅ IPFS Gateway: Healthy');
      } catch (error) {
        console.error('❌ IPFS Gateway: Unavailable');
        throw error;
      }
    });

    it('should have database connectivity', async function() {
      const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health/detailed`);
      expect(response.data.checks).to.have.property('database');
      expect(response.data.checks.database).to.have.property('status', 'healthy');
      console.log('✅ IPFS Gateway: Database connected');
    });

    it('should have Pinata connectivity', async function() {
      const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health/detailed`);
      expect(response.data.checks).to.have.property('pinata');
      expect(response.data.checks.pinata).to.have.property('status', 'healthy');
      console.log('✅ IPFS Gateway: Pinata connected');
    });
  });
});

describe('Service API Endpoints', function() {
  this.timeout(15000);

  describe('PRE Proxy Endpoints', function() {
    it('should list capsules', async function() {
      const response = await axios.get(`${PRE_PROXY_URL}/api/proxy/capsules`);
      expect(response.status).to.equal(200);
      expect(response.data).to.have.property('success', true);
      expect(response.data).to.have.property('capsules');
      expect(response.data.capsules).to.be.an('array');
      console.log(`✅ PRE Proxy: ${response.data.capsules.length} capsules found`);
    });

    it('should get statistics', async function() {
      const response = await axios.get(`${PRE_PROXY_URL}/api/proxy/stats`);
      expect(response.status).to.equal(200);
      expect(response.data).to.have.property('success', true);
      expect(response.data).to.have.property('stats');
      console.log('✅ PRE Proxy: Statistics retrieved');
    });
  });

  describe('DAO Service Endpoints', function() {
    it('should list proposals', async function() {
      const response = await axios.get(`${DAO_SERVICE_URL}/api/dao/proposals`);
      expect(response.status).to.equal(200);
      expect(response.data).to.have.property('success', true);
      expect(response.data).to.have.property('proposals');
      expect(response.data.proposals).to.be.an('array');
      console.log(`✅ DAO Service: ${response.data.proposals.length} proposals found`);
    });

    it('should get statistics', async function() {
      const response = await axios.get(`${DAO_SERVICE_URL}/api/dao/stats`);
      expect(response.status).to.equal(200);
      expect(response.data).to.have.property('success', true);
      expect(response.data).to.have.property('stats');
      console.log('✅ DAO Service: Statistics retrieved');
    });
  });

  describe('IPFS Gateway Endpoints', function() {
    it('should list pins', async function() {
      const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/pin/list`);
      expect(response.status).to.equal(200);
      expect(response.data).to.have.property('success', true);
      expect(response.data).to.have.property('pins');
      expect(response.data.pins).to.be.an('array');
      console.log(`✅ IPFS Gateway: ${response.data.pins.length} pins found`);
    });

    it('should get pin statistics', async function() {
      const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/pin/stats`);
      expect(response.status).to.equal(200);
      expect(response.data).to.have.property('success', true);
      expect(response.data).to.have.property('stats');
      console.log('✅ IPFS Gateway: Statistics retrieved');
    });
  });
});
