const hre = require("hardhat");

/**
 * Deploy script for ReKeyRegistry contract
 *
 * Usage:
 * - Local: npx hardhat run scripts/deploy-rekey-registry.js
 * - Testnet: npx hardhat run scripts/deploy-rekey-registry.js --network baseSepolia
 * - Mainnet: npx hardhat run scripts/deploy-rekey-registry.js --network base
 */

async function main() {
  console.log("\n🚀 Starting ReKeyRegistry deployment...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "ETH\n");

  // Deploy ReKeyRegistry
  console.log("📦 Deploying ReKeyRegistry...");
  const ReKeyRegistry = await hre.ethers.getContractFactory("ReKeyRegistry");
  const reKeyRegistry = await ReKeyRegistry.deploy();

  await reKeyRegistry.waitForDeployment();
  const address = await reKeyRegistry.getAddress();

  console.log("✅ ReKeyRegistry deployed to:", address);

  // Verify deployment
  console.log("\n🔍 Verifying deployment...");
  const owner = await reKeyRegistry.owner();
  const defaultExpiration = await reKeyRegistry.DEFAULT_EXPIRATION();

  console.log("   Owner:", owner);
  console.log("   Default Expiration:", defaultExpiration.toString(), "seconds (7 days)");

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    contract: "ReKeyRegistry",
    address: address,
    deployer: deployer.address,
    blockNumber: await hre.ethers.provider.getBlockNumber(),
    timestamp: new Date().toISOString(),
    owner: owner,
    defaultExpiration: defaultExpiration.toString()
  };

  console.log("\n📄 Deployment Summary:");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  // Instructions for verification on block explorer
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("\n🔗 To verify on BaseScan:");
    console.log(`   npx hardhat verify --network ${hre.network.name} ${address}`);
  }

  console.log("\n✨ Deployment complete!\n");

  return deploymentInfo;
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
