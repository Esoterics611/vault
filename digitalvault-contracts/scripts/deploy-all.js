const hre = require("hardhat");

/**
 * Deploy all DigitalVault contracts in the correct order
 *
 * Deployment order:
 * 1. VaultToken (ERC20)
 * 2. ContentRegistry
 * 3. ReKeyRegistry (NEW - Week 2)
 * 4. Marketplace (depends on ContentRegistry, ReKeyRegistry, VaultToken)
 * 5. DAOGovernor (depends on VaultToken)
 * 6. RewardDistributor (depends on VaultToken)
 * 7. StakingContract (depends on VaultToken)
 * 8. RoyaltyManager (depends on ContentRegistry)
 * 9. DisputeResolution (depends on Marketplace)
 * 10. IdentityVerification
 * 11. EmergencyPause (depends on all contracts)
 *
 * Usage:
 * - Local: npx hardhat run scripts/deploy-all.js
 * - Testnet: npx hardhat run scripts/deploy-all.js --network baseSepolia
 */

async function main() {
  console.log("\n🚀 Starting full DigitalVault deployment...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "ETH\n");

  const deployedContracts = {};

  // 1. Deploy VaultToken
  console.log("1️⃣  Deploying VaultToken...");
  const VaultToken = await hre.ethers.getContractFactory("VaultToken");
  const vaultToken = await VaultToken.deploy(deployer.address); // OpenZeppelin v5 - requires initialOwner
  await vaultToken.waitForDeployment();
  deployedContracts.VaultToken = await vaultToken.getAddress();
  console.log("   ✅ VaultToken deployed:", deployedContracts.VaultToken, "\n");

  // 2. Deploy ContentRegistry
  console.log("2️⃣  Deploying ContentRegistry...");
  const ContentRegistry = await hre.ethers.getContractFactory("ContentRegistry");
  const contentRegistry = await ContentRegistry.deploy(deployer.address); // Week 3 - OpenZeppelin v5
  await contentRegistry.waitForDeployment();
  deployedContracts.ContentRegistry = await contentRegistry.getAddress();
  console.log("   ✅ ContentRegistry deployed:", deployedContracts.ContentRegistry, "\n");

  // 3. Deploy ReKeyRegistry (NEW)
  console.log("3️⃣  Deploying ReKeyRegistry...");
  const ReKeyRegistry = await hre.ethers.getContractFactory("ReKeyRegistry");
  const reKeyRegistry = await ReKeyRegistry.deploy();
  await reKeyRegistry.waitForDeployment();
  deployedContracts.ReKeyRegistry = await reKeyRegistry.getAddress();
  console.log("   ✅ ReKeyRegistry deployed:", deployedContracts.ReKeyRegistry, "\n");

  // 4. Deploy Marketplace
  console.log("4️⃣  Deploying Marketplace...");
  const Marketplace = await hre.ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    deployer.address,                        // Week 4 - OpenZeppelin v5 initialOwner
    deployedContracts.VaultToken,
    deployedContracts.ContentRegistry,
    deployedContracts.ReKeyRegistry,         // Week 4 - PRE integration
    deployer.address                          // feeCollector (using deployer for now)
  );
  await marketplace.waitForDeployment();
  deployedContracts.Marketplace = await marketplace.getAddress();
  console.log("   ✅ Marketplace deployed:", deployedContracts.Marketplace, "\n");

  // Week 4 - Setup authorization for PRE purchases
  console.log("   🔐 Setting up authorization...");
  await contentRegistry.setTrustedMarketplace(deployedContracts.Marketplace, true);
  console.log("      ✓ ContentRegistry authorized Marketplace");
  await reKeyRegistry.setTrustedMarketplace(deployedContracts.Marketplace, true);
  console.log("      ✓ ReKeyRegistry authorized Marketplace\n");

  // 5. Deploy DAOGovernor
  console.log("5️⃣  Deploying DAOGovernor...");
  const DAOGovernor = await hre.ethers.getContractFactory("DAOGovernor");
  const daoGovernor = await DAOGovernor.deploy(deployedContracts.VaultToken);
  await daoGovernor.waitForDeployment();
  deployedContracts.DAOGovernor = await daoGovernor.getAddress();
  console.log("   ✅ DAOGovernor deployed:", deployedContracts.DAOGovernor, "\n");

  // 6. Deploy RewardDistributor
  console.log("6️⃣  Deploying RewardDistributor...");
  const RewardDistributor = await hre.ethers.getContractFactory("RewardDistributor");
  const rewardDistributor = await RewardDistributor.deploy(deployedContracts.VaultToken);
  await rewardDistributor.waitForDeployment();
  deployedContracts.RewardDistributor = await rewardDistributor.getAddress();
  console.log("   ✅ RewardDistributor deployed:", deployedContracts.RewardDistributor, "\n");

  // 7. Deploy StakingContract
  console.log("7️⃣  Deploying StakingContract...");
  const StakingContract = await hre.ethers.getContractFactory("StakingContract");
  const stakingContract = await StakingContract.deploy(deployedContracts.VaultToken);
  await stakingContract.waitForDeployment();
  deployedContracts.StakingContract = await stakingContract.getAddress();
  console.log("   ✅ StakingContract deployed:", deployedContracts.StakingContract, "\n");

  // 8. Deploy RoyaltyManager
  console.log("8️⃣  Deploying RoyaltyManager...");
  const RoyaltyManager = await hre.ethers.getContractFactory("RoyaltyManager");
  const royaltyManager = await RoyaltyManager.deploy(deployedContracts.ContentRegistry);
  await royaltyManager.waitForDeployment();
  deployedContracts.RoyaltyManager = await royaltyManager.getAddress();
  console.log("   ✅ RoyaltyManager deployed:", deployedContracts.RoyaltyManager, "\n");

  // 9. Deploy DisputeResolution
  console.log("9️⃣  Deploying DisputeResolution...");
  const DisputeResolution = await hre.ethers.getContractFactory("DisputeResolution");
  const disputeResolution = await DisputeResolution.deploy(deployedContracts.Marketplace);
  await disputeResolution.waitForDeployment();
  deployedContracts.DisputeResolution = await disputeResolution.getAddress();
  console.log("   ✅ DisputeResolution deployed:", deployedContracts.DisputeResolution, "\n");

  // 10. Deploy IdentityVerification
  console.log("🔟 Deploying IdentityVerification...");
  const IdentityVerification = await hre.ethers.getContractFactory("IdentityVerification");
  const identityVerification = await IdentityVerification.deploy();
  await identityVerification.waitForDeployment();
  deployedContracts.IdentityVerification = await identityVerification.getAddress();
  console.log("   ✅ IdentityVerification deployed:", deployedContracts.IdentityVerification, "\n");

  // 11. Deploy EmergencyPause
  console.log("1️⃣1️⃣  Deploying EmergencyPause...");
  const EmergencyPause = await hre.ethers.getContractFactory("EmergencyPause");
  const emergencyPause = await EmergencyPause.deploy();
  await emergencyPause.waitForDeployment();
  deployedContracts.EmergencyPause = await emergencyPause.getAddress();
  console.log("   ✅ EmergencyPause deployed:", deployedContracts.EmergencyPause, "\n");

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    deployer: deployer.address,
    blockNumber: await hre.ethers.provider.getBlockNumber(),
    timestamp: new Date().toISOString(),
    contracts: deployedContracts
  };

  console.log("\n📄 Deployment Summary:");
  console.log("════════════════════════════════════════════════════════════════");
  Object.entries(deployedContracts).forEach(([name, address]) => {
    console.log(`   ${name.padEnd(25)} ${address}`);
  });
  console.log("════════════════════════════════════════════════════════════════\n");

  // Save to file
  const fs = require("fs");
  const path = require("path");
  const outputDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const outputFile = path.join(
    outputDir,
    `${hre.network.name}-${Date.now()}.json`
  );
  fs.writeFileSync(outputFile, JSON.stringify(deploymentInfo, null, 2));
  console.log("💾 Deployment info saved to:", outputFile, "\n");

  // Instructions for verification
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("🔗 To verify all contracts on BaseScan, run:");
    Object.entries(deployedContracts).forEach(([name, address]) => {
      console.log(`   npx hardhat verify --network ${hre.network.name} ${address}`);
    });
    console.log("");
  }

  console.log("✨ Full deployment complete!\n");

  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
