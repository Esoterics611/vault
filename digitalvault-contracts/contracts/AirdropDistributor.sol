// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AirdropDistributor
 * @dev Manages airdrop campaigns using Merkle trees for gas efficiency
 *
 * Airdrop Categories:
 * 1. Early Adopters: 50M VLTC (first 10,000 users)
 * 2. Content Creators: 75M VLTC (users who upload content)
 * 3. Storage Providers: 25M VLTC (first 100 providers)
 * 4. Community Contributors: 50M VLTC (governance participants)
 */
contract AirdropDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct AirdropCampaign {
        uint256 campaignId;
        uint256 totalAllocation;
        uint256 perUserAmount;
        uint256 startTime;
        uint256 endTime;
        bytes32 merkleRoot;
        uint256 totalClaimed;
        mapping(address => bool) claimed;
    }

    IERC20 public vaultToken;

    uint256 private _campaignIdCounter;
    mapping(uint256 => AirdropCampaign) public campaigns;

    event CampaignCreated(
        uint256 indexed campaignId,
        uint256 allocation,
        uint256 perUserAmount,
        bytes32 merkleRoot
    );

    event AirdropClaimed(
        uint256 indexed campaignId,
        address indexed user,
        uint256 amount
    );

    event UnclaimedTokensRecovered(uint256 indexed campaignId, uint256 amount);

    constructor(address initialOwner, address _vaultToken) Ownable(initialOwner) {
        require(_vaultToken != address(0), "AirdropDistributor: vault token is zero address");
        vaultToken = IERC20(_vaultToken);
        _campaignIdCounter = 1;
    }

    /**
     * @dev Create an airdrop campaign
     */
    function createAirdropCampaign(
        uint256 totalAllocation,
        uint256 perUserAmount,
        uint256 startTime,
        uint256 endTime,
        bytes32 merkleRoot
    ) external onlyOwner returns (uint256) {
        require(totalAllocation > 0, "AirdropDistributor: invalid allocation");
        require(perUserAmount > 0, "AirdropDistributor: invalid per user amount");
        require(startTime < endTime, "AirdropDistributor: invalid time range");
        require(merkleRoot != bytes32(0), "AirdropDistributor: invalid merkle root");

        uint256 campaignId = _campaignIdCounter++;

        AirdropCampaign storage campaign = campaigns[campaignId];
        campaign.campaignId = campaignId;
        campaign.totalAllocation = totalAllocation;
        campaign.perUserAmount = perUserAmount;
        campaign.startTime = startTime;
        campaign.endTime = endTime;
        campaign.merkleRoot = merkleRoot;
        campaign.totalClaimed = 0;

        emit CampaignCreated(campaignId, totalAllocation, perUserAmount, merkleRoot);

        return campaignId;
    }

    /**
     * @dev Claim airdrop using Merkle proof
     */
    function claimAirdrop(uint256 campaignId, bytes32[] calldata proof, uint256 amount)
        external
        nonReentrant
    {
        AirdropCampaign storage campaign = campaigns[campaignId];

        require(block.timestamp >= campaign.startTime, "AirdropDistributor: campaign not started");
        require(block.timestamp <= campaign.endTime, "AirdropDistributor: campaign ended");
        require(!campaign.claimed[msg.sender], "AirdropDistributor: already claimed");
        require(amount <= campaign.perUserAmount, "AirdropDistributor: amount exceeds allocation");
        require(
            campaign.totalClaimed + amount <= campaign.totalAllocation,
            "AirdropDistributor: campaign depleted"
        );

        // Verify Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(
            MerkleProof.verify(proof, campaign.merkleRoot, leaf),
            "AirdropDistributor: invalid proof"
        );

        campaign.claimed[msg.sender] = true;
        campaign.totalClaimed += amount;

        vaultToken.safeTransfer(msg.sender, amount);

        emit AirdropClaimed(campaignId, msg.sender, amount);
    }

    /**
     * @dev Check if user is eligible (has claimed)
     */
    function hasClaimed(uint256 campaignId, address user) external view returns (bool) {
        return campaigns[campaignId].claimed[user];
    }

    /**
     * @dev Get remaining allocation for a campaign
     */
    function getRemainingAllocation(uint256 campaignId) external view returns (uint256) {
        AirdropCampaign storage campaign = campaigns[campaignId];
        return campaign.totalAllocation - campaign.totalClaimed;
    }

    /**
     * @dev Recover unclaimed tokens after campaign ends (90 days grace period)
     */
    function recoverUnclaimedTokens(uint256 campaignId) external onlyOwner nonReentrant {
        AirdropCampaign storage campaign = campaigns[campaignId];

        require(
            block.timestamp > campaign.endTime + 90 days,
            "AirdropDistributor: grace period not ended"
        );

        uint256 unclaimed = campaign.totalAllocation - campaign.totalClaimed;
        require(unclaimed > 0, "AirdropDistributor: no unclaimed tokens");

        // Transfer unclaimed tokens back to owner (treasury)
        vaultToken.safeTransfer(owner(), unclaimed);

        emit UnclaimedTokensRecovered(campaignId, unclaimed);
    }

    /**
     * @dev Update merkle root for a campaign (before it starts)
     */
    function updateMerkleRoot(uint256 campaignId, bytes32 newMerkleRoot) external onlyOwner {
        AirdropCampaign storage campaign = campaigns[campaignId];
        require(block.timestamp < campaign.startTime, "AirdropDistributor: campaign already started");

        campaign.merkleRoot = newMerkleRoot;
    }
}
