/// API endpoints for backend services
class ApiEndpoints {
  // Base URLs - Production ready: Use host machine's actual IP
  // Updated for Windows Docker Desktop networking compatibility
  static const String ipfsGatewayUrl = 'http://10.0.0.2:3000'; // IPFS Gateway v2
  static const String preProxyUrl = 'http://10.0.0.2:3001';     // PRE Proxy Network
  static const String daoServiceUrl = 'http://10.0.0.2:3002';   // DAO Governance

  // Legacy production URLs (for future deployment)
  static const String prodIpfsGateway = 'https://ipfs.digitalvault.app';
  static const String prodApiBase = 'https://api.digitalvault.app';
  static const String pinataApiUrl = 'https://api.pinata.cloud';

  // IPFS Gateway endpoints (port 3000)
  static const String ipfsUpload = '/api/ipfs/upload/file';
  static const String ipfsUploadJson = '/api/ipfs/upload/json';
  static const String ipfsUploadMetadata = '/api/ipfs/upload/metadata';
  static const String ipfsRetrieve = '/api/ipfs/content';
  static const String ipfsContentInfo = '/api/ipfs/content';  // /cid/info
  static const String ipfsPinStatus = '/api/ipfs/pin/status';
  static const String ipfsPinList = '/api/ipfs/pin/list';
  static const String ipfsPinStats = '/api/ipfs/pin/stats';
  static const String ipfsHealth = '/api/ipfs/health';

  // PRE Proxy endpoints (port 3001)
  static const String preCapsuleStore = '/api/proxy/capsules';
  static const String preReencrypt = '/api/proxy/reencrypt';
  static const String preReencryptHistory = '/api/proxy/reencrypt/history';
  static const String preProxyHealth = '/api/proxy/health';

  // DAO Service endpoints (port 3002)
  static const String daoProposals = '/api/dao/proposals';
  static const String daoProposalsActive = '/api/dao/proposals/active';
  static const String daoVoting = '/api/dao/voting';
  static const String daoVotingPower = '/api/dao/voting/power';
  static const String daoVotingHistory = '/api/dao/voting/history';
  static const String daoTreasuryBalance = '/api/dao/treasury/balance';
  static const String daoTreasuryTransactions = '/api/dao/treasury/transactions';
  static const String daoHealth = '/api/dao/health';

  // Legacy endpoints (for compatibility)
  static const String contents = '/api/contents';
  static const String listings = '/api/listings';
  static const String transactions = '/api/transactions';
  static const String providers = '/api/providers';
  static const String analytics = '/api/analytics/overview';

  // Helper methods
  static String getIpfsContent(String cid) => '$ipfsRetrieve/$cid';
  static String getUserContents(String address) => '$contents?owner=$address';
  static String getUserTransactions(String address) => '$transactions/$address';
}
