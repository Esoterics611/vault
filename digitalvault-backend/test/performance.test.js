/**
 * Performance Benchmarks for DigitalVault Backend
 * Tests response times and throughput
 */

const { expect } = require('chai');
const axios = require('axios');

const PRE_PROXY_URL = process.env.PRE_PROXY_URL || 'http://localhost:3001';
const DAO_SERVICE_URL = process.env.DAO_SERVICE_URL || 'http://localhost:3002';
const IPFS_GATEWAY_URL = process.env.IPFS_GATEWAY_URL || 'http://localhost:3000';

describe('Performance Benchmarks', function() {
  this.timeout(60000);

  describe('Health Endpoint Response Times', function() {
    it('PRE Proxy health check should respond under 200ms', async function() {
      const start = Date.now();
      await axios.get(`${PRE_PROXY_URL}/api/proxy/health`);
      const duration = Date.now() - start;
      
      console.log(`   PRE Proxy health: ${duration}ms`);
      expect(duration).to.be.lessThan(200);
    });

    it('DAO Service health check should respond under 200ms', async function() {
      const start = Date.now();
      await axios.get(`${DAO_SERVICE_URL}/api/dao/health`);
      const duration = Date.now() - start;
      
      console.log(`   DAO Service health: ${duration}ms`);
      expect(duration).to.be.lessThan(200);
    });

    it('IPFS Gateway health check should respond under 200ms', async function() {
      const start = Date.now();
      await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health`);
      const duration = Date.now() - start;
      
      console.log(`   IPFS Gateway health: ${duration}ms`);
      expect(duration).to.be.lessThan(200);
    });
  });

  describe('Database Query Performance', function() {
    it('PRE Proxy capsule list should respond under 500ms', async function() {
      const start = Date.now();
      await axios.get(`${PRE_PROXY_URL}/api/proxy/capsules`);
      const duration = Date.now() - start;
      
      console.log(`   PRE capsule list: ${duration}ms`);
      expect(duration).to.be.lessThan(500);
    });

    it('DAO proposal list should respond under 500ms', async function() {
      const start = Date.now();
      await axios.get(`${DAO_SERVICE_URL}/api/dao/proposals`);
      const duration = Date.now() - start;
      
      console.log(`   DAO proposal list: ${duration}ms`);
      expect(duration).to.be.lessThan(500);
    });

    it('IPFS pin list should respond under 500ms', async function() {
      const start = Date.now();
      await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/pin/list`);
      const duration = Date.now() - start;
      
      console.log(`   IPFS pin list: ${duration}ms`);
      expect(duration).to.be.lessThan(500);
    });
  });

  describe('Concurrent Request Handling', function() {
    it('should handle 10 concurrent health checks', async function() {
      const requests = Array(10).fill(null).map(() => 
        axios.get(`${PRE_PROXY_URL}/api/proxy/health`)
      );

      const start = Date.now();
      const results = await Promise.all(requests);
      const duration = Date.now() - start;

      results.forEach(r => expect(r.status).to.equal(200));
      console.log(`   10 concurrent requests: ${duration}ms`);
      expect(duration).to.be.lessThan(2000);
    });

    it('should handle mixed service requests concurrently', async function() {
      const requests = [
        axios.get(`${PRE_PROXY_URL}/api/proxy/health`),
        axios.get(`${DAO_SERVICE_URL}/api/dao/health`),
        axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/health`),
        axios.get(`${PRE_PROXY_URL}/api/proxy/stats`),
        axios.get(`${DAO_SERVICE_URL}/api/dao/stats`),
        axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/pin/stats`)
      ];

      const start = Date.now();
      const results = await Promise.all(requests);
      const duration = Date.now() - start;

      results.forEach(r => expect(r.status).to.equal(200));
      console.log(`   6 mixed service requests: ${duration}ms`);
      expect(duration).to.be.lessThan(1500);
    });
  });

  describe('Statistics and Analytics Queries', function() {
    it('PRE Proxy statistics should respond under 300ms', async function() {
      const start = Date.now();
      await axios.get(`${PRE_PROXY_URL}/api/proxy/stats`);
      const duration = Date.now() - start;
      
      console.log(`   PRE stats: ${duration}ms`);
      expect(duration).to.be.lessThan(300);
    });

    it('DAO statistics should respond under 300ms', async function() {
      const start = Date.now();
      await axios.get(`${DAO_SERVICE_URL}/api/dao/stats`);
      const duration = Date.now() - start;
      
      console.log(`   DAO stats: ${duration}ms`);
      expect(duration).to.be.lessThan(300);
    });

    it('IPFS pin statistics should respond under 300ms', async function() {
      const start = Date.now();
      await axios.get(`${IPFS_GATEWAY_URL}/api/ipfs/pin/stats`);
      const duration = Date.now() - start;
      
      console.log(`   IPFS stats: ${duration}ms`);
      expect(duration).to.be.lessThan(300);
    });
  });
});
