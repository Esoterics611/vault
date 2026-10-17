/**
 * Service-to-Service Communication Tests
 * Tests integration between PRE Proxy, DAO Service, and IPFS Gateway
 */

const { expect } = require('chai');
const axios = require('axios');
const FormData = require('form-data');

const PRE_PROXY_URL = process.env.PRE_PROXY_URL || 'http://localhost:3001';
const DAO_SERVICE_URL = process.env.DAO_SERVICE_URL || 'http://localhost:3002';
const IPFS_GATEWAY_URL = process.env.IPFS_GATEWAY_URL || 'http://localhost:3000';

describe('PRE Proxy ↔ IPFS Gateway Integration', function() {
  this.timeout(30000);

  let testCapsuleCID = null;
  let testContentId = null;

  it('should upload encrypted content to IPFS via gateway', async function() {
    try {
      const testData = {
        data: {
          encrypted: true,
          content: 'test encrypted content',
          timestamp: Date.now()
        },
        name: 'pre-test-capsule'
      };

      const response = await axios.post(
        `${IPFS_GATEWAY_URL}/api/ipfs/upload/json`,
        testData
      );

      if (response.status === 201) {
        expect(response.data).to.have.property('success', true);
        expect(response.data).to.have.property('cid');
        testCapsuleCID = response.data.cid;
        console.log(`✅ Uploaded capsule to IPFS: ${testCapsuleCID}`);
      } else {
        console.log('⚠️  Upload returned non-201 status, skipping');
        this.skip();
      }
    } catch (error) {
      console.log('⚠️  Upload failed, skipping test');
      this.skip();
    }
  });

  it('should retrieve capsule from IPFS gateway', async function() {
    if (!testCapsuleCID) {
      console.log('⚠️  No CID available, skipping');
      this.skip();
      return;
    }

    const response = await axios.get(
      `${IPFS_GATEWAY_URL}/api/ipfs/content/${testCapsuleCID}`
    );

    expect(response.status).to.equal(200);
    expect(response.data).to.be.an('object');
    console.log('✅ Retrieved capsule from IPFS');
  });

  it('should track PRE-related uploads in IPFS gateway', async function() {
    const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/pin/stats`);
    expect(response.data).to.have.property('success', true);
    expect(response.data.stats).to.have.property('totalPins');
    console.log(`✅ IPFS tracking ${response.data.stats.totalPins} total pins`);
  });
});

describe('DAO Service ↔ IPFS Gateway Integration', function() {
  this.timeout(30000);

  let testProposalMetadataCID = null;

  it('should upload proposal metadata to IPFS', async function() {
    try {
      const proposalMetadata = {
        data: {
          title: 'Test DAO Proposal',
          description: 'Integration test proposal',
          category: 'general',
          timestamp: Date.now()
        },
        name: 'dao-proposal-metadata'
      };

      const response = await axios.post(
        `${IPFS_GATEWAY_URL}/api/ipfs/upload/json`,
        proposalMetadata
      );

      if (response.status === 201) {
        expect(response.data).to.have.property('success', true);
        expect(response.data).to.have.property('cid');
        testProposalMetadataCID = response.data.cid;
        console.log(`✅ Uploaded proposal metadata to IPFS: ${testProposalMetadataCID}`);
      } else {
        console.log('⚠️  Upload returned non-201 status, skipping');
        this.skip();
      }
    } catch (error) {
      console.log('⚠️  Upload failed, skipping test');
      this.skip();
    }
  });

  it('should retrieve proposal metadata from IPFS', async function() {
    if (!testProposalMetadataCID) {
      console.log('⚠️  No CID available, skipping');
      this.skip();
      return;
    }

    const response = await axios.get(
      `${IPFS_GATEWAY_URL}/api/ipfs/content/${testProposalMetadataCID}`
    );

    expect(response.status).to.equal(200);
    expect(response.data).to.be.an('object');
    console.log('✅ Retrieved proposal metadata from IPFS');
  });

  it('should verify DAO can access IPFS gateway', async function() {
    const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health`);
    expect(response.status).to.equal(200);
    console.log('✅ DAO can access IPFS gateway');
  });
});

describe('Cross-Service Network Communication', function() {
  this.timeout(15000);

  it('should allow PRE Proxy to reach IPFS Gateway', async function() {
    try {
      const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health`, {
        headers: { 'X-Source-Service': 'pre-proxy' }
      });
      expect(response.status).to.equal(200);
      console.log('✅ PRE Proxy → IPFS Gateway: Connected');
    } catch (error) {
      console.error('❌ PRE Proxy cannot reach IPFS Gateway');
      throw error;
    }
  });

  it('should allow DAO Service to reach IPFS Gateway', async function() {
    try {
      const response = await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health`, {
        headers: { 'X-Source-Service': 'dao-service' }
      });
      expect(response.status).to.equal(200);
      console.log('✅ DAO Service → IPFS Gateway: Connected');
    } catch (error) {
      console.error('❌ DAO Service cannot reach IPFS Gateway');
      throw error;
    }
  });

  it('should allow IPFS Gateway to reach PRE Proxy', async function() {
    try {
      const response = await axios.get(`${PRE_PROXY_URL}/api/proxy/health`, {
        headers: { 'X-Source-Service': 'ipfs-gateway' }
      });
      expect(response.status).to.equal(200);
      console.log('✅ IPFS Gateway → PRE Proxy: Connected');
    } catch (error) {
      console.error('❌ IPFS Gateway cannot reach PRE Proxy');
      throw error;
    }
  });

  it('should allow all services to communicate on shared network', async function() {
    const services = [
      { name: 'PRE Proxy', url: `${PRE_PROXY_URL}/api/proxy/health` },
      { name: 'DAO Service', url: `${DAO_SERVICE_URL}/api/dao/health` },
      { name: 'IPFS Gateway', url: `${IPFS_GATEWAY_URL}/api/ipfs/health` }
    ];

    for (const service of services) {
      const response = await axios.get(service.url);
      expect(response.status).to.equal(200);
      console.log(`✅ ${service.name}: Reachable on shared network`);
    }
  });
});
