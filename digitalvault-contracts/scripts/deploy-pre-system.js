const hre = require("hardhat");

/**
 * Deploy PRE System - Week 4 Complete Integration
 *
 * Deploys the 3 core PRE contracts with authorization setup:
 * 1. VaultToken (ERC20)
 * 2. ContentRegistry (with PRE support)
 * 3. ReKeyRegistry (grant management)
 * 4. Marketplace (PRE integration)
 *
 * Usage:
 * - Local: npx hardhat run scripts/deploy-pre-system.js
 * - Testnet: npx hardhat run scripts/deploy-pre-system.js --network baseSepolia
 *
 * @author DigitalVault Team
 * @version Week 4 - PRE Integration Complete
 */

async function main() {
  console.log("\n🔐 Deploying PRE System (Week 4 Complete)...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "ETH\n");

  const deployedContracts = {};
  const transactions = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Deploy VaultToken
  // ═══════════════════════════════════════════════════════════════════════════
  console.log("1️⃣  Deploying VaultToken (ERC20)...");
  const VaultToken = await hre.ethers.getContractFactory("VaultToken");
  const vaultToken = await VaultToken.deploy(deployer.address);
  await vaultToken.waitForDeployment();
  deployedContracts.VaultToken = await vaultToken.getAddress();
  transactions.push({
    contract: "VaultToken",
    tx: vaultToken.deploymentTransaction().hash
  });
  console.log("   ✅ VaultToken deployed:", deployedContracts.VaultToken);
  console.log("   📦 Total Supply: 1,000,000 VLTC");
  console.log("");

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Deploy ContentRegistry
  // ═══════════════════════════════════════════════════════════════════════════
  console.log("2️⃣  Deploying ContentRegistry (Week 3 - PRE Support)...");
  const ContentRegistry = await hre.ethers.getContractFactory("ContentRegistry");
  const contentRegistry = await ContentRegistry.deploy(deployer.address);
  await contentRegistry.waitForDeployment();
  deployedContracts.ContentRegistry = await contentRegistry.getAddress();
  transactions.push({
    contract: "ContentRegistry",
    tx: contentRegistry.deploymentTransaction().hash
  });
  console.log("   ✅ ContentRegistry deployed:", deployedContracts.ContentRegistry);
  console.log("   ✨ Features: Legacy + PRE content registration");
  console.log("");

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Deploy ReKeyRegistry
  // ═══════════════════════════════════════════════════════════════════════════
  console.log("3️⃣  Deploying ReKeyRegistry (Week 2 - Grant Management)...");
  const ReKeyRegistry = await hre.ethers.getContractFactory("ReKeyRegistry");
  const reKeyRegistry = await ReKeyRegistry.deploy();
  await reKeyRegistry.waitForDeployment();
  deployedContracts.ReKeyRegistry = await reKeyRegistry.getAddress();
  transactions.push({
    contract: "ReKeyRegistry",
    tx: reKeyRegistry.deploymentTransaction().hash
  });
  console.log("   ✅ ReKeyRegistry deployed:", deployedContracts.ReKeyRegistry);
  console.log("   ✨ Features: Grant creation, verification, expiration (7 days)");
  console.log("");

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Deploy Marketplace
  // ═══════════════════════════════════════════════════════════════════════════
  console.log("4️⃣  Deploying Marketplace (Week 4 - PRE Integration)...");
  const Marketplace = await hre.ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    deployer.address,                     // initialOwner
    deployedContracts.VaultToken,         // payment token
    deployedContracts.ContentRegistry,    // content management
    deployedContracts.ReKeyRegistry,      // grant management
    deployer.address                       // feeCollector
  );
  await marketplace.waitForDeployment();
  deployedContracts.Marketplace = await marketplace.getAddress();
  transactions.push({
    contract: "Marketplace",
    tx: marketplace.deploymentTransaction().hash
  });
  console.log("   ✅ Marketplace deployed:", deployedContracts.Marketplace);
  console.log("   ✨ Features: Legacy + PRE purchases, royalties, escrow");
  console.log("");

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Setup Authorization (Week 4 - CRITICAL!)
  // ═══════════════════════════════════════════════════════════════════════════
  console.log("🔐 Setting up authorization (Week 4)...");
  console.log("");

  console.log("   📝 Authorizing Marketplace in ContentRegistry...");
  const tx1 = await contentRegistry.setTrustedMarketplace(deployedContracts.Marketplace, true);
  await tx1.wait();
  transactions.push({
    contract: "ContentRegistry",
    action: "setTrustedMarketplace",
    tx: tx1.hash
  });
  console.log("      ✅ Marketplace can now transfer content on behalf of owners");
  console.log("");

  console.log("   📝 Authorizing Marketplace in ReKeyRegistry...");
  const tx2 = await reKeyRegistry.setTrustedMarketplace(deployedContracts.Marketplace, true);
  await tx2.wait();
  transactions.push({
    contract: "ReKeyRegistry",
    action: "setTrustedMarketplace",
    tx: tx2.hash
  });
  console.log("      ✅ Marketplace can now mark grants as used");
  console.log("");

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Verify Deployment
  // ═══════════════════════════════════════════════════════════════════════════
  console.log("🔍 Verifying deployment...");
  console.log("");

  // Verify ContentRegistry authorization
  const isContentRegistryTrusted = await contentRegistry.isTrustedMarketplace(deployedContracts.Marketplace);
  console.log("   ContentRegistry → Marketplace trusted:", isContentRegistryTrusted ? "✅ YES" : "❌ NO");

  // Verify ReKeyRegistry authorization
  const isReKeyRegistryTrusted = await reKeyRegistry.isTrustedMarketplace(deployedContracts.Marketplace);
  console.log("   ReKeyRegistry → Marketplace trusted:", isReKeyRegistryTrusted ? "✅ YES" : "❌ NO");

  // Verify Marketplace configuration
  const marketplaceVaultToken = await marketplace.vaultToken();
  const marketplaceContentRegistry = await marketplace.contentRegistry();
  const marketplaceReKeyRegistry = await marketplace.reKeyRegistry();
  console.log("   Marketplace → VaultToken:", marketplaceVaultToken === deployedContracts.VaultToken ? "✅ CORRECT" : "❌ WRONG");
  console.log("   Marketplace → ContentRegistry:", marketplaceContentRegistry === deployedContracts.ContentRegistry ? "✅ CORRECT" : "❌ WRONG");
  console.log("   Marketplace → ReKeyRegistry:", marketplaceReKeyRegistry === deployedContracts.ReKeyRegistry ? "✅ CORRECT" : "❌ WRONG");
  console.log("");

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Save Deployment Info
  // ═══════════════════════════════════════════════════════════════════════════
  const deploymentInfo = {
    network: hre.network.name,
    deployer: deployer.address,
    blockNumber: await hre.ethers.provider.getBlockNumber(),
    timestamp: new Date().toISOString(),
    version: "Week 4 - PRE Integration Complete",
    contracts: deployedContracts,
    transactions: transactions,
    configuration: {
      authorizationsSet: true,
      contentRegistryTrustsMarketplace: isContentRegistryTrusted,
      reKeyRegistryTrustsMarketplace: isReKeyRegistryTrusted
    }
  };

  console.log("═══════════════════════════════════════════════════════════════════");
  console.log("📄 PRE SYSTEM DEPLOYMENT SUMMARY");
  console.log("═══════════════════════════════════════════════════════════════════");
  console.log("");
  console.log("Network:", hre.network.name.toUpperCase());
  console.log("Deployer:", deployer.address);
  console.log("Block:", deploymentInfo.blockNumber);
  console.log("");
  console.log("═══════════════════════════════════════════════════════════════════");
  console.log("DEPLOYED CONTRACTS:");
  console.log("═══════════════════════════════════════════════════════════════════");
  Object.entries(deployedContracts).forEach(([name, address]) => {
    console.log(`   ${name.padEnd(20)} ${address}`);
  });
  console.log("═══════════════════════════════════════════════════════════════════");
  console.log("");

  // Save to file
  const fs = require("fs");
  const path = require("path");
  const outputDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const outputFile = path.join(
    outputDir,
    `pre-system-${hre.network.name}-${Date.now()}.json`
  );
  fs.writeFileSync(outputFile, JSON.stringify(deploymentInfo, null, 2));
  console.log("💾 Deployment info saved to:", outputFile);
  console.log("");

  // Verification instructions
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("═══════════════════════════════════════════════════════════════════");
    console.log("🔗 VERIFY CONTRACTS ON BASESCAN:");
    console.log("═══════════════════════════════════════════════════════════════════");
    console.log("");
    console.log(`npx hardhat verify --network ${hre.network.name} ${deployedContracts.VaultToken} ${deployer.address}`);
    console.log(`npx hardhat verify --network ${hre.network.name} ${deployedContracts.ContentRegistry} ${deployer.address}`);
    console.log(`npx hardhat verify --network ${hre.network.name} ${deployedContracts.ReKeyRegistry}`);
    console.log(`npx hardhat verify --network ${hre.network.name} ${deployedContracts.Marketplace} ${deployer.address} ${deployedContracts.VaultToken} ${deployedContracts.ContentRegistry} ${deployedContracts.ReKeyRegistry} ${deployer.address}`);
    console.log("");
    console.log("═══════════════════════════════════════════════════════════════════");
    console.log("");
  }

  console.log("✨ PRE System deployment complete!");
  console.log("");
  console.log("🎯 NEXT STEPS:");
  console.log("   1. Test the system with test/Marketplace.test.js");
  console.log("   2. Register test content with PRE");
  console.log("   3. Create marketplace listings");
  console.log("   4. Test PRE purchases end-to-end");
  console.log("");

  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
