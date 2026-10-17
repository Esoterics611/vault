const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * PRE System Deployment Verification Tests
 *
 * Tests the complete deployment and configuration of the PRE system:
 * - VaultToken
 * - ContentRegistry
 * - ReKeyRegistry
 * - Marketplace
 * - Authorization setup
 *
 * Run: npx hardhat test test/PRE-Deployment.test.js
 */

describe("PRE System Deployment Verification", function () {
  let vaultToken, contentRegistry, reKeyRegistry, marketplace;
  let deployer, user1, user2;

  beforeEach(async function () {
    [deployer, user1, user2] = await ethers.getSigners();

    // Deploy VaultToken
    const VaultToken = await ethers.getContractFactory("VaultToken");
    vaultToken = await VaultToken.deploy(deployer.address);

    // Deploy ContentRegistry
    const ContentRegistry = await ethers.getContractFactory("ContentRegistry");
    contentRegistry = await ContentRegistry.deploy(deployer.address);

    // Deploy ReKeyRegistry
    const ReKeyRegistry = await ethers.getContractFactory("ReKeyRegistry");
    reKeyRegistry = await ReKeyRegistry.deploy();

    // Deploy Marketplace
    const Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await Marketplace.deploy(
      deployer.address,
      await vaultToken.getAddress(),
      await contentRegistry.getAddress(),
      await reKeyRegistry.getAddress(),
      deployer.address
    );

    // Setup authorization
    await contentRegistry.setTrustedMarketplace(await marketplace.getAddress(), true);
    await reKeyRegistry.setTrustedMarketplace(await marketplace.getAddress(), true);
  });

  describe("Deployment Validation", function () {
    it("Should deploy all 4 contracts successfully", async function () {
      expect(await vaultToken.getAddress()).to.be.properAddress;
      expect(await contentRegistry.getAddress()).to.be.properAddress;
      expect(await reKeyRegistry.getAddress()).to.be.properAddress;
      expect(await marketplace.getAddress()).to.be.properAddress;
    });

    it("Should set correct deployer as owner", async function () {
      // VaultToken uses AccessControl, not Ownable - check admin role instead
      const adminRole = await vaultToken.DEFAULT_ADMIN_ROLE();
      expect(await vaultToken.hasRole(adminRole, deployer.address)).to.be.true;

      expect(await contentRegistry.owner()).to.equal(deployer.address);
      expect(await reKeyRegistry.owner()).to.equal(deployer.address);
      expect(await marketplace.owner()).to.equal(deployer.address);
    });

    it("Should initialize VaultToken with correct total supply", async function () {
      const totalSupply = await vaultToken.totalSupply();
      // VaultToken has 1 billion initial supply (see VaultToken.sol constructor)
      expect(totalSupply).to.equal(ethers.parseEther("1000000000"));
    });
  });

  describe("Contract References", function () {
    it("Marketplace should reference correct VaultToken", async function () {
      const marketplaceVaultToken = await marketplace.vaultToken();
      expect(marketplaceVaultToken).to.equal(await vaultToken.getAddress());
    });

    it("Marketplace should reference correct ContentRegistry", async function () {
      const marketplaceContentRegistry = await marketplace.contentRegistry();
      expect(marketplaceContentRegistry).to.equal(await contentRegistry.getAddress());
    });

    it("Marketplace should reference correct ReKeyRegistry", async function () {
      const marketplaceReKeyRegistry = await marketplace.reKeyRegistry();
      expect(marketplaceReKeyRegistry).to.equal(await reKeyRegistry.getAddress());
    });
  });

  describe("Authorization Setup", function () {
    it("ContentRegistry should trust Marketplace", async function () {
      const isTrusted = await contentRegistry.isTrustedMarketplace(await marketplace.getAddress());
      expect(isTrusted).to.be.true;
    });

    it("ReKeyRegistry should trust Marketplace", async function () {
      const isTrusted = await reKeyRegistry.isTrustedMarketplace(await marketplace.getAddress());
      expect(isTrusted).to.be.true;
    });

    it("Should allow owner to revoke marketplace trust", async function () {
      const marketplaceAddr = await marketplace.getAddress();

      // Revoke trust
      await contentRegistry.setTrustedMarketplace(marketplaceAddr, false);
      expect(await contentRegistry.isTrustedMarketplace(marketplaceAddr)).to.be.false;

      // Re-establish trust
      await contentRegistry.setTrustedMarketplace(marketplaceAddr, true);
      expect(await contentRegistry.isTrustedMarketplace(marketplaceAddr)).to.be.true;
    });

    it("Should prevent non-owner from setting trust", async function () {
      await expect(
        contentRegistry.connect(user1).setTrustedMarketplace(user2.address, true)
      ).to.be.revertedWithCustomError(contentRegistry, "OwnableUnauthorizedAccount");
    });
  });

  describe("End-to-End Integration Test", function () {
    it("Should complete full PRE purchase flow", async function () {
      // Setup: Distribute tokens
      await vaultToken.setTreasury(deployer.address);
      await vaultToken.transfer(user1.address, ethers.parseEther("10000"));
      await vaultToken.transfer(user2.address, ethers.parseEther("10000"));

      // User1 approves marketplace
      await vaultToken.connect(user1).approve(await marketplace.getAddress(), ethers.parseEther("1000"));
      await vaultToken.connect(user2).approve(await marketplace.getAddress(), ethers.parseEther("1000"));

      // User1 registers PRE content
      const contentHash = ethers.keccak256(ethers.toUtf8Bytes("test_content"));
      const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("metadata"));
      const encryptedKey = ethers.toUtf8Bytes("encrypted_key");
      const capsuleHash = ethers.keccak256(ethers.toUtf8Bytes("capsule"));
      const publicKey = ethers.toUtf8Bytes("public_key");

      await contentRegistry.connect(user1).registerContentWithPRE(
        contentHash,
        metadataHash,
        encryptedKey,
        1024,
        0, // ContentType.IMAGE
        0, // AccessModel.FULL_OWNERSHIP
        capsuleHash,
        publicKey
      );

      // User1 creates marketplace listing
      const listingPrice = ethers.parseEther("100");
      await marketplace.connect(user1).createListing(
        1, // contentId
        listingPrice,
        0, // ListingType.FULL_OWNERSHIP
        0, // no access duration
        0  // no max keys
      );

      // User2 purchases with PRE
      const newEncryptedKey = ethers.toUtf8Bytes("user2_encrypted_key");
      const kfragHash = ethers.keccak256(ethers.toUtf8Bytes("kfrag"));
      const newCapsuleHash = ethers.keccak256(ethers.toUtf8Bytes("new_capsule"));
      const newPublicKey = ethers.toUtf8Bytes("user2_public_key");

      await expect(
        marketplace.connect(user2).purchaseListingWithPRE(
          1, // listingId
          newEncryptedKey,
          kfragHash,
          newCapsuleHash,
          newPublicKey,
          2, // threshold
          3  // totalShares
        )
      ).to.emit(marketplace, "ListingPurchasedWithPRE");

      // Verify ownership transferred
      const content = await contentRegistry.getContentInfo(1);
      expect(content.owner).to.equal(user2.address);
      expect(content.capsuleHash).to.equal(newCapsuleHash);

      // Verify grant created and used
      const grant = await reKeyRegistry.verifyGrant(1);
      expect(grant.isUsed).to.be.true;
      expect(grant.buyer).to.equal(user2.address);
    });
  });

  describe("Pausability", function () {
    it("ContentRegistry should be pausable by owner", async function () {
      await contentRegistry.pause();

      await expect(
        contentRegistry.connect(user1).registerContent(
          ethers.keccak256(ethers.toUtf8Bytes("test")),
          ethers.keccak256(ethers.toUtf8Bytes("metadata")),
          ethers.toUtf8Bytes("key"),
          1024,
          0,
          0
        )
      ).to.be.revertedWithCustomError(contentRegistry, "EnforcedPause");

      await contentRegistry.unpause();
    });

    it("Marketplace should be pausable by owner", async function () {
      await marketplace.pause();

      await expect(
        marketplace.connect(user1).createListing(1, 100, 0, 0, 0)
      ).to.be.revertedWithCustomError(marketplace, "EnforcedPause");

      await marketplace.unpause();
    });
  });

  describe("Fee Configuration", function () {
    it("Should have correct default fees", async function () {
      expect(await marketplace.platformFee()).to.equal(250); // 2.5%
      expect(await marketplace.creatorRoyalty()).to.equal(500); // 5%
      expect(await marketplace.storageProviderCut()).to.equal(100); // 1%
    });

    it("Should allow owner to update fees", async function () {
      await marketplace.updateFees(300, 600, 150);

      expect(await marketplace.platformFee()).to.equal(300);
      expect(await marketplace.creatorRoyalty()).to.equal(600);
      expect(await marketplace.storageProviderCut()).to.equal(150);
    });

    it("Should prevent fees from being too high", async function () {
      await expect(
        marketplace.updateFees(1100, 600, 150) // 11% platform fee
      ).to.be.revertedWithCustomError(marketplace, "PlatformFeeTooHigh");
    });
  });

  describe("Deployment Cost Estimation", function () {
    it("Should report deployment gas costs", async function () {
      // This test runs actual deployment to measure gas
      const VaultToken = await ethers.getContractFactory("VaultToken");
      const vt = await VaultToken.deploy(deployer.address);
      const vtReceipt = await vt.deploymentTransaction().wait();

      const ContentRegistry = await ethers.getContractFactory("ContentRegistry");
      const cr = await ContentRegistry.deploy(deployer.address);
      const crReceipt = await cr.deploymentTransaction().wait();

      const ReKeyRegistry = await ethers.getContractFactory("ReKeyRegistry");
      const rr = await ReKeyRegistry.deploy();
      const rrReceipt = await rr.deploymentTransaction().wait();

      const Marketplace = await ethers.getContractFactory("Marketplace");
      const mp = await Marketplace.deploy(
        deployer.address,
        await vt.getAddress(),
        await cr.getAddress(),
        await rr.getAddress(),
        deployer.address
      );
      const mpReceipt = await mp.deploymentTransaction().wait();

      console.log("\n📊 Deployment Gas Costs:");
      console.log(`   VaultToken:      ${vtReceipt.gasUsed.toLocaleString()} gas`);
      console.log(`   ContentRegistry: ${crReceipt.gasUsed.toLocaleString()} gas`);
      console.log(`   ReKeyRegistry:   ${rrReceipt.gasUsed.toLocaleString()} gas`);
      console.log(`   Marketplace:     ${mpReceipt.gasUsed.toLocaleString()} gas`);

      const total = vtReceipt.gasUsed + crReceipt.gasUsed + rrReceipt.gasUsed + mpReceipt.gasUsed;
      console.log(`   TOTAL:           ${total.toLocaleString()} gas`);
      console.log(`   Estimated cost @ 0.1 gwei: $${(Number(total) * 0.0000000001 * 3000).toFixed(2)}\n`);
    });
  });
});
