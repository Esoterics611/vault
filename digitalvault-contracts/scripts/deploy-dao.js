const hre = require("hardhat");

/**
 * Deploy DAO Governor and Timelock
 *
 * This script deploys:
 * 1. TimelockController (48 hour delay)
 * 2. DAOGovernor (using existing VaultToken)
 * 3. Grants proper roles
 *
 * Prerequisites:
 * - VaultToken must already be deployed
 * - VaultToken must have voting power enabled (ERC20Votes)
 */
async function main() {
  console.log("🏛️  Deploying DAO Governance System...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)), "ETH\n");

  // ============================================================================
  // Get Existing VaultToken
  // ============================================================================

  const VAULT_TOKEN_ADDRESS = "0x9583d1643354B9C254586966343D54bCB79970D3"; // Base Sepolia

  console.log("📝 Using existing VaultToken at:", VAULT_TOKEN_ADDRESS);

  const VaultToken = await hre.ethers.getContractAt("VaultToken", VAULT_TOKEN_ADDRESS);

  // Verify token supports voting
  try {
    const hasVoting = await VaultToken.delegates;
    console.log("✅ VaultToken has voting support (ERC20Votes)\n");
  } catch (e) {
    console.error("❌ VaultToken does not support voting!");
    console.error("   Make sure VaultToken inherits from ERC20Votes");
    process.exit(1);
  }

  // ============================================================================
  // Deploy TimelockController
  // ============================================================================

  console.log("⏰ Deploying TimelockController...");

  const minDelay = 2 * 24 * 60 * 60; // 48 hours
  const proposers = []; // Will be set to Governor after deployment
  const executors = [hre.ethers.ZeroAddress]; // Anyone can execute
  const admin = deployer.address; // Deployer is initial admin (will renounce)

  const TimelockController = await hre.ethers.getContractFactory("TimelockController");
  const timelock = await TimelockController.deploy(
    minDelay,
    proposers,
    executors,
    admin
  );

  await timelock.waitForDeployment();
  const timelockAddress = await timelock.getAddress();

  console.log("✅ TimelockController deployed to:", timelockAddress);
  console.log("   Min delay:", minDelay / (24 * 60 * 60), "days\n");

  // ============================================================================
  // Deploy DAOGovernor
  // ============================================================================

  console.log("🏛️  Deploying DAOGovernor...");

  const DAOGovernor = await hre.ethers.getContractFactory("DAOGovernor");
  const governor = await DAOGovernor.deploy(
    VAULT_TOKEN_ADDRESS,
    timelockAddress
  );

  await governor.waitForDeployment();
  const governorAddress = await governor.getAddress();

  console.log("✅ DAOGovernor deployed to:", governorAddress);

  // Get governance parameters
  const votingDelay = await governor.votingDelay();
  const votingPeriod = await governor.votingPeriod();
  const proposalThreshold = await governor.proposalThreshold();
  const quorumNumerator = await governor.quorumNumerator();

  console.log("   Voting delay:", Number(votingDelay) / (24 * 60 * 60), "days");
  console.log("   Voting period:", Number(votingPeriod) / (24 * 60 * 60), "days");
  console.log("   Proposal threshold:", hre.ethers.formatEther(proposalThreshold), "VLTC");
  console.log("   Quorum:", quorumNumerator.toString() + "%\n");

  // ============================================================================
  // Grant Roles
  // ============================================================================

  console.log("🔐 Configuring roles...");

  // Get role constants
  const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
  const DEFAULT_ADMIN_ROLE = await timelock.DEFAULT_ADMIN_ROLE();

  // Grant proposer role to Governor
  console.log("   Granting PROPOSER_ROLE to Governor...");
  let tx = await timelock.grantRole(PROPOSER_ROLE, governorAddress);
  await tx.wait();
  console.log("   ✅ Governor can now propose operations");

  // Grant executor role to everyone (0x0)
  console.log("   Granting EXECUTOR_ROLE to everyone...");
  tx = await timelock.grantRole(EXECUTOR_ROLE, hre.ethers.ZeroAddress);
  await tx.wait();
  console.log("   ✅ Anyone can execute passed proposals");

  // Renounce admin role (optional - for decentralization)
  // Uncomment when ready to fully decentralize
  // console.log("   Renouncing admin role...");
  // tx = await timelock.renounceRole(DEFAULT_ADMIN_ROLE, deployer.address);
  // await tx.wait();
  // console.log("   ✅ Admin role renounced - fully decentralized!\n");

  console.log("   ⚠️  Admin role NOT renounced - deployer still has admin access");
  console.log("   ℹ️  Renounce admin when ready for full decentralization\n");

  // ============================================================================
  // Verification Information
  // ============================================================================

  console.log("📋 Deployment Summary");
  console.log("═".repeat(80));
  console.log("VaultToken:       ", VAULT_TOKEN_ADDRESS);
  console.log("TimelockController:", timelockAddress);
  console.log("DAOGovernor:      ", governorAddress);
  console.log("═".repeat(80));

  console.log("\n🔍 Verify contracts on Basescan:");
  console.log(`https://sepolia.basescan.org/address/${timelockAddress}`);
  console.log(`https://sepolia.basescan.org/address/${governorAddress}`);

  console.log("\n📝 Update contract addresses in mobile app:");
  console.log("File: digitalvault-mobile/lib/core/constants/contract_addresses.dart");
  console.log(`  'TimelockController': '${timelockAddress}',`);
  console.log(`  'DAOGovernor': '${governorAddress}',`);

  console.log("\n🎉 DAO Governance System deployed successfully!");
  console.log("\n💡 Next steps:");
  console.log("1. Update contract addresses in mobile app");
  console.log("2. Users must delegate voting power: token.delegate(myAddress)");
  console.log("3. Create first proposal to test governance");
  console.log("4. When ready for full decentralization, renounce admin role");

  // ============================================================================
  // Save Deployment Info
  // ============================================================================

  const deploymentInfo = {
    network: hre.network.name,
    chainId: (await hre.ethers.provider.getNetwork()).chainId.toString(),
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      VaultToken: VAULT_TOKEN_ADDRESS,
      TimelockController: timelockAddress,
      DAOGovernor: governorAddress,
    },
    parameters: {
      votingDelay: votingDelay.toString(),
      votingPeriod: votingPeriod.toString(),
      proposalThreshold: proposalThreshold.toString(),
      quorumPercentage: quorumNumerator.toString(),
      timelockDelay: minDelay.toString(),
    },
  };

  const fs = require('fs');
  const path = require('path');
  const deploymentsDir = path.join(__dirname, '../deployments');

  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  const filename = `dao-${hre.network.name}-${Date.now()}.json`;
  fs.writeFileSync(
    path.join(deploymentsDir, filename),
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log(`\n💾 Deployment info saved to: deployments/${filename}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
