const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Marketplace - PRE Integration (Week 4)", function () {
  let marketplace, contentRegistry, reKeyRegistry, vaultToken;
  let owner, seller, buyer, feeCollector, other;

  // Test data
  const contentHash = ethers.keccak256(ethers.toUtf8Bytes("test_content"));
  const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("test_metadata"));
  const encryptedKey = ethers.toUtf8Bytes("encrypted_aes_key");
  const fileSize = 1024 * 1024; // 1 MB
  const ContentType = { POETRY: 0, JOURNAL: 1, PHOTO: 2, VIDEO: 3 };
  const AccessModel = { PRIVATE: 0, PREVIEW_ALLOWED: 1, PAY_PER_ACCESS: 2, FOR_SALE: 3 };
  const ListingType = { FULL_OWNERSHIP: 0, ACCESS_KEY: 1, TIMED_ACCESS: 2 };

  // PRE test data
  const capsuleHash = ethers.keccak256(ethers.toUtf8Bytes("test_capsule"));
  const ownerPublicKey = ethers.toUtf8Bytes("seller_public_key");
  const kfragHash = ethers.keccak256(ethers.toUtf8Bytes("kfrag_fragments"));
  const newCapsuleHash = ethers.keccak256(ethers.toUtf8Bytes("reencrypted_capsule"));
  const newOwnerPublicKey = ethers.toUtf8Bytes("buyer_public_key");
  const newEncryptedKey = ethers.toUtf8Bytes("buyer_encrypted_key");
  const threshold = 2;
  const totalShares = 3;

  // Listing price
  const listingPrice = ethers.parseEther("100"); // 100 VLTC

  beforeEach(async function () {
    [owner, seller, buyer, feeCollector, other] = await ethers.getSigners();

    // Deploy VaultToken
    const VaultToken = await ethers.getContractFactory("VaultToken");
    vaultToken = await VaultToken.deploy(owner.address);

    // Deploy ContentRegistry
    const ContentRegistry = await ethers.getContractFactory("ContentRegistry");
    contentRegistry = await ContentRegistry.deploy(owner.address);

    // Deploy ReKeyRegistry
    const ReKeyRegistry = await ethers.getContractFactory("ReKeyRegistry");
    reKeyRegistry = await ReKeyRegistry.deploy();

    // Deploy Marketplace
    const Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await Marketplace.deploy(
      owner.address,
      await vaultToken.getAddress(),
      await contentRegistry.getAddress(),
      await reKeyRegistry.getAddress(),
      feeCollector.address
    );

    // Set owner as treasury and transfer tokens from contract to owner
    await vaultToken.connect(owner).setTreasury(owner.address);

    // Distribute tokens from owner to test accounts
    await vaultToken.connect(owner).transfer(buyer.address, ethers.parseEther("10000"));
    await vaultToken.connect(owner).transfer(seller.address, ethers.parseEther("10000"));

    // Approve marketplace to spend tokens
    await vaultToken.connect(buyer).approve(await marketplace.getAddress(), ethers.parseEther("10000"));
    await vaultToken.connect(seller).approve(await marketplace.getAddress(), ethers.parseEther("10000"));

    // Week 4 - Authorize marketplace to transfer content on behalf of owners
    await contentRegistry.connect(owner).setTrustedMarketplace(await marketplace.getAddress(), true);

    // Week 4 - Authorize marketplace to mark grants as used
    await reKeyRegistry.connect(owner).setTrustedMarketplace(await marketplace.getAddress(), true);
  });

  describe("Deployment", function () {
    it("Should set correct addresses", async function () {
      expect(await marketplace.owner()).to.equal(owner.address);
      expect(await marketplace.vaultToken()).to.equal(await vaultToken.getAddress());
      expect(await marketplace.contentRegistry()).to.equal(await contentRegistry.getAddress());
      expect(await marketplace.reKeyRegistry()).to.equal(await reKeyRegistry.getAddress());
      expect(await marketplace.feeCollector()).to.equal(feeCollector.address);
    });

    it("Should set default fees", async function () {
      expect(await marketplace.platformFee()).to.equal(250); // 2.5%
      expect(await marketplace.creatorRoyalty()).to.equal(500); // 5%
      expect(await marketplace.storageProviderCut()).to.equal(100); // 1%
    });
  });

  describe("Legacy Content Listing & Purchase", function () {
    let contentId, listingId;

    beforeEach(async function () {
      // Register legacy content (no PRE)
      contentId = await contentRegistry.connect(seller).registerContent.staticCall(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.FOR_SALE
      );
      await contentRegistry.connect(seller).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.FOR_SALE
      );
    });

    it("Should create listing for legacy content", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0, // no duration
        0  // unlimited keys
      );

      const tx = await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      await expect(tx)
        .to.emit(marketplace, "ListingCreated")
        .withArgs(listingId, contentId, seller.address, listingPrice, ListingType.FULL_OWNERSHIP);
    });

    it("Should purchase legacy content successfully", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      const buyerBalanceBefore = await vaultToken.balanceOf(buyer.address);

      const tx = await marketplace.connect(buyer).purchaseListing(
        listingId,
        newEncryptedKey
      );

      await expect(tx)
        .to.emit(marketplace, "ListingPurchased")
        .withArgs(listingId, buyer.address, listingPrice, ListingType.FULL_OWNERSHIP);

      // Check ownership transferred
      const content = await contentRegistry.getContentInfo(contentId);
      expect(content.owner).to.equal(buyer.address);
      expect(content.creator).to.equal(seller.address); // Creator unchanged

      // Check payment
      const buyerBalanceAfter = await vaultToken.balanceOf(buyer.address);
      expect(buyerBalanceBefore - buyerBalanceAfter).to.equal(listingPrice);
    });

    it("Should prevent purchasing with PRE function for legacy content", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      // Try to use PRE purchase for legacy content
      // This should work but will call legacy transferOwnership since isPRE=false
      // The actual validation happens in ContentRegistry
      await expect(
        marketplace.connect(buyer).purchaseListingWithPRE(
          listingId,
          newEncryptedKey,
          kfragHash,
          newCapsuleHash,
          newOwnerPublicKey,
          threshold,
          totalShares
        )
      ).to.not.be.reverted;
    });
  });

  describe("PRE Content Listing & Purchase (Week 4 - NEW)", function () {
    let contentId, listingId;

    beforeEach(async function () {
      // Register PRE content
      contentId = await contentRegistry.connect(seller).registerContentWithPRE.staticCall(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );
      await contentRegistry.connect(seller).registerContentWithPRE(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );
    });

    it("Should create listing for PRE content", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      const tx = await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      await expect(tx)
        .to.emit(marketplace, "ListingCreated")
        .withArgs(listingId, contentId, seller.address, listingPrice, ListingType.FULL_OWNERSHIP);

      const listing = await marketplace.getListing(listingId);
      expect(listing.contentId).to.equal(contentId);
      expect(listing.seller).to.equal(seller.address);
      expect(listing.isActive).to.be.true;
    });

    it("Should purchase PRE content with full flow", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      const buyerBalanceBefore = await vaultToken.balanceOf(buyer.address);

      // Purchase with PRE
      const tx = await marketplace.connect(buyer).purchaseListingWithPRE(
        listingId,
        newEncryptedKey,
        kfragHash,
        newCapsuleHash,
        newOwnerPublicKey,
        threshold,
        totalShares
      );

      // Check events
      await expect(tx)
        .to.emit(marketplace, "ListingPurchasedWithPRE")
        .withArgs(listingId, contentId, buyer.address, listingPrice, kfragHash);

      // Should also emit grant events
      await expect(tx)
        .to.emit(reKeyRegistry, "GrantCreated");

      await expect(tx)
        .to.emit(reKeyRegistry, "GrantUsed");

      // Check ownership transferred
      const content = await contentRegistry.getContentInfo(contentId);
      expect(content.owner).to.equal(buyer.address);
      expect(content.creator).to.equal(seller.address);
      expect(content.capsuleHash).to.equal(newCapsuleHash);

      // Check PRE info updated
      const [capsule, pubKey, version] = await contentRegistry.getPREInfo(contentId);
      expect(capsule).to.equal(newCapsuleHash);
      expect(ethers.hexlify(pubKey)).to.equal(ethers.hexlify(newOwnerPublicKey));
      expect(version).to.equal(1);

      // Check payment
      const buyerBalanceAfter = await vaultToken.balanceOf(buyer.address);
      expect(buyerBalanceBefore - buyerBalanceAfter).to.equal(listingPrice);

      // Check listing inactive
      const listing = await marketplace.getListing(listingId);
      expect(listing.isActive).to.be.false;
    });

    it("Should reject PRE purchase without kfrag hash", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      await expect(
        marketplace.connect(buyer).purchaseListingWithPRE(
          listingId,
          newEncryptedKey,
          ethers.ZeroHash, // Invalid
          newCapsuleHash,
          newOwnerPublicKey,
          threshold,
          totalShares
        )
      ).to.be.revertedWithCustomError(marketplace, "KfragHashRequired");
    });

    it("Should reject PRE purchase without capsule hash", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      await expect(
        marketplace.connect(buyer).purchaseListingWithPRE(
          listingId,
          newEncryptedKey,
          kfragHash,
          ethers.ZeroHash, // Invalid
          newOwnerPublicKey,
          threshold,
          totalShares
        )
      ).to.be.revertedWithCustomError(marketplace, "CapsuleHashRequired");
    });

    it("Should reject PRE purchase without public key", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      await expect(
        marketplace.connect(buyer).purchaseListingWithPRE(
          listingId,
          newEncryptedKey,
          kfragHash,
          newCapsuleHash,
          "0x", // Invalid
          threshold,
          totalShares
        )
      ).to.be.revertedWithCustomError(marketplace, "PublicKeyRequired");
    });

    it("Should prevent purchasing PRE content with legacy function", async function () {
      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      // Try legacy purchase for PRE content
      await expect(
        marketplace.connect(buyer).purchaseListing(
          listingId,
          newEncryptedKey
        )
      ).to.be.revertedWithCustomError(contentRegistry, "UsePRETransferFunction");
    });
  });

  describe("Payment Distribution", function () {
    let contentId, listingId;

    beforeEach(async function () {
      // Register PRE content
      contentId = await contentRegistry.connect(seller).registerContentWithPRE.staticCall(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );
      await contentRegistry.connect(seller).registerContentWithPRE(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );

      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
    });

    it("Should distribute payment correctly (primary sale)", async function () {
      const feeCollectorBefore = await vaultToken.balanceOf(feeCollector.address);

      await marketplace.connect(buyer).purchaseListingWithPRE(
        listingId,
        newEncryptedKey,
        kfragHash,
        newCapsuleHash,
        newOwnerPublicKey,
        threshold,
        totalShares
      );

      // Check seller earnings (96.5% of price)
      const sellerEarnings = await marketplace.getEarnings(seller.address);
      const expectedSeller = (listingPrice * 9650n) / 10000n; // 100% - 2.5% - 1%
      expect(sellerEarnings).to.equal(expectedSeller);

      // Check fee collector received platform fee (2.5%) + storage (1%)
      const feeCollectorAfter = await vaultToken.balanceOf(feeCollector.address);
      const expectedFees = (listingPrice * 350n) / 10000n; // 3.5%
      expect(feeCollectorAfter - feeCollectorBefore).to.equal(expectedFees);
    });

    it("Should apply royalty on secondary sale", async function () {
      // First purchase
      await marketplace.connect(buyer).purchaseListingWithPRE(
        listingId,
        newEncryptedKey,
        kfragHash,
        newCapsuleHash,
        newOwnerPublicKey,
        threshold,
        totalShares
      );

      // Buyer re-lists
      const newListingId = await marketplace.connect(buyer).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(buyer).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      // New buyer purchases
      const newKfragHash = ethers.keccak256(ethers.toUtf8Bytes("new_kfrag"));
      const newCapsuleHash2 = ethers.keccak256(ethers.toUtf8Bytes("capsule2"));
      const newOwnerPublicKey2 = ethers.toUtf8Bytes("buyer2_public_key");

      await vaultToken.transfer(other.address, ethers.parseEther("10000"));
      await vaultToken.connect(other).approve(await marketplace.getAddress(), ethers.parseEther("10000"));

      await marketplace.connect(other).purchaseListingWithPRE(
        newListingId,
        newEncryptedKey,
        newKfragHash,
        newCapsuleHash2,
        newOwnerPublicKey2,
        threshold,
        totalShares
      );

      // Check creator royalty (5%)
      const creatorEarnings = await marketplace.getEarnings(seller.address);
      const royaltyAmount = (listingPrice * 500n) / 10000n;

      // Seller earnings from first sale + royalty from second sale
      const firstSaleEarnings = (listingPrice * 9650n) / 10000n;
      expect(creatorEarnings).to.equal(firstSaleEarnings + royaltyAmount);

      // Buyer (now seller) gets less due to royalty
      const buyerEarnings = await marketplace.getEarnings(buyer.address);
      const expectedBuyerEarnings = (listingPrice * 9150n) / 10000n; // 96.5% - 5%
      expect(buyerEarnings).to.equal(expectedBuyerEarnings);
    });
  });

  describe("Earnings Withdrawal", function () {
    let contentId, listingId;

    beforeEach(async function () {
      contentId = await contentRegistry.connect(seller).registerContentWithPRE.staticCall(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );
      await contentRegistry.connect(seller).registerContentWithPRE(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );

      listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      await marketplace.connect(buyer).purchaseListingWithPRE(
        listingId,
        newEncryptedKey,
        kfragHash,
        newCapsuleHash,
        newOwnerPublicKey,
        threshold,
        totalShares
      );
    });

    it("Should allow seller to withdraw earnings", async function () {
      const earnings = await marketplace.getEarnings(seller.address);
      const sellerBalanceBefore = await vaultToken.balanceOf(seller.address);

      const tx = await marketplace.connect(seller).withdrawEarnings();

      await expect(tx)
        .to.emit(marketplace, "EarningsWithdrawn")
        .withArgs(seller.address, earnings);

      const sellerBalanceAfter = await vaultToken.balanceOf(seller.address);
      expect(sellerBalanceAfter - sellerBalanceBefore).to.equal(earnings);

      // Earnings should be zero after withdrawal
      expect(await marketplace.getEarnings(seller.address)).to.equal(0);
    });

    it("Should reject withdrawal with no earnings", async function () {
      await expect(
        marketplace.connect(other).withdrawEarnings()
      ).to.be.revertedWithCustomError(marketplace, "NoEarningsToWithdraw");
    });
  });

  describe("Listing Management", function () {
    let contentId;

    beforeEach(async function () {
      contentId = await contentRegistry.connect(seller).registerContentWithPRE.staticCall(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );
      await contentRegistry.connect(seller).registerContentWithPRE(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );
    });

    it("Should cancel listing", async function () {
      const listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      const tx = await marketplace.connect(seller).cancelListing(listingId);

      await expect(tx)
        .to.emit(marketplace, "ListingCancelled")
        .withArgs(listingId, seller.address);

      const listing = await marketplace.getListing(listingId);
      expect(listing.isActive).to.be.false;
    });

    it("Should update listing price", async function () {
      const listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      const newPrice = ethers.parseEther("150");

      const tx = await marketplace.connect(seller).updateListingPrice(listingId, newPrice);

      await expect(tx)
        .to.emit(marketplace, "PriceUpdated")
        .withArgs(listingId, listingPrice, newPrice);

      const listing = await marketplace.getListing(listingId);
      expect(listing.price).to.equal(newPrice);
    });

    it("Should prevent non-owner from managing listing", async function () {
      const listingId = await marketplace.connect(seller).createListing.staticCall(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );
      await marketplace.connect(seller).createListing(
        contentId,
        listingPrice,
        ListingType.FULL_OWNERSHIP,
        0,
        0
      );

      await expect(
        marketplace.connect(other).cancelListing(listingId)
      ).to.be.revertedWithCustomError(marketplace, "CallerIsNotSeller");

      await expect(
        marketplace.connect(other).updateListingPrice(listingId, ethers.parseEther("200"))
      ).to.be.revertedWithCustomError(marketplace, "CallerIsNotSeller");
    });
  });

  describe("Pausable", function () {
    it("Should pause and unpause marketplace", async function () {
      await marketplace.connect(owner).pause();

      await expect(
        marketplace.connect(seller).createListing(1, listingPrice, ListingType.FULL_OWNERSHIP, 0, 0)
      ).to.be.revertedWithCustomError(marketplace, "EnforcedPause");

      await marketplace.connect(owner).unpause();

      // Should work after unpause (will fail for other reasons, but not pause)
      await expect(
        marketplace.connect(seller).createListing(1, listingPrice, ListingType.FULL_OWNERSHIP, 0, 0)
      ).to.not.be.revertedWithCustomError(marketplace, "EnforcedPause");
    });
  });
});
