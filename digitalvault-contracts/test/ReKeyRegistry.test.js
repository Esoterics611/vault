const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("ReKeyRegistry", function () {
  let reKeyRegistry;
  let owner, seller, buyer, other;

  const contentId = 1;
  const contentId2 = 2;
  const kfragHash = ethers.keccak256(ethers.toUtf8Bytes("test_kfrag_data"));
  const kfragHash2 = ethers.keccak256(ethers.toUtf8Bytes("another_kfrag"));
  const threshold = 2;
  const totalShares = 3;

  beforeEach(async function () {
    [owner, seller, buyer, other] = await ethers.getSigners();

    const ReKeyRegistry = await ethers.getContractFactory("ReKeyRegistry");
    reKeyRegistry = await ReKeyRegistry.deploy();
  });

  describe("Deployment", function () {
    it("Should set the correct owner", async function () {
      expect(await reKeyRegistry.owner()).to.equal(owner.address);
    });

    it("Should have correct default expiration", async function () {
      expect(await reKeyRegistry.DEFAULT_EXPIRATION()).to.equal(7 * 24 * 60 * 60);
    });
  });

  describe("Grant Creation", function () {
    it("Should create a grant successfully", async function () {
      const tx = await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt.blockNumber);
      const expectedExpiration = BigInt(block.timestamp) + BigInt(7 * 24 * 60 * 60);

      await expect(tx)
        .to.emit(reKeyRegistry, "GrantCreated")
        .withArgs(
          contentId,
          seller.address,
          buyer.address,
          kfragHash,
          threshold,
          totalShares,
          expectedExpiration
        );

      const grant = await reKeyRegistry.verifyGrant(contentId);
      expect(grant.contentId).to.equal(contentId);
      expect(grant.seller).to.equal(seller.address);
      expect(grant.buyer).to.equal(buyer.address);
      expect(grant.kfragHash).to.equal(kfragHash);
      expect(grant.threshold).to.equal(threshold);
      expect(grant.totalShares).to.equal(totalShares);
      expect(grant.isActive).to.be.true;
      expect(grant.isUsed).to.be.false;
    });

    it("Should prevent duplicate grants", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      await expect(
        reKeyRegistry.connect(seller).createGrant(
          contentId,
          buyer.address,
          kfragHash,
          threshold,
          totalShares
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantAlreadyExists");
    });

    it("Should prevent invalid threshold (threshold > totalShares)", async function () {
      await expect(
        reKeyRegistry.connect(seller).createGrant(
          contentId,
          buyer.address,
          kfragHash,
          4, // threshold
          3  // totalShares
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "InvalidThreshold");
    });

    it("Should prevent zero threshold", async function () {
      await expect(
        reKeyRegistry.connect(seller).createGrant(
          contentId,
          buyer.address,
          kfragHash,
          0,
          totalShares
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "ThresholdMustBePositive");
    });

    it("Should prevent granting to zero address", async function () {
      await expect(
        reKeyRegistry.connect(seller).createGrant(
          contentId,
          ethers.ZeroAddress,
          kfragHash,
          threshold,
          totalShares
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "InvalidBuyerAddress");
    });

    it("Should prevent self-grant", async function () {
      await expect(
        reKeyRegistry.connect(seller).createGrant(
          contentId,
          seller.address,
          kfragHash,
          threshold,
          totalShares
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "CannotGrantToSelf");
    });

    it("Should prevent invalid kfrag hash", async function () {
      await expect(
        reKeyRegistry.connect(seller).createGrant(
          contentId,
          buyer.address,
          ethers.ZeroHash,
          threshold,
          totalShares
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "InvalidKfragHash");
    });

    it("Should prevent too many shares", async function () {
      await expect(
        reKeyRegistry.connect(seller).createGrant(
          contentId,
          buyer.address,
          kfragHash,
          5,
          11 // > 10 limit
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "TooManyShares");
    });

    it("Should track grants by seller", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      await reKeyRegistry.connect(seller).createGrant(
        contentId2,
        buyer.address,
        kfragHash2,
        threshold,
        totalShares
      );

      const sellerGrants = await reKeyRegistry.getGrantsBySeller(seller.address);
      expect(sellerGrants.length).to.equal(2);
      expect(sellerGrants[0]).to.equal(contentId);
      expect(sellerGrants[1]).to.equal(contentId2);
    });

    it("Should track grants by buyer", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      await reKeyRegistry.connect(other).createGrant(
        contentId2,
        buyer.address,
        kfragHash2,
        threshold,
        totalShares
      );

      const buyerGrants = await reKeyRegistry.getGrantsByBuyer(buyer.address);
      expect(buyerGrants.length).to.equal(2);
      expect(buyerGrants[0]).to.equal(contentId);
      expect(buyerGrants[1]).to.equal(contentId2);
    });
  });

  describe("Grant Verification", function () {
    beforeEach(async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );
    });

    it("Should verify active grant returns true", async function () {
      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.true;
    });

    it("Should return false for non-existent grant", async function () {
      expect(await reKeyRegistry.isGrantActive(999)).to.be.false;
    });

    it("Should return false for expired grant", async function () {
      // Fast forward 8 days (past 7 day expiration)
      await time.increase(8 * 24 * 60 * 60);

      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.false;
    });

    it("Should check if grant exists", async function () {
      expect(await reKeyRegistry.grantExists(contentId)).to.be.true;
      expect(await reKeyRegistry.grantExists(999)).to.be.false;
    });

    it("Should verify kfrag hash correctly", async function () {
      expect(await reKeyRegistry.verifyKfragHash(contentId, kfragHash)).to.be.true;
      expect(await reKeyRegistry.verifyKfragHash(contentId, kfragHash2)).to.be.false;
    });

    it("Should return grant details via getGrant", async function () {
      const [
        grantSeller,
        grantBuyer,
        grantKfragHash,
        grantThreshold,
        grantTotalShares,
        expiresAt,
        isActive,
        isUsed
      ] = await reKeyRegistry.getGrant(contentId);

      expect(grantSeller).to.equal(seller.address);
      expect(grantBuyer).to.equal(buyer.address);
      expect(grantKfragHash).to.equal(kfragHash);
      expect(grantThreshold).to.equal(threshold);
      expect(grantTotalShares).to.equal(totalShares);
      expect(isActive).to.be.true;
      expect(isUsed).to.be.false;
    });
  });

  describe("Grant Usage", function () {
    beforeEach(async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );
    });

    it("Should allow buyer to mark grant as used", async function () {
      const tx = await reKeyRegistry.connect(buyer).markGrantUsed(contentId);

      await expect(tx)
        .to.emit(reKeyRegistry, "GrantUsed")
        .withArgs(contentId, buyer.address, await time.latest());

      const grant = await reKeyRegistry.verifyGrant(contentId);
      expect(grant.isUsed).to.be.true;
      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.false;
    });

    it("Should prevent non-buyer from marking used", async function () {
      await expect(
        reKeyRegistry.connect(other).markGrantUsed(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "NotAuthorized");
    });

    it("Should prevent seller from marking used", async function () {
      await expect(
        reKeyRegistry.connect(seller).markGrantUsed(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "NotAuthorized");
    });

    it("Should prevent marking already used grant", async function () {
      await reKeyRegistry.connect(buyer).markGrantUsed(contentId);

      await expect(
        reKeyRegistry.connect(buyer).markGrantUsed(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantAlreadyUsed");
    });

    it("Should prevent marking revoked grant as used", async function () {
      await reKeyRegistry.connect(seller).revokeGrant(contentId);

      await expect(
        reKeyRegistry.connect(buyer).markGrantUsed(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantNotActive");
    });

    it("Should prevent marking expired grant as used", async function () {
      await time.increase(8 * 24 * 60 * 60);

      await expect(
        reKeyRegistry.connect(buyer).markGrantUsed(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantExpired");
    });

    it("Should prevent marking non-existent grant as used", async function () {
      await expect(
        reKeyRegistry.connect(buyer).markGrantUsed(999)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantDoesNotExist");
    });
  });

  describe("Grant Revocation", function () {
    beforeEach(async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );
    });

    it("Should allow seller to revoke unused grant", async function () {
      const tx = await reKeyRegistry.connect(seller).revokeGrant(contentId);

      await expect(tx)
        .to.emit(reKeyRegistry, "GrantRevoked")
        .withArgs(contentId, seller.address, await time.latest());

      const grant = await reKeyRegistry.verifyGrant(contentId);
      expect(grant.isActive).to.be.false;
      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.false;
    });

    it("Should prevent non-seller from revoking", async function () {
      await expect(
        reKeyRegistry.connect(buyer).revokeGrant(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "OnlySellerCanRevoke");
    });

    it("Should prevent revoking used grant", async function () {
      await reKeyRegistry.connect(buyer).markGrantUsed(contentId);

      await expect(
        reKeyRegistry.connect(seller).revokeGrant(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "CannotRevokeUsedGrant");
    });

    it("Should prevent revoking already revoked grant", async function () {
      await reKeyRegistry.connect(seller).revokeGrant(contentId);

      await expect(
        reKeyRegistry.connect(seller).revokeGrant(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantNotActive");
    });

    it("Should prevent revoking non-existent grant", async function () {
      await expect(
        reKeyRegistry.connect(seller).revokeGrant(999)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantDoesNotExist");
    });
  });

  describe("Edge Cases", function () {
    it("Should handle multiple grants for same seller", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      await reKeyRegistry.connect(seller).createGrant(
        contentId2,
        other.address,
        kfragHash2,
        threshold,
        totalShares
      );

      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.true;
      expect(await reKeyRegistry.isGrantActive(contentId2)).to.be.true;
    });

    it("Should handle multiple grants for same buyer", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      await reKeyRegistry.connect(other).createGrant(
        contentId2,
        buyer.address,
        kfragHash2,
        threshold,
        totalShares
      );

      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.true;
      expect(await reKeyRegistry.isGrantActive(contentId2)).to.be.true;
    });

    it("Should handle grant lifecycle: create → use → cannot reuse", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.true;

      await reKeyRegistry.connect(buyer).markGrantUsed(contentId);

      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.false;

      await expect(
        reKeyRegistry.connect(buyer).markGrantUsed(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantAlreadyUsed");
    });

    it("Should handle grant lifecycle: create → revoke → cannot use", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.true;

      await reKeyRegistry.connect(seller).revokeGrant(contentId);

      expect(await reKeyRegistry.isGrantActive(contentId)).to.be.false;

      await expect(
        reKeyRegistry.connect(buyer).markGrantUsed(contentId)
      ).to.be.revertedWithCustomError(reKeyRegistry, "GrantNotActive");
    });

    it("Should correctly track multiple grants per user", async function () {
      // Seller creates multiple grants
      await reKeyRegistry.connect(seller).createGrant(1, buyer.address, kfragHash, 2, 3);
      await reKeyRegistry.connect(seller).createGrant(2, other.address, kfragHash, 2, 3);
      await reKeyRegistry.connect(seller).createGrant(3, buyer.address, kfragHash, 2, 3);

      const sellerGrants = await reKeyRegistry.getGrantsBySeller(seller.address);
      expect(sellerGrants.length).to.equal(3);

      const buyerGrants = await reKeyRegistry.getGrantsByBuyer(buyer.address);
      expect(buyerGrants.length).to.equal(2);

      const otherGrants = await reKeyRegistry.getGrantsByBuyer(other.address);
      expect(otherGrants.length).to.equal(1);
    });
  });

  describe("Gas Optimization Tests", function () {
    it("Should efficiently create grant", async function () {
      const tx = await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      const receipt = await tx.wait();
      // Gas should be reasonable (< 300k for first grant with storage)
      expect(receipt.gasUsed).to.be.lt(300000);
    });

    it("Should efficiently query grant", async function () {
      await reKeyRegistry.connect(seller).createGrant(
        contentId,
        buyer.address,
        kfragHash,
        threshold,
        totalShares
      );

      // View functions should be cheap
      const grant = await reKeyRegistry.verifyGrant(contentId);
      expect(grant.contentId).to.equal(contentId);
    });
  });

  describe("Batch Operations", function () {
    it("Should create multiple grants in batch", async function () {
      const contentIds = [1, 2, 3];
      const buyers = [buyer.address, buyer.address, other.address];
      const kfragHashes = [
        ethers.keccak256(ethers.toUtf8Bytes("kfrag1")),
        ethers.keccak256(ethers.toUtf8Bytes("kfrag2")),
        ethers.keccak256(ethers.toUtf8Bytes("kfrag3"))
      ];
      const thresholds = [2, 2, 2];
      const totalSharesArray = [3, 3, 3];

      const tx = await reKeyRegistry.connect(seller).batchCreateGrants(
        contentIds,
        buyers,
        kfragHashes,
        thresholds,
        totalSharesArray
      );

      // Check all grants were created
      expect(await reKeyRegistry.isGrantActive(1)).to.be.true;
      expect(await reKeyRegistry.isGrantActive(2)).to.be.true;
      expect(await reKeyRegistry.isGrantActive(3)).to.be.true;

      // Verify grants are tracked correctly
      const sellerGrants = await reKeyRegistry.getGrantsBySeller(seller.address);
      expect(sellerGrants.length).to.equal(3);

      const buyerGrants = await reKeyRegistry.getGrantsByBuyer(buyer.address);
      expect(buyerGrants.length).to.equal(2);
    });

    it("Should reject batch with array length mismatch", async function () {
      const contentIds = [1, 2];
      const buyers = [buyer.address]; // Wrong length
      const kfragHashes = [kfragHash, kfragHash2];
      const thresholds = [2, 2];
      const totalSharesArray = [3, 3];

      await expect(
        reKeyRegistry.connect(seller).batchCreateGrants(
          contentIds,
          buyers,
          kfragHashes,
          thresholds,
          totalSharesArray
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "ArrayLengthMismatch");
    });

    it("Should reject empty batch", async function () {
      await expect(
        reKeyRegistry.connect(seller).batchCreateGrants(
          [], [], [], [], []
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "EmptyArrays");
    });

    it("Should reject batch exceeding limit", async function () {
      const length = 51; // Over limit
      const contentIds = Array.from({ length }, (_, i) => i + 1);
      const buyers = Array(length).fill(buyer.address);
      const kfragHashes = Array(length).fill(kfragHash);
      const thresholds = Array(length).fill(2);
      const totalSharesArray = Array(length).fill(3);

      await expect(
        reKeyRegistry.connect(seller).batchCreateGrants(
          contentIds,
          buyers,
          kfragHashes,
          thresholds,
          totalSharesArray
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "TooManyGrants");
    });

    it("Should still validate individual grants in batch", async function () {
      const contentIds = [1, 2];
      const buyers = [buyer.address, ethers.ZeroAddress]; // Invalid
      const kfragHashes = [kfragHash, kfragHash2];
      const thresholds = [2, 2];
      const totalSharesArray = [3, 3];

      await expect(
        reKeyRegistry.connect(seller).batchCreateGrants(
          contentIds,
          buyers,
          kfragHashes,
          thresholds,
          totalSharesArray
        )
      ).to.be.revertedWithCustomError(reKeyRegistry, "InvalidBuyerAddress");
    });
  });

  describe("Active Grant Filters", function () {
    beforeEach(async function () {
      // Create multiple grants with different states
      await reKeyRegistry.connect(seller).createGrant(1, buyer.address, kfragHash, 2, 3);
      await reKeyRegistry.connect(seller).createGrant(2, buyer.address, kfragHash2, 2, 3);
      await reKeyRegistry.connect(seller).createGrant(3, buyer.address, kfragHash, 2, 3);
      await reKeyRegistry.connect(other).createGrant(4, buyer.address, kfragHash, 2, 3);
    });

    it("Should return only active grants for buyer", async function () {
      // Mark one as used
      await reKeyRegistry.connect(buyer).markGrantUsed(1);

      // Revoke another
      await reKeyRegistry.connect(seller).revokeGrant(2);

      const activeGrants = await reKeyRegistry.getActiveGrantsByBuyer(buyer.address);

      // Should have 2 active grants (3 from seller, 4 from other)
      expect(activeGrants.length).to.equal(2);
      expect(activeGrants).to.include(BigInt(3));
      expect(activeGrants).to.include(BigInt(4));
    });

    it("Should return only active grants for seller", async function () {
      // Mark one as used
      await reKeyRegistry.connect(buyer).markGrantUsed(1);

      // Revoke another
      await reKeyRegistry.connect(seller).revokeGrant(2);

      const activeGrants = await reKeyRegistry.getActiveGrantsBySeller(seller.address);

      // Should have 1 active grant (only grant 3)
      expect(activeGrants.length).to.equal(1);
      expect(activeGrants[0]).to.equal(3);
    });

    it("Should exclude expired grants from active list", async function () {
      // Fast forward past expiration
      await time.increase(8 * 24 * 60 * 60);

      const activeGrantsBuyer = await reKeyRegistry.getActiveGrantsByBuyer(buyer.address);
      const activeGrantsSeller = await reKeyRegistry.getActiveGrantsBySeller(seller.address);

      // All should be expired
      expect(activeGrantsBuyer.length).to.equal(0);
      expect(activeGrantsSeller.length).to.equal(0);
    });

    it("Should return empty array when no active grants", async function () {
      // Mark all seller grants as used or revoked
      await reKeyRegistry.connect(buyer).markGrantUsed(1);
      await reKeyRegistry.connect(seller).revokeGrant(2);
      await reKeyRegistry.connect(seller).revokeGrant(3);

      const activeGrants = await reKeyRegistry.getActiveGrantsBySeller(seller.address);
      expect(activeGrants.length).to.equal(0);
    });

    it("Should handle user with no grants", async function () {
      const activeGrantsBuyer = await reKeyRegistry.getActiveGrantsByBuyer(owner.address);
      const activeGrantsSeller = await reKeyRegistry.getActiveGrantsBySeller(owner.address);

      expect(activeGrantsBuyer.length).to.equal(0);
      expect(activeGrantsSeller.length).to.equal(0);
    });
  });
});
