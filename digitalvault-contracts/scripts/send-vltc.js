const { ethers } = require("hardhat");

const VLTC_ADDRESS = "0x9583d1643354B9C254586966343D54bCB79970D3";
const RECIPIENT   = "0x1Cfe39A9176c9979a65035024aC097875b2e5893";
const AMOUNT      = ethers.parseEther("10000"); // 10,000 VLTC

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);

  const vltc = await ethers.getContractAt("VaultToken", VLTC_ADDRESS);

  // Check balances before
  const contractBal = await vltc.balanceOf(VLTC_ADDRESS);
  const recipientBal = await vltc.balanceOf(RECIPIENT);
  console.log("Contract holds:  ", ethers.formatEther(contractBal), "VLTC");
  console.log("Recipient before:", ethers.formatEther(recipientBal), "VLTC");

  // Check deployer has DEFAULT_ADMIN_ROLE
  const adminRole = await vltc.DEFAULT_ADMIN_ROLE();
  const isAdmin = await vltc.hasRole(adminRole, deployer.address);
  console.log("Is admin:", isAdmin);
  if (!isAdmin) {
    throw new Error(`${deployer.address} does not have admin role — wrong key?`);
  }

  // Mint directly to recipient (deployer has MINTER_ROLE)
  console.log(`\nMinting 10,000 VLTC to ${RECIPIENT}...`);
  const tx = await vltc.mint(RECIPIENT, AMOUNT);
  await tx.wait();
  console.log("TX hash:", tx.hash);

  // Check balances after
  const recipientAfter = await vltc.balanceOf(RECIPIENT);
  console.log("Recipient after: ", ethers.formatEther(recipientAfter), "VLTC ✅");
}

main().catch((e) => { console.error(e); process.exit(1); });
