const hre = require("hardhat");
const fs = require("fs");

/**
 * Wallet utility functions for DigitalVault
 *
 * Usage:
 *   npx hardhat run scripts/wallet-utils.js --network localhost
 *
 * Or use individual functions in Hardhat console:
 *   const utils = require('./scripts/wallet-utils.js');
 *   await utils.createWallet();
 */

async function createWallet() {
  console.log("=== Creating New Wallet ===\n");

  const wallet = hre.ethers.Wallet.createRandom();

  console.log("🎉 New wallet created!\n");
  console.log("Address:     ", wallet.address);
  console.log("Private Key: ", wallet.privateKey);
  console.log("\n🔐 Mnemonic (12 words - WRITE THIS DOWN!):");
  console.log(wallet.mnemonic.phrase);
  console.log("\n⚠️  Keep your private key and mnemonic SECRET!");
  console.log("⚠️  Anyone with these can control your funds!\n");

  return wallet;
}

async function fundWallet(targetAddress, ethAmount = "1.0") {
  console.log(`=== Funding Wallet ===\n`);

  const [deployer] = await hre.ethers.getSigners();

  console.log("From:  ", deployer.address);
  console.log("To:    ", targetAddress);
  console.log("Amount:", ethAmount, "ETH\n");

  const tx = await deployer.sendTransaction({
    to: targetAddress,
    value: hre.ethers.parseEther(ethAmount)
  });

  console.log("Transaction:", tx.hash);
  await tx.wait();
  console.log("✅ Funded!\n");

  return tx;
}

async function checkBalance(address) {
  console.log(`=== Checking Balance for ${address} ===\n`);

  // ETH balance
  const ethBalance = await hre.ethers.provider.getBalance(address);
  console.log("ETH Balance:  ", hre.ethers.formatEther(ethBalance), "ETH");

  // VAULT token balance
  const deployments = JSON.parse(fs.readFileSync("deployments.json", "utf8"));
  const token = await hre.ethers.getContractAt("VaultToken", deployments.VaultToken);
  const vaultBalance = await token.balanceOf(address);
  console.log("VAULT Balance:", hre.ethers.formatEther(vaultBalance), "VLTC");

  // Transaction count (nonce)
  const txCount = await hre.ethers.provider.getTransactionCount(address);
  console.log("Transactions: ", txCount);

  // Content owned
  const registry = await hre.ethers.getContractAt("ContentRegistry", deployments.ContentRegistry);
  const creatorContents = await registry.getCreatorContents(address);
  const ownerContents = await registry.getOwnerContents(address);
  console.log("Content Created:", creatorContents.length);
  console.log("Content Owned:  ", ownerContents.length);

  console.log();
  return {
    eth: ethBalance,
    vault: vaultBalance,
    txCount,
    contentCreated: creatorContents,
    contentOwned: ownerContents
  };
}

async function transferETH(toAddress, amount) {
  console.log(`=== Transferring ${amount} ETH ===\n`);

  const [signer] = await hre.ethers.getSigners();

  console.log("From:", signer.address);
  console.log("To:  ", toAddress);

  const tx = await signer.sendTransaction({
    to: toAddress,
    value: hre.ethers.parseEther(amount)
  });

  console.log("Transaction:", tx.hash);
  await tx.wait();
  console.log("✅ Transfer complete!\n");

  return tx;
}

async function transferVAULT(toAddress, amount) {
  console.log(`=== Transferring ${amount} VLTC ===\n`);

  const deployments = JSON.parse(fs.readFileSync("deployments.json", "utf8"));
  const token = await hre.ethers.getContractAt("VaultToken", deployments.VaultToken);

  const [signer] = await hre.ethers.getSigners();
  console.log("From:", signer.address);
  console.log("To:  ", toAddress);

  const tx = await token.transfer(toAddress, hre.ethers.parseEther(amount));

  console.log("Transaction:", tx.hash);
  await tx.wait();
  console.log("✅ Transfer complete!\n");

  return tx;
}

async function importWallet(privateKey) {
  console.log("=== Importing Wallet ===\n");

  // Ensure 0x prefix
  if (!privateKey.startsWith('0x')) {
    privateKey = '0x' + privateKey;
  }

  const wallet = new hre.ethers.Wallet(privateKey, hre.ethers.provider);

  console.log("✅ Wallet imported!");
  console.log("Address:", wallet.address);
  console.log();

  await checkBalance(wallet.address);

  return wallet;
}

