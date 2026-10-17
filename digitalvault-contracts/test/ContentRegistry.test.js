const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ContentRegistry", function () {
  let contentRegistry;
  let owner, creator, buyer, other;

  // Test data
  const contentHash = ethers.keccak256(ethers.toUtf8Bytes("test_content_hash"));
  const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("test_metadata"));
  const encryptedKey = ethers.toUtf8Bytes("encrypted_aes_key_data");
  const fileSize = 1024 * 1024; // 1 MB
  const ContentType = { POETRY: 0, JOURNAL: 1, PHOTO: 2, VIDEO: 3 };
  const AccessModel = { PRIVATE: 0, PREVIEW_ALLOWED: 1, PAY_PER_ACCESS: 2, FOR_SALE: 3 };

  // PRE test data
  const capsuleHash = ethers.keccak256(ethers.toUtf8Bytes("test_capsule_hash"));
  const ownerPublicKey = ethers.toUtf8Bytes("owner_public_key_umbral");
  const newCapsuleHash = ethers.keccak256(ethers.toUtf8Bytes("reencrypted_capsule"));
  const newOwnerPublicKey = ethers.toUtf8Bytes("buyer_public_key_umbral");

  beforeEach(async function () {
    [owner, creator, buyer, other] = await ethers.getSigners();

    const ContentRegistry = await ethers.getContractFactory("ContentRegistry");
    contentRegistry = await ContentRegistry.deploy(owner.address);
  });

  describe("Deployment", function () {
    it("Should set the correct owner", async function () {
      expect(await contentRegistry.owner()).to.equal(owner.address);
    });

    it("Should start with content ID counter at 1", async function () {
      // Register content and check it gets ID 1
      const tx = await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      // Content should be registered with ID 1
      const content = await contentRegistry.getContentInfo(1);
      expect(content.creator).to.equal(creator.address);
    });
  });

  describe("Legacy Content Registration (No PRE)", function () {
    it("Should register content successfully", async function () {
      const tx = await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      await expect(tx)
        .to.emit(contentRegistry, "ContentRegistered")
        .withArgs(1, creator.address, ContentType.POETRY, await ethers.provider.getBlock("latest").then(b => b.timestamp));

      const content = await contentRegistry.getContentInfo(1);
      expect(content.contentHash).to.equal(contentHash);
      expect(content.metadataHash).to.equal(metadataHash);
      expect(content.owner).to.equal(creator.address);
      expect(content.creator).to.equal(creator.address);
      expect(content.fileSize).to.equal(fileSize);
      expect(content.contentType).to.equal(ContentType.POETRY);
      expect(content.accessModel).to.equal(AccessModel.PRIVATE);
      expect(content.viewCount).to.equal(0);
      expect(content.isActive).to.be.true;
      expect(content.usesPRE).to.be.false; // Legacy content
    });

    it("Should reject registration with invalid content hash", async function () {
      await expect(
        contentRegistry.connect(creator).registerContent(
          ethers.ZeroHash,
          metadataHash,
          encryptedKey,
          fileSize,
          ContentType.POETRY,
          AccessModel.PRIVATE
        )
      ).to.be.revertedWithCustomError(contentRegistry, "InvalidContentHash");
    });

    it("Should reject registration with invalid metadata hash", async function () {
      await expect(
        contentRegistry.connect(creator).registerContent(
          contentHash,
          ethers.ZeroHash,
          encryptedKey,
          fileSize,
          ContentType.POETRY,
          AccessModel.PRIVATE
        )
      ).to.be.revertedWithCustomError(contentRegistry, "InvalidMetadataHash");
    });

    it("Should reject registration with empty encrypted key", async function () {
      await expect(
        contentRegistry.connect(creator).registerContent(
          contentHash,
          metadataHash,
          "0x",
          fileSize,
          ContentType.POETRY,
          AccessModel.PRIVATE
        )
      ).to.be.revertedWithCustomError(contentRegistry, "EncryptedKeyRequired");
    });

    it("Should reject registration with zero file size", async function () {
      await expect(
        contentRegistry.connect(creator).registerContent(
          contentHash,
          metadataHash,
          encryptedKey,
          0,
          ContentType.POETRY,
          AccessModel.PRIVATE
        )
      ).to.be.revertedWithCustomError(contentRegistry, "InvalidFileSize");
    });

    it("Should reject registration with file size exceeding limit", async function () {
      const tooLarge = 101 * 1024 * 1024; // 101 MB
      await expect(
        contentRegistry.connect(creator).registerContent(
          contentHash,
          metadataHash,
          encryptedKey,
          tooLarge,
          ContentType.POETRY,
          AccessModel.PRIVATE
        )
      ).to.be.revertedWithCustomError(contentRegistry, "InvalidFileSize");
    });

    it("Should track creator contents", async function () {
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      await contentRegistry.connect(creator).registerContent(
        ethers.keccak256(ethers.toUtf8Bytes("content2")),
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.JOURNAL,
        AccessModel.FOR_SALE
      );

      const creatorContents = await contentRegistry.getCreatorContents(creator.address);
      expect(creatorContents.length).to.equal(2);
      expect(creatorContents[0]).to.equal(1);
      expect(creatorContents[1]).to.equal(2);
    });

    it("Should track owner contents", async function () {
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      const ownerContents = await contentRegistry.getOwnerContents(creator.address);
      expect(ownerContents.length).to.equal(1);
      expect(ownerContents[0]).to.equal(1);
    });
  });

  describe("PRE Content Registration (Week 3 - NEW)", function () {
    it("Should register PRE content successfully", async function () {
      const tx = await contentRegistry.connect(creator).registerContentWithPRE(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );

      await expect(tx)
        .to.emit(contentRegistry, "ContentRegistered")
        .withArgs(1, creator.address, ContentType.PHOTO, await ethers.provider.getBlock("latest").then(b => b.timestamp));

      const content = await contentRegistry.getContentInfo(1);
      expect(content.contentHash).to.equal(contentHash);
      expect(content.owner).to.equal(creator.address);
      expect(content.creator).to.equal(creator.address);
      expect(content.usesPRE).to.be.true;
      expect(content.capsuleHash).to.equal(capsuleHash);
      expect(content.capsuleVersion).to.equal(1); // Umbral
    });

    it("Should reject PRE registration without capsule hash", async function () {
      await expect(
        contentRegistry.connect(creator).registerContentWithPRE(
          contentHash,
          metadataHash,
          encryptedKey,
          fileSize,
          ContentType.PHOTO,
          AccessModel.FOR_SALE,
          ethers.ZeroHash, // Invalid
          ownerPublicKey
        )
      ).to.be.revertedWithCustomError(contentRegistry, "CapsuleHashRequired");
    });

    it("Should reject PRE registration without owner public key", async function () {
      await expect(
        contentRegistry.connect(creator).registerContentWithPRE(
          contentHash,
          metadataHash,
          encryptedKey,
          fileSize,
          ContentType.PHOTO,
          AccessModel.FOR_SALE,
          capsuleHash,
          "0x" // Empty public key
        )
      ).to.be.revertedWithCustomError(contentRegistry, "PublicKeyRequired");
    });

    it("Should correctly identify PRE vs legacy content", async function () {
      // Register legacy content
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      // Register PRE content
      await contentRegistry.connect(creator).registerContentWithPRE(
        ethers.keccak256(ethers.toUtf8Bytes("content2")),
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );

      expect(await contentRegistry.isContentPRE(1)).to.be.false; // Legacy
      expect(await contentRegistry.isContentPRE(2)).to.be.true;  // PRE
    });

    it("Should return PRE info correctly", async function () {
      await contentRegistry.connect(creator).registerContentWithPRE(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );

      const [returnedHash, returnedPubKey, version] = await contentRegistry.getPREInfo(1);

      expect(returnedHash).to.equal(capsuleHash);
      expect(ethers.hexlify(returnedPubKey)).to.equal(ethers.hexlify(ownerPublicKey));
      expect(version).to.equal(1);
    });

    it("Should reject getPREInfo for legacy content", async function () {
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      await expect(
        contentRegistry.getPREInfo(1)
      ).to.be.revertedWithCustomError(contentRegistry, "ContentDoesNotUsePRE");
    });
  });

  describe("Legacy Ownership Transfer", function () {
    beforeEach(async function () {
      // Register legacy content
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.FOR_SALE
      );
    });

    it("Should transfer ownership successfully", async function () {
      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");
      const price = ethers.parseEther("1.0");

      const tx = await contentRegistry.connect(creator).transferOwnership(
        1,
        buyer.address,
        newKey,
        price
      );

      await expect(tx)
        .to.emit(contentRegistry, "ContentOwnershipTransferred")
        .withArgs(1, creator.address, buyer.address, price);

      const content = await contentRegistry.getContentInfo(1);
      expect(content.owner).to.equal(buyer.address);
      expect(content.creator).to.equal(creator.address); // Creator unchanged
    });

    it("Should prevent transferring PRE content with legacy function", async function () {
      // Register PRE content
      await contentRegistry.connect(creator).registerContentWithPRE(
        ethers.keccak256(ethers.toUtf8Bytes("content2")),
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.PHOTO,
        AccessModel.FOR_SALE,
        capsuleHash,
        ownerPublicKey
      );

      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");

      await expect(
        contentRegistry.connect(creator).transferOwnership(
          2,
          buyer.address,
          newKey,
          0
        )
      ).to.be.revertedWithCustomError(contentRegistry, "UsePRETransferFunction");
    });

    it("Should prevent non-owner from transferring", async function () {
      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");

      await expect(
        contentRegistry.connect(other).transferOwnership(
          1,
          buyer.address,
          newKey,
          0
        )
      ).to.be.revertedWithCustomError(contentRegistry, "CallerNotAuthorized");
    });

    it("Should update ownership tracking", async function () {
      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");

      await contentRegistry.connect(creator).transferOwnership(
        1,
        buyer.address,
        newKey,
        0
      );

      // Creator should still have it in creator list
      const creatorContents = await contentRegistry.getCreatorContents(creator.address);
      expect(creatorContents.length).to.equal(1);

      // Creator should not have it in owner list
      const creatorOwned = await contentRegistry.getOwnerContents(creator.address);
      expect(creatorOwned.length).to.equal(0);

      // Buyer should have it in owner list
      const buyerOwned = await contentRegistry.getOwnerContents(buyer.address);
      expect(buyerOwned.length).to.equal(1);
      expect(buyerOwned[0]).to.equal(1);
    });
  });

  describe("PRE Ownership Transfer (Week 3 - NEW)", function () {
    beforeEach(async function () {
      // Register PRE content
      await contentRegistry.connect(creator).registerContentWithPRE(
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

    it("Should transfer PRE ownership successfully", async function () {
      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");
      const price = ethers.parseEther("2.5");

      const tx = await contentRegistry.connect(creator).transferOwnershipWithPRE(
        1,
        buyer.address,
        newKey,
        price,
        newCapsuleHash,
        newOwnerPublicKey
      );

      await expect(tx)
        .to.emit(contentRegistry, "ContentOwnershipTransferredWithPRE")
        .withArgs(1, creator.address, buyer.address, price, newCapsuleHash, newOwnerPublicKey);

      const content = await contentRegistry.getContentInfo(1);
      expect(content.owner).to.equal(buyer.address);
      expect(content.creator).to.equal(creator.address);
      expect(content.capsuleHash).to.equal(newCapsuleHash);
    });

    it("Should reject PRE transfer without capsule hash", async function () {
      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");

      await expect(
        contentRegistry.connect(creator).transferOwnershipWithPRE(
          1,
          buyer.address,
          newKey,
          0,
          ethers.ZeroHash, // Invalid
          newOwnerPublicKey
        )
      ).to.be.revertedWithCustomError(contentRegistry, "CapsuleHashRequired");
    });

    it("Should reject PRE transfer without public key", async function () {
      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");

      await expect(
        contentRegistry.connect(creator).transferOwnershipWithPRE(
          1,
          buyer.address,
          newKey,
          0,
          newCapsuleHash,
          "0x" // Empty
        )
      ).to.be.revertedWithCustomError(contentRegistry, "PublicKeyRequired");
    });

    it("Should reject PRE transfer for legacy content", async function () {
      // Register legacy content
      await contentRegistry.connect(creator).registerContent(
        ethers.keccak256(ethers.toUtf8Bytes("content2")),
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.FOR_SALE
      );

      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");

      await expect(
        contentRegistry.connect(creator).transferOwnershipWithPRE(
          2,
          buyer.address,
          newKey,
          0,
          newCapsuleHash,
          newOwnerPublicKey
        )
      ).to.be.revertedWithCustomError(contentRegistry, "ContentDoesNotUsePRE");
    });

    it("Should update PRE info after transfer", async function () {
      const newKey = ethers.toUtf8Bytes("buyer_encrypted_key");

      await contentRegistry.connect(creator).transferOwnershipWithPRE(
        1,
        buyer.address,
        newKey,
        0,
        newCapsuleHash,
        newOwnerPublicKey
      );

      const [hash, pubKey, version] = await contentRegistry.getPREInfo(1);
      expect(hash).to.equal(newCapsuleHash);
      expect(ethers.hexlify(pubKey)).to.equal(ethers.hexlify(newOwnerPublicKey));
      expect(version).to.equal(1);
    });
  });

  describe("PRE Helper Functions (Week 3 - NEW)", function () {
    beforeEach(async function () {
      // Register PRE content
      await contentRegistry.connect(creator).registerContentWithPRE(
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

    it("Should update capsule hash by owner", async function () {
      const updatedHash = ethers.keccak256(ethers.toUtf8Bytes("updated_capsule"));

      await contentRegistry.connect(creator).updateCapsuleHash(1, updatedHash);

      const content = await contentRegistry.getContentInfo(1);
      expect(content.capsuleHash).to.equal(updatedHash);
    });

    it("Should reject capsule hash update by non-owner", async function () {
      const updatedHash = ethers.keccak256(ethers.toUtf8Bytes("updated_capsule"));

      await expect(
        contentRegistry.connect(other).updateCapsuleHash(1, updatedHash)
      ).to.be.revertedWithCustomError(contentRegistry, "CallerNotOwner");
    });

    it("Should update owner public key", async function () {
      const updatedKey = ethers.toUtf8Bytes("updated_public_key");

      await contentRegistry.connect(creator).updateOwnerPublicKey(1, updatedKey);

      const content = await contentRegistry.getContentInfo(1);
      expect(ethers.hexlify(content.ownerPublicKey)).to.equal(ethers.hexlify(updatedKey));
    });

    it("Should reject public key update for legacy content", async function () {
      // Register legacy content
      await contentRegistry.connect(creator).registerContent(
        ethers.keccak256(ethers.toUtf8Bytes("content2")),
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      const updatedKey = ethers.toUtf8Bytes("updated_public_key");

      await expect(
        contentRegistry.connect(creator).updateOwnerPublicKey(2, updatedKey)
      ).to.be.revertedWithCustomError(contentRegistry, "ContentDoesNotUsePRE");
    });

    it("Should get PRE contents by owner", async function () {
      // Register another PRE content
      await contentRegistry.connect(creator).registerContentWithPRE(
        ethers.keccak256(ethers.toUtf8Bytes("content2")),
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.VIDEO,
        AccessModel.FOR_SALE,
        ethers.keccak256(ethers.toUtf8Bytes("capsule2")),
        ownerPublicKey
      );

      // Register legacy content
      await contentRegistry.connect(creator).registerContent(
        ethers.keccak256(ethers.toUtf8Bytes("content3")),
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );

      const preContents = await contentRegistry.getPREContentsByOwner(creator.address);
      expect(preContents.length).to.equal(2);
      expect(preContents[0]).to.equal(1);
      expect(preContents[1]).to.equal(2);
    });

    it("Should return empty array if no PRE contents", async function () {
      const preContents = await contentRegistry.getPREContentsByOwner(other.address);
      expect(preContents.length).to.equal(0);
    });
  });

  describe("Access Model Management", function () {
    beforeEach(async function () {
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );
    });

    it("Should update access model successfully", async function () {
      const tx = await contentRegistry.connect(creator).updateAccessModel(
        1,
        AccessModel.FOR_SALE
      );

      await expect(tx)
        .to.emit(contentRegistry, "AccessModelUpdated")
        .withArgs(1, AccessModel.PRIVATE, AccessModel.FOR_SALE);

      const content = await contentRegistry.getContentInfo(1);
      expect(content.accessModel).to.equal(AccessModel.FOR_SALE);
    });

    it("Should prevent non-owner from updating access model", async function () {
      await expect(
        contentRegistry.connect(other).updateAccessModel(1, AccessModel.FOR_SALE)
      ).to.be.revertedWithCustomError(contentRegistry, "CallerNotOwner");
    });
  });

  describe("Content Deactivation", function () {
    beforeEach(async function () {
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );
    });

    it("Should deactivate content successfully", async function () {
      const tx = await contentRegistry.connect(creator).deactivateContent(1);

      await expect(tx)
        .to.emit(contentRegistry, "ContentDeactivated")
        .withArgs(1, creator.address);

      const content = await contentRegistry.getContentInfo(1);
      expect(content.isActive).to.be.false;
    });

    it("Should prevent non-owner from deactivating", async function () {
      await expect(
        contentRegistry.connect(other).deactivateContent(1)
      ).to.be.revertedWithCustomError(contentRegistry, "CallerNotOwner");
    });
  });

  describe("View Count", function () {
    beforeEach(async function () {
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PREVIEW_ALLOWED
      );
    });

    it("Should increment view count", async function () {
      await contentRegistry.connect(other).incrementViewCount(1);
      await contentRegistry.connect(buyer).incrementViewCount(1);

      const content = await contentRegistry.getContentInfo(1);
      expect(content.viewCount).to.equal(2);
    });

    it("Should emit ViewCountIncremented event", async function () {
      const tx = await contentRegistry.connect(other).incrementViewCount(1);

      await expect(tx)
        .to.emit(contentRegistry, "ViewCountIncremented")
        .withArgs(1, 1);
    });
  });

  describe("Ownership Verification", function () {
    beforeEach(async function () {
      await contentRegistry.connect(creator).registerContent(
        contentHash,
        metadataHash,
        encryptedKey,
        fileSize,
        ContentType.POETRY,
        AccessModel.PRIVATE
      );
    });

    it("Should verify correct owner", async function () {
      expect(await contentRegistry.verifyOwnership(1, creator.address)).to.be.true;
    });

    it("Should reject incorrect owner", async function () {
      expect(await contentRegistry.verifyOwnership(1, buyer.address)).to.be.false;
    });

    it("Should return false for non-existent content", async function () {
      expect(await contentRegistry.verifyOwnership(999, creator.address)).to.be.false;
    });
  });

  describe("Pausable", function () {
    it("Should pause and unpause", async function () {
      await contentRegistry.connect(owner).pause();

      await expect(
        contentRegistry.connect(creator).registerContent(
          contentHash,
          metadataHash,
          encryptedKey,
          fileSize,
          ContentType.POETRY,
          AccessModel.PRIVATE
        )
      ).to.be.revertedWithCustomError(contentRegistry, "EnforcedPause");

      await contentRegistry.connect(owner).unpause();

      await expect(
        contentRegistry.connect(creator).registerContent(
          contentHash,
          metadataHash,
          encryptedKey,
          fileSize,
          ContentType.POETRY,
          AccessModel.PRIVATE
        )
      ).to.not.be.reverted;
    });

    it("Should only allow owner to pause", async function () {
      await expect(
        contentRegistry.connect(other).pause()
      ).to.be.revertedWithCustomError(contentRegistry, "OwnableUnauthorizedAccount");
    });
  });
});
