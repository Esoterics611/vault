/// Smart contract addresses for different networks
class ContractAddresses {
  // Base Mainnet (chainId: 8453)
  static const Map<String, String> baseMainnet = {
    'VaultToken': '0x0000000000000000000000000000000000000000',
    'ContentRegistry': '0x0000000000000000000000000000000000000000',
    'Marketplace': '0x0000000000000000000000000000000000000000',
    'StorageProvider': '0x0000000000000000000000000000000000000000',
    'RewardDistributor': '0x0000000000000000000000000000000000000000',
    'DAOGovernor': '0x0000000000000000000000000000000000000000',
  };

  // Base Sepolia Testnet (chainId: 84532) - Week 7 Deployment
  static const Map<String, String> baseSepolia = {
    'VaultToken': '0x9583d1643354B9C254586966343D54bCB79970D3',
    'ContentRegistry': '0xd469e2AA709bb01ab409eBb762c655FC641C41f0',
    'ReKeyRegistry': '0xBC835256b0D08DFeD09c7cE3B07eD945C6e243aA',
    'Marketplace': '0xC763Ea95626100C0128c0d28E6DdED873eba91c5',
    // Week 20 - DAO Governance deployed
    'DAOGovernor': '0xc0cE9E7376c401FB74264D0312afc7d91B191050',
    'TimelockController': '0xa58E06916eDf2239F5518ed41409075d3937365C',
    // Not yet deployed on Base Sepolia:
    'StorageProvider': '0x0000000000000000000000000000000000000000',
    'RewardDistributor': '0x0000000000000000000000000000000000000000',
  };

  // Local Hardhat (chainId: 31337)
  static const Map<String, String> localhost = {
    'VaultToken': '0xa513E6E4b8f2a923D98304ec87F64353C4D5C853',
    'ContentRegistry': '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6',
    'Marketplace': '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318',
    'StorageProvider': '0x610178dA211FEF7D417bC0e6FeD39F05609AD788',
    'RewardDistributor': '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e',
    'DAOGovernor': '0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82',
    'ContentAccessControl': '0x9A676e781A523b5d0C0e43731313A708CB607508',
    'SocialVerification': '0x0B306BF915C4d645ff596e518fAf3F9669b97016',
    'PresaleContract': '0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1',
    'AirdropDistributor': '0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE',
  };

  static Map<String, String> getAddresses(int chainId) {
    switch (chainId) {
      case 8453:
        return baseMainnet;
      case 84532:
        return baseSepolia;
      case 31337:
        return localhost;
      default:
        return localhost;
    }
  }

  // Convenience getters for Base Sepolia (most commonly used)
  static String get marketplace => baseSepolia['Marketplace']!;
  static String get vaultToken => baseSepolia['VaultToken']!;
  static String get contentRegistry => baseSepolia['ContentRegistry']!;
  static String get reKeyRegistry => baseSepolia['ReKeyRegistry']!;
  static String get daoGovernor => baseSepolia['DAOGovernor']!;
  static String get timelockController => baseSepolia['TimelockController']!;
}