async function importFromMnemonic(mnemonic, index = 0) {
  console.log("=== Restoring from Mnemonic ===\n");

  const wallet = hre.ethers.Wallet.fromPhrase(mnemonic, hre.ethers.provider);

  console.log("✅ Wallet restored!");
  console.log("Address:", wallet.address);
  console.log("Index:  ", index);
  console.log();

  await checkBalance(wallet.address);

  return wallet;
}

async function listAllAccounts() {
  console.log("=== All Available Accounts ===\n");

  const accounts = await hre.ethers.getSigners();

  for (let i = 0; i < accounts.length; i++) {
    const account = accounts[i];
    const balance = await hre.ethers.provider.getBalance(account.address);
    console.log(`Account #${i}:`);
    console.log(`  Address: ${account.address}`);
    console.log(`  Balance: ${hre.ethers.formatEther(balance)} ETH\n`);
  }

  return accounts;
}

async function getContentDetails(contentId) {
  console.log(`=== Content #${contentId} Details ===\n`);

  const deployments = JSON.parse(fs.readFileSync("deployments.json", "utf8"));
  const registry = await hre.ethers.getContractAt("ContentRegistry", deployments.ContentRegistry);

  const content = await registry.getContentInfo(contentId);

  const contentTypes = ["POETRY", "JOURNAL", "PHOTO", "VIDEO"];
  const accessModels = ["PRIVATE", "PREVIEW_ALLOWED", "PAY_PER_ACCESS", "FOR_SALE"];

  console.log("Owner:       ", content.owner);
  console.log("Creator:     ", content.creator);
  console.log("Content Type:", contentTypes[content.contentType]);
  console.log("Access Model:", accessModels[content.accessModel]);
  console.log("File Size:   ", content.fileSize.toString(), "bytes");
  console.log("View Count:  ", content.viewCount.toString());
  console.log("Created At:  ", new Date(Number(content.createdAt) * 1000).toLocaleString());
  console.log("Active:      ", content.isActive);
  console.log();

  return content;
}

// Main function for direct execution
async function main() {
  console.log("╔════════════════════════════════════════╗");
  console.log("║   DigitalVault Wallet Utilities       ║");
  console.log("╚════════════════════════════════════════╝\n");

  // Get command from environment variable for Hardhat
  const command = process.env.CMD;
  const arg1 = process.env.ARG1;
  const arg2 = process.env.ARG2;

  if (!command) {
    console.log("Available commands:");
    console.log("  create          - Create new wallet");
    console.log("  list            - List all accounts");
    console.log("  balance <addr>  - Check address balance");
    console.log("  fund <addr>     - Fund address with 1 ETH");
    console.log("  content <id>    - Get content details");
    console.log("\nExample (Windows):");
    console.log("  set CMD=create && npx hardhat run scripts/wallet-utils.js --network localhost");
    console.log("  set CMD=list && npx hardhat run scripts/wallet-utils.js --network localhost");
    console.log("  set CMD=balance && set ARG1=0xADDRESS && npx hardhat run scripts/wallet-utils.js --network localhost");
    console.log("\nBetter: Use in Hardhat console:");
    console.log("  npx hardhat console --network localhost");
    console.log("  const utils = require('./scripts/wallet-utils.js');");
    console.log("  await utils.createWallet();");
    console.log("  await utils.listAllAccounts();");
    return;
  }

  switch (command) {
    case "create":
      await createWallet();
      break;

    case "list":
      await listAllAccounts();
      break;

    case "balance":
      if (!arg1) {
        console.log("❌ Please provide address via ARG1 env variable");
        return;
      }
      await checkBalance(arg1);
      break;

    case "fund":
      if (!arg1) {
        console.log("❌ Please provide address via ARG1 env variable");
        return;
      }
      const amount = arg2 || "1.0";
      await fundWallet(arg1, amount);
      break;

    case "content":
      if (!arg1) {
        console.log("❌ Please provide content ID via ARG1 env variable");
        return;
      }
      await getContentDetails(arg1);
      break;

    default:
      console.log("❌ Unknown command:", command);
      console.log("Run without arguments to see available commands");
  }
}

// Export functions for use in other scripts or console
module.exports = {
  createWallet,
  fundWallet,
  checkBalance,
  transferETH,
  transferVAULT,
  importWallet,
  importFromMnemonic,
  listAllAccounts,
  getContentDetails
};

// Run main if executed directly
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
