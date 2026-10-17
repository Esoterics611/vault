const express = require('express');
const { Sequelize, DataTypes } = require('sequelize');
const { ethers } = require('ethers');
require('dotenv').config();

const app = express();
const PORT = process.env.INDEXER_PORT || 3001;

// Database connection
const sequelize = new Sequelize({
  dialect: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'digitalvault',
  username: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  logging: false,
});

// Define models
const Content = sequelize.define('Content', {
  content_id: { type: DataTypes.BIGINT, primaryKey: true },
  content_hash: DataTypes.STRING,
  metadata_hash: DataTypes.STRING,
  owner: { type: DataTypes.STRING, allowNull: false },
  creator: { type: DataTypes.STRING, allowNull: false },
  created_at: DataTypes.DATE,
  file_size: DataTypes.BIGINT,
  content_type: DataTypes.STRING,
  access_model: DataTypes.STRING,
  view_count: { type: DataTypes.INTEGER, defaultValue: 0 },
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
});

const Listing = sequelize.define('Listing', {
  listing_id: { type: DataTypes.BIGINT, primaryKey: true },
  content_id: DataTypes.BIGINT,
  seller: { type: DataTypes.STRING, allowNull: false },
  price: DataTypes.DECIMAL(78, 0),
  listing_type: DataTypes.STRING,
  access_duration: DataTypes.INTEGER,
  max_keys: DataTypes.INTEGER,
  sold_keys: { type: DataTypes.INTEGER, defaultValue: 0 },
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
  listed_at: DataTypes.DATE,
});

const Transaction = sequelize.define('Transaction', {
  tx_hash: { type: DataTypes.STRING, primaryKey: true },
  from_address: DataTypes.STRING,
  to_address: DataTypes.STRING,
  content_id: DataTypes.BIGINT,
  amount: DataTypes.DECIMAL(78, 0),
  transaction_type: DataTypes.STRING,
  timestamp: DataTypes.DATE,
  status: DataTypes.STRING,
});

const Provider = sequelize.define('Provider', {
  provider_address: { type: DataTypes.STRING, primaryKey: true },
  ipfs_node_id: DataTypes.STRING,
  staked_amount: DataTypes.DECIMAL(78, 0),
  storage_capacity: DataTypes.BIGINT,
  used_storage: DataTypes.BIGINT,
  content_count: { type: DataTypes.INTEGER, defaultValue: 0 },
  uptime: DataTypes.DECIMAL(10, 2),
  reputation_score: DataTypes.INTEGER,
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
});

// Middleware
app.use(express.json());

// API Endpoints

/**
 * @route   GET /api/contents
 * @desc    Get contents with filters
 */
app.get('/api/contents', async (req, res) => {
  try {
    const { owner, creator, type, limit = 50, offset = 0 } = req.query;

    const where = {};
    if (owner) where.owner = owner;
    if (creator) where.creator = creator;
    if (type) where.content_type = type;

    const contents = await Content.findAll({
      where,
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['created_at', 'DESC']],
    });

    res.json({ success: true, data: contents });
  } catch (error) {
    console.error('Get contents error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/contents/:id
 * @desc    Get single content by ID
 */
app.get('/api/contents/:id', async (req, res) => {
  try {
    const content = await Content.findByPk(req.params.id);

    if (!content) {
      return res.status(404).json({ success: false, error: 'Content not found' });
    }

    res.json({ success: true, data: content });
  } catch (error) {
    console.error('Get content error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/listings
 * @desc    Get marketplace listings
 */
app.get('/api/listings', async (req, res) => {
  try {
    const { type, priceMin, priceMax, limit = 50, offset = 0 } = req.query;

    const where = { is_active: true };
    if (type) where.listing_type = type;
    if (priceMin || priceMax) {
      where.price = {};
      if (priceMin) where.price[Sequelize.Op.gte] = priceMin;
      if (priceMax) where.price[Sequelize.Op.lte] = priceMax;
    }

    const listings = await Listing.findAll({
      where,
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['listed_at', 'DESC']],
    });

    res.json({ success: true, data: listings });
  } catch (error) {
    console.error('Get listings error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/transactions/:address
 * @desc    Get transactions for an address
 */
app.get('/api/transactions/:address', async (req, res) => {
  try {
    const { address } = req.params;
    const { limit = 50, offset = 0 } = req.query;

    const transactions = await Transaction.findAll({
      where: {
        [Sequelize.Op.or]: [
          { from_address: address },
          { to_address: address },
        ],
      },
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['timestamp', 'DESC']],
    });

    res.json({ success: true, data: transactions });
  } catch (error) {
    console.error('Get transactions error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/providers
 * @desc    Get storage providers
 */
app.get('/api/providers', async (req, res) => {
  try {
    const { minReputation, minCapacity, limit = 50 } = req.query;

    const where = { is_active: true };
    if (minReputation) where.reputation_score = { [Sequelize.Op.gte]: minReputation };
    if (minCapacity) where.storage_capacity = { [Sequelize.Op.gte]: minCapacity };

    const providers = await Provider.findAll({
      where,
      limit: parseInt(limit),
      order: [['reputation_score', 'DESC']],
    });

    res.json({ success: true, data: providers });
  } catch (error) {
    console.error('Get providers error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/analytics/overview
 * @desc    Get platform analytics
 */
app.get('/api/analytics/overview', async (req, res) => {
  try {
    const totalContents = await Content.count();
    const totalListings = await Listing.count({ where: { is_active: true } });
    const totalProviders = await Provider.count({ where: { is_active: true } });
    const totalTransactions = await Transaction.count();

    res.json({
      success: true,
      data: {
        totalContents,
        totalListings,
        totalProviders,
        totalTransactions,
      },
    });
  } catch (error) {
    console.error('Get analytics error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'metadata-indexer' });
});

// Initialize database and start server
async function init() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    await sequelize.sync({ alter: true });
    console.log('✅ Database synced');

    // Start blockchain event listener
    startEventListener();

    app.listen(PORT, () => {
      console.log(`🚀 Metadata Indexer running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to initialize:', error);
    process.exit(1);
  }
}

// Blockchain event listener
function startEventListener() {
  const provider = new ethers.JsonRpcProvider(
    process.env.RPC_URL || 'http://127.0.0.1:8545'
  );

  // ContentRegistry events
  const contentRegistryAddress = process.env.CONTENT_REGISTRY_ADDRESS;
  if (contentRegistryAddress) {
    const filter = {
      address: contentRegistryAddress,
      topics: [
        ethers.id('ContentRegistered(uint256,address,uint8,uint256)'),
      ],
    };

    provider.on(filter, async (log) => {
      try {
        // Parse event and save to database
        console.log('ContentRegistered event:', log);
        // TODO: Implement event parsing and database insertion
      } catch (error) {
        console.error('Event processing error:', error);
      }
    });

    console.log('📡 Listening for blockchain events...');
  }
}

init();

module.exports = app;
