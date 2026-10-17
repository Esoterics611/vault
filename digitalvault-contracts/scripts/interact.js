const hre = require("hardhat");
const fs = require("fs");

/**
 * Helper script to interact with deployed contracts
 *
 * Usage:
 *   npx hardhat run scripts/interact.js --network localhost
 */

async function main() {
  // Load deployed addresses
  const deployments = JSON.parse(fs.readFileSync("deployments.json", "utf8"));

  const [signer] = await hre.ethers.getSigners();
  console.log("Interacting with contracts using account:", signer.address);
  console.log("Account balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(signer.address)), "ETH\n");

  // Get contract instances
  const vaultToken = await hre.ethers.getContractAt("VaultToken", deployments.VaultToken);
  const contentRegistry = await hre.ethers.getContractAt("ContentRegistry", deployments.ContentRegistry);
  const marketplace = await hre.ethers.getContractAt("Marketplace", deployments.Marketplace);

  // Example 1: Check VaultToken details
  console.log("=== VaultToken Info ===");
  const name = await vaultToken.name();
  const symbol = await vaultToken.symbol();
  const totalSupply = await vaultToken.totalSupply();
  const balance = await vaultToken.balanceOf(signer.address);

  console.log("Name:", name);
  console.log("Symbol:", symbol);
  console.log("Total Supply:", hre.ethers.formatEther(totalSupply), "VAULT");
  console.log("Your Balance:", hre.ethers.formatEther(balance), "VAULT\n");

  // Example 2: Register content
  console.log("=== Registering Sample Content ===");
  const contentHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("My First Poem"));
  const metadataHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes('{"title":"My First Poem","type":"poetry"}'));
  const encryptedKey = hre.ethers.hexlify(hre.ethers.randomBytes(32));

  const tx = await contentRegistry.registerContent(
    contentHash,
    metadataHash,
    encryptedKey,
    1024, // fileSize: 1KB
    0, // ContentType.POETRY
    1 // AccessModel.PREVIEW_ALLOWED
  );

  const receipt = await tx.wait();
  console.log("Content registered! Transaction hash:", receipt.hash);

  // Get the content ID from events
  const event = receipt.logs.find(log => {
    try {
      const parsed = contentRegistry.interface.parseLog(log);
      return parsed.name === "ContentRegistered";
    } catch (e) {
      return false;
    }
  });

  if (event) {
    const parsedEvent = contentRegistry.interface.parseLog(event);
    const contentId = parsedEvent.args.contentId;
    console.log("Content ID:", contentId.toString());

    // Fetch content details
    const content = await contentRegistry.getContentInfo(contentId);
    console.log("\nContent Details:");
    console.log("- Owner:", content.owner);
    console.log("- Creator:", content.creator);
    console.log("- Content Type:", content.contentType);
    console.log("- Access Model:", content.accessModel);
    console.log("- File Size:", content.fileSize.toString(), "bytes");
    console.log("- View Count:", content.viewCount.toString());
  }

  // Example 3: Get user's content
  console.log("\n=== Your Content ===");
  const userContents = await contentRegistry.getCreatorContents(signer.address);
  console.log("Total content pieces:", userContents.length);

  console.log("\n✅ Interaction completed!");
  console.log("\n💡 Tip: Edit this script to test different contract functions");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
