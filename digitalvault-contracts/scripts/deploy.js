const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  // Deploy VaultToken
  console.log("\n1. Deploying VaultToken...");
  const VaultToken = await hre.ethers.getContractFactory("VaultToken");
  const vaultToken = await VaultToken.deploy(deployer.address);
  await vaultToken.waitForDeployment();
  const vaultTokenAddress = await vaultToken.getAddress();
  console.log("VaultToken deployed to:", vaultTokenAddress);

  // Deploy ContentRegistry
  console.log("\n2. Deploying ContentRegistry...");
  const ContentRegistry = await hre.ethers.getContractFactory("ContentRegistry");
  const contentRegistry = await ContentRegistry.deploy(deployer.address);
  await contentRegistry.waitForDeployment();
  const contentRegistryAddress = await contentRegistry.getAddress();
  console.log("ContentRegistry deployed to:", contentRegistryAddress);

  // Deploy Marketplace
  console.log("\n3. Deploying Marketplace...");
  const Marketplace = await hre.ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    deployer.address,
    vaultTokenAddress,
    contentRegistryAddress,
    deployer.address // fee collector (use treasury address in production)
  );
  await marketplace.waitForDeployment();
  const marketplaceAddress = await marketplace.getAddress();
  console.log("Marketplace deployed to:", marketplaceAddress);

  // Deploy StorageProvider
  console.log("\n4. Deploying StorageProvider...");
  const StorageProvider = await hre.ethers.getContractFactory("StorageProvider");
  const storageProvider = await StorageProvider.deploy(deployer.address, vaultTokenAddress);
  await storageProvider.waitForDeployment();
  const storageProviderAddress = await storageProvider.getAddress();
  console.log("StorageProvider deployed to:", storageProviderAddress);

  // Deploy RewardDistributor
  console.log("\n5. Deploying RewardDistributor...");
  const RewardDistributor = await hre.ethers.getContractFactory("RewardDistributor");
  const rewardDistributor = await RewardDistributor.deploy(deployer.address, vaultTokenAddress);
  await rewardDistributor.waitForDeployment();
  const rewardDistributorAddress = await rewardDistributor.getAddress();
  console.log("RewardDistributor deployed to:", rewardDistributorAddress);

  // Deploy TimelockController for DAO
  console.log("\n6. Deploying TimelockController...");
  const TimelockController = await hre.ethers.getContractFactory("TimelockController");
  const timelock = await TimelockController.deploy(
    2 * 24 * 60 * 60, // 48 hours delay
    [], // proposers (will be set to governor)
    [], // executors (will be set to governor)
    deployer.address // admin
  );
  await timelock.waitForDeployment();
  const timelockAddress = await timelock.getAddress();
  console.log("TimelockController deployed to:", timelockAddress);

  // Deploy DAOGovernor
  console.log("\n7. Deploying DAOGovernor...");
  const DAOGovernor = await hre.ethers.getContractFactory("DAOGovernor");
  const daoGovernor = await DAOGovernor.deploy(vaultTokenAddress, timelockAddress);
  await daoGovernor.waitForDeployment();
  const daoGovernorAddress = await daoGovernor.getAddress();
  console.log("DAOGovernor deployed to:", daoGovernorAddress);

  // Deploy ContentAccessControl
  console.log("\n8. Deploying ContentAccessControl...");
  const ContentAccessControl = await hre.ethers.getContractFactory("ContentAccessControl");
  const contentAccessControl = await ContentAccessControl.deploy(deployer.address);
  await contentAccessControl.waitForDeployment();
  const contentAccessControlAddress = await contentAccessControl.getAddress();
  console.log("ContentAccessControl deployed to:", contentAccessControlAddress);

  // Deploy SocialVerification
  console.log("\n9. Deploying SocialVerification...");
  const SocialVerification = await hre.ethers.getContractFactory("SocialVerification");
  const socialVerification = await SocialVerification.deploy(deployer.address);
  await socialVerification.waitForDeployment();
  const socialVerificationAddress = await socialVerification.getAddress();
  console.log("SocialVerification deployed to:", socialVerificationAddress);

  // Deploy PresaleContract
  console.log("\n10. Deploying PresaleContract...");
  const PresaleContract = await hre.ethers.getContractFactory("PresaleContract");
  const presaleContract = await PresaleContract.deploy(
    deployer.address,
    vaultTokenAddress,
    deployer.address // funds collector
  );
  await presaleContract.waitForDeployment();
  const presaleContractAddress = await presaleContract.getAddress();
  console.log("PresaleContract deployed to:", presaleContractAddress);

  // Deploy AirdropDistributor
  console.log("\n11. Deploying AirdropDistributor...");
  const AirdropDistributor = await hre.ethers.getContractFactory("AirdropDistributor");
  const airdropDistributor = await AirdropDistributor.deploy(deployer.address, vaultTokenAddress);
  await airdropDistributor.waitForDeployment();
  const airdropDistributorAddress = await airdropDistributor.getAddress();
  console.log("AirdropDistributor deployed to:", airdropDistributorAddress);

  // Set contract addresses in VaultToken
  console.log("\n12. Setting allocations in VaultToken...");
  await vaultToken.setPresaleContract(presaleContractAddress);
  console.log("  - Presale allocation set");

  await vaultToken.setAirdropContract(airdropDistributorAddress);
  console.log("  - Airdrop allocation set");

  await vaultToken.setRewardDistributor(rewardDistributorAddress);
  console.log("  - Reward distributor allocation set");

  await vaultToken.setTreasury(deployer.address); // Use proper treasury in production
  console.log("  - Treasury allocation set");

  // Set storage provider contract in Marketplace
  console.log("\n13. Setting storage provider in Marketplace...");
  await marketplace.setStorageProviderContract(storageProviderAddress);
  console.log("  - Storage provider contract set");

  // Setup timelock roles for governance
  console.log("\n14. Setting up timelock roles...");
  const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
  const CANCELLER_ROLE = await timelock.CANCELLER_ROLE();

  await timelock.grantRole(PROPOSER_ROLE, daoGovernorAddress);
  await timelock.grantRole(EXECUTOR_ROLE, daoGovernorAddress);
  console.log("  - Governor roles granted to timelock");

  console.log("\n✅ Deployment completed successfully!");
  console.log("\n📝 Contract Addresses:");
  console.log("================================");
  console.log("VaultToken:          ", vaultTokenAddress);
  console.log("ContentRegistry:     ", contentRegistryAddress);
  console.log("Marketplace:         ", marketplaceAddress);
  console.log("StorageProvider:     ", storageProviderAddress);
  console.log("RewardDistributor:   ", rewardDistributorAddress);
  console.log("TimelockController:  ", timelockAddress);
  console.log("DAOGovernor:         ", daoGovernorAddress);
  console.log("ContentAccessControl:", contentAccessControlAddress);
  console.log("SocialVerification:  ", socialVerificationAddress);
  console.log("PresaleContract:     ", presaleContractAddress);
  console.log("AirdropDistributor:  ", airdropDistributorAddress);
  console.log("================================");

  // Save addresses to file
  const fs = require("fs");
  const addresses = {
    VaultToken: vaultTokenAddress,
    ContentRegistry: contentRegistryAddress,
    Marketplace: marketplaceAddress,
    StorageProvider: storageProviderAddress,
    RewardDistributor: rewardDistributorAddress,
    TimelockController: timelockAddress,
    DAOGovernor: daoGovernorAddress,
    ContentAccessControl: contentAccessControlAddress,
    SocialVerification: socialVerificationAddress,
    PresaleContract: presaleContractAddress,
    AirdropDistributor: airdropDistributorAddress,
  };

  fs.writeFileSync(
    "deployments.json",
    JSON.stringify(addresses, null, 2)
  );
  console.log("\n📄 Addresses saved to deployments.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
