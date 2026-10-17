/**
 * Integration Tests for DAO Governance Service
 * Tests the complete flow: proposals -> voting -> treasury
 */

const { expect } = require('chai');
const request = require('supertest');

const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:3002';

describe('DAO Governance Service - Integration Tests', function() {
  this.timeout(30000);

  before(async function() {
    try {
      const response = await request(BASE_URL).get('/api/dao/health');
      expect(response.status).to.equal(200);
      console.log('✅ Service is running');
    } catch (error) {
      console.error('❌ Service not running. Start the service first:');
      console.error('   cd services/dao-service && npm start');
      throw error;
    }
  });

  describe('Health Checks', function() {
    it('should return basic health status', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/health')
        .expect(200);

      expect(response.body).to.have.property('status', 'healthy');
      expect(response.body).to.have.property('service', 'DAO Governance');
      expect(response.body).to.have.property('version');
    });

    it('should return detailed health status', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/health/detailed')
        .expect('Content-Type', /json/);

      expect(response.body).to.have.property('checks');
      expect(response.body.checks).to.have.property('database');
      expect(response.body.checks).to.have.property('blockchain');
    });
  });

  describe('Proposals', function() {
    it('should list all proposals with pagination', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/proposals')
        .query({ page: 1, pageSize: 10 })
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('proposals');
      expect(response.body.proposals).to.be.an('array');
      expect(response.body).to.have.property('pagination');
      expect(response.body.pagination).to.have.property('page', 1);
      expect(response.body.pagination).to.have.property('pageSize', 10);
    });

    it('should list active proposals only', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/proposals/active')
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('proposals');
      expect(response.body.proposals).to.be.an('array');

      // All proposals should have ACTIVE status
      response.body.proposals.forEach(proposal => {
        expect(proposal.status).to.equal('ACTIVE');
      });
    });

    it('should reject invalid page number', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/proposals')
        .query({ page: -1 })
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should filter proposals by status', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/proposals')
        .query({ status: 'EXECUTED' })
        .expect(200);

      expect(response.body).to.have.property('success', true);
      response.body.proposals.forEach(proposal => {
        expect(proposal.status).to.equal('EXECUTED');
      });
    });

    it('should get proposals by address', async function() {
      const testAddress = '0x' + '1'.repeat(40);

      const response = await request(BASE_URL)
        .get(`/api/dao/proposals/by-address/${testAddress}`)
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('address', testAddress);
      expect(response.body).to.have.property('proposals');
    });

    it('should reject invalid ethereum address', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/proposals/by-address/invalid')
        .expect(400);

      expect(response.body).to.have.property('error');
    });
  });

  describe('Voting', function() {
    it('should get voting power for address', async function() {
      const testAddress = '0x' + '1'.repeat(40);

      const response = await request(BASE_URL)
        .get(`/api/dao/voting/power/${testAddress}`)
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('address');
      expect(response.body).to.have.property('votingPower');
    });

    it('should check if address has voted', async function() {
      const testAddress = '0x' + '1'.repeat(40);
      const proposalId = 1;

      const response = await request(BASE_URL)
        .get(`/api/dao/voting/has-voted/${proposalId}/${testAddress}`)
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('hasVoted');
      expect(response.body.hasVoted).to.be.a('boolean');
    });

    it('should get voting history for address', async function() {
      const testAddress = '0x' + '1'.repeat(40);

      const response = await request(BASE_URL)
        .get(`/api/dao/voting/history/${testAddress}`)
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('votes');
      expect(response.body.votes).to.be.an('array');
    });

    it('should get all votes for a proposal', async function() {
      const proposalId = 1;

      const response = await request(BASE_URL)
        .get(`/api/dao/voting/proposal/${proposalId}`)
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('votes');
      expect(response.body).to.have.property('totals');
      expect(response.body.totals).to.have.property('for');
      expect(response.body.totals).to.have.property('against');
      expect(response.body.totals).to.have.property('abstain');
    });

    it('should respect vote history limit', async function() {
      const testAddress = '0x' + '1'.repeat(40);

      const response = await request(BASE_URL)
        .get(`/api/dao/voting/history/${testAddress}`)
        .query({ limit: 5 })
        .expect(200);

      expect(response.body.votes.length).to.be.at.most(5);
    });
  });

  describe('Treasury', function() {
    it('should get treasury balance', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/treasury/balance');

      // May return 503 if not configured, 200 if configured
      if (response.status === 200) {
        expect(response.body).to.have.property('success', true);
        expect(response.body).to.have.property('balances');
        expect(response.body.balances).to.have.property('eth');
        expect(response.body.balances).to.have.property('vltc');
      } else {
        expect(response.status).to.equal(503);
        expect(response.body.code).to.equal('NOT_CONFIGURED');
      }
    });

    it('should get treasury transactions', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/treasury/transactions')
        .query({ limit: 10 })
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('transactions');
      expect(response.body.transactions).to.be.an('array');
      expect(response.body).to.have.property('pagination');
    });

    it('should filter transactions by type', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/treasury/transactions')
        .query({ type: 'DEPOSIT' })
        .expect(200);

      expect(response.body).to.have.property('success', true);
      response.body.transactions.forEach(tx => {
        expect(tx.type).to.equal('DEPOSIT');
      });
    });

    it('should get treasury statistics', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/treasury/stats')
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('stats');
      expect(response.body.stats).to.have.property('deposits');
      expect(response.body.stats).to.have.property('withdrawals');
      expect(response.body.stats).to.have.property('last30Days');
    });
  });

  describe('Input Validation', function() {
    it('should reject invalid proposal ID', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/proposals/invalid')
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should reject invalid ethereum address format', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/voting/power/not_an_address')
        .expect(400);

      expect(response.body).to.have.property('error');
    });

    it('should reject invalid page size', async function() {
      const response = await request(BASE_URL)
        .get('/api/dao/proposals')
        .query({ pageSize: 1000 })
        .expect(400);

      expect(response.body).to.have.property('error');
    });
  });
});

describe('DAO Governance Service - Unit Tests', function() {
  describe('Blockchain Module', function() {
    it('should have required functions', function() {
      const blockchain = require('../src/blockchain/dao');
      expect(blockchain).to.have.property('initBlockchain');
      expect(blockchain).to.have.property('getProposalState');
      expect(blockchain).to.have.property('getProposalVotes');
      expect(blockchain).to.have.property('getVotingPower');
      expect(blockchain).to.have.property('hasVoted');
    });
  });

  describe('Database Module', function() {
    it('should have required functions', function() {
      const database = require('../src/database');
      expect(database).to.have.property('initDatabase');
      expect(database).to.have.property('getPool');
      expect(database).to.have.property('closeDatabase');
    });
  });
});
