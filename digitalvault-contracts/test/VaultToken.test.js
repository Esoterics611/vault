const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VaultToken", function () {
  let vaultToken;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const VaultToken = await ethers.getContractFactory("VaultToken");
    vaultToken = await VaultToken.deploy(owner.address);
    await vaultToken.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await vaultToken.name()).to.equal("VaultCoin");
      expect(await vaultToken.symbol()).to.equal("VLTC");
    });

    it("Should mint total supply to contract", async function () {
      const totalSupply = await vaultToken.TOTAL_SUPPLY();
      const contractBalance = await vaultToken.balanceOf(await vaultToken.getAddress());
      expect(contractBalance).to.equal(totalSupply);
    });

    it("Should have correct allocations", async function () {
      expect(await vaultToken.PRESALE_ALLOCATION()).to.equal(ethers.parseEther("300000000"));
      expect(await vaultToken.AIRDROP_ALLOCATION()).to.equal(ethers.parseEther("200000000"));
      expect(await vaultToken.LIQUIDITY_MINING_ALLOCATION()).to.equal(ethers.parseEther("300000000"));
      expect(await vaultToken.STORAGE_REWARDS_ALLOCATION()).to.equal(ethers.parseEther("100000000"));
      expect(await vaultToken.TREASURY_ALLOCATION()).to.equal(ethers.parseEther("100000000"));
    });

    it("Should grant admin role to owner", async function () {
      const DEFAULT_ADMIN_ROLE = await vaultToken.DEFAULT_ADMIN_ROLE();
      expect(await vaultToken.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
    });
  });

  describe("Access Control", function () {
    it("Should allow admin to grant roles", async function () {
      const MINTER_ROLE = await vaultToken.MINTER_ROLE();
      await vaultToken.grantRole(MINTER_ROLE, addr1.address);
      expect(await vaultToken.hasRole(MINTER_ROLE, addr1.address)).to.be.true;
    });

    it("Should not allow non-admin to grant roles", async function () {
      const MINTER_ROLE = await vaultToken.MINTER_ROLE();
      await expect(
        vaultToken.connect(addr1).grantRole(MINTER_ROLE, addr2.address)
      ).to.be.reverted;
    });
  });

  describe("Pausable", function () {
    it("Should allow pauser to pause", async function () {
      await vaultToken.pause();
      expect(await vaultToken.paused()).to.be.true;
    });

    it("Should not allow transfers when paused", async function () {
      await vaultToken.setTreasury(owner.address);
      await vaultToken.pause();

      await expect(
        vaultToken.transfer(addr1.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(vaultToken, "EnforcedPause");
    });

    it("Should allow unpause after pause", async function () {
      await vaultToken.pause();
      await vaultToken.unpause();
      expect(await vaultToken.paused()).to.be.false;
    });
  });

  describe("Burnable", function () {
    it("Should allow users to burn their tokens", async function () {
      await vaultToken.setTreasury(owner.address);
      const burnAmount = ethers.parseEther("1000");

      const balanceBefore = await vaultToken.balanceOf(owner.address);
      await vaultToken.burn(burnAmount);
      const balanceAfter = await vaultToken.balanceOf(owner.address);

      expect(balanceBefore - balanceAfter).to.equal(burnAmount);
    });
  });

  describe("Voting checkpoints", function () {
    it("Should give a holder voting power once they delegate", async function () {
      await vaultToken.delegate(owner.address);
      expect(await vaultToken.getVotes(owner.address)).to.equal(await vaultToken.balanceOf(owner.address));
    });

    it("Should keep past voting power at earlier blocks", async function () {
      await vaultToken.delegate(owner.address);
      const block = await ethers.provider.getBlockNumber();
      const votes = await vaultToken.getVotes(owner.address);
      await ethers.provider.send("evm_mine", []);
      expect(await vaultToken.getPastVotes(owner.address, block)).to.equal(votes);
    });
  });

  describe("Allocations", function () {
    it("Should set presale contract and transfer allocation", async function () {
      await vaultToken.setPresaleContract(addr1.address);

      expect(await vaultToken.presaleContract()).to.equal(addr1.address);
      const presaleBalance = await vaultToken.balanceOf(addr1.address);
      expect(presaleBalance).to.equal(await vaultToken.PRESALE_ALLOCATION());
    });

    it("Should not allow setting presale contract twice", async function () {
      await vaultToken.setPresaleContract(addr1.address);

      await expect(
        vaultToken.setPresaleContract(addr2.address)
      ).to.be.revertedWith("VaultToken: presale already set");
    });

    it("Should set airdrop contract and transfer allocation", async function () {
      await vaultToken.setAirdropContract(addr1.address);

      expect(await vaultToken.airdropContract()).to.equal(addr1.address);
      const airdropBalance = await vaultToken.balanceOf(addr1.address);
      expect(airdropBalance).to.equal(await vaultToken.AIRDROP_ALLOCATION());
    });

    it("Should set reward distributor and transfer allocation", async function () {
      await vaultToken.setRewardDistributor(addr1.address);

      expect(await vaultToken.rewardDistributor()).to.equal(addr1.address);
      const rewardBalance = await vaultToken.balanceOf(addr1.address);
      const expectedAllocation =
        (await vaultToken.LIQUIDITY_MINING_ALLOCATION()) +
        (await vaultToken.STORAGE_REWARDS_ALLOCATION());
      expect(rewardBalance).to.equal(expectedAllocation);
    });

    it("Should set treasury and transfer allocation", async function () {
      await vaultToken.setTreasury(addr1.address);

      expect(await vaultToken.treasury()).to.equal(addr1.address);
      const treasuryBalance = await vaultToken.balanceOf(addr1.address);
      expect(treasuryBalance).to.equal(await vaultToken.TREASURY_ALLOCATION());
    });
  });
});
