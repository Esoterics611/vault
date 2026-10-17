// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StorageProvider
 * @dev Manages decentralized storage provider network for DigitalVault
 *
 * Features:
 * - Provider registration with staking
 * - Proof of storage verification
 * - Reputation system
 * - Slashing for misbehavior
 * - Reward distribution
 */
contract StorageProvider is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Provider {
        address providerAddress;
        string ipfsNodeId;          // IPFS peer ID
        uint256 stakedAmount;       // VLTC staked
        uint256 storageCapacity;    // In GB
        uint256 usedStorage;        // In GB
        uint256 contentCount;       // Number of contents hosted
        uint256 uptime;             // Uptime percentage (basis points, 10000 = 100%)
        uint256 reputationScore;    // 0-1000
        uint256 registeredAt;
        bool isActive;
    }

    struct StorageRecord {
        uint256 contentId;
        address[] providers;        // List of providers hosting this content
        uint256 redundancyLevel;    // How many copies required
        uint256 lastVerified;       // Last proof-of-storage verification
    }

    IERC20 public vaultToken;

    // Constants
    uint256 public constant MIN_STAKE = 1000 * 10**18;          // 1000 VLTC
    uint256 public constant MIN_STORAGE_CAPACITY = 100;         // 100 GB
    uint256 public constant REDUNDANCY_REQUIREMENT = 3;         // 3 providers minimum
    uint256 public constant VERIFICATION_INTERVAL = 24 hours;
    uint256 public constant UPTIME_THRESHOLD = 9500;            // 95%

    mapping(address => Provider) public providers;
    mapping(uint256 => StorageRecord) public storageRecords;
    mapping(address => uint256) public pendingRewards;

    address[] private providerList;

    // Events
    event ProviderRegistered(
        address indexed providerAddress,
        string ipfsNodeId,
        uint256 stakedAmount
    );

    event StorageProvided(uint256 indexed contentId, address indexed providerAddress);
    event ProofSubmitted(uint256 indexed contentId, address indexed providerAddress, uint256 timestamp);
    event ProviderSlashed(address indexed providerAddress, uint256 amount, string reason);
    event RewardsClaimed(address indexed providerAddress, uint256 amount);
    event StakeAdded(address indexed providerAddress, uint256 amount);
    event StakeWithdrawn(address indexed providerAddress, uint256 amount);

    constructor(address initialOwner, address _vaultToken) Ownable(initialOwner) {
        require(_vaultToken != address(0), "StorageProvider: vault token is zero address");
        vaultToken = IERC20(_vaultToken);
    }

    /**
     * @dev Register as a storage provider
     */
    function registerProvider(
        string memory ipfsNodeId,
        uint256 storageCapacity,
        uint256 stakeAmount
    ) external nonReentrant {
        require(bytes(ipfsNodeId).length > 0, "StorageProvider: invalid IPFS node ID");
        require(storageCapacity >= MIN_STORAGE_CAPACITY, "StorageProvider: insufficient storage capacity");
        require(stakeAmount >= MIN_STAKE, "StorageProvider: insufficient stake");
        require(!providers[msg.sender].isActive, "StorageProvider: already registered");

        // Transfer stake to contract
        vaultToken.safeTransferFrom(msg.sender, address(this), stakeAmount);

        Provider storage provider = providers[msg.sender];
        provider.providerAddress = msg.sender;
        provider.ipfsNodeId = ipfsNodeId;
        provider.stakedAmount = stakeAmount;
        provider.storageCapacity = storageCapacity;
        provider.usedStorage = 0;
        provider.contentCount = 0;
        provider.uptime = 10000; // Start at 100%
        provider.reputationScore = 500; // Start at 500/1000
        provider.registeredAt = block.timestamp;
        provider.isActive = true;

        providerList.push(msg.sender);

        emit ProviderRegistered(msg.sender, ipfsNodeId, stakeAmount);
    }

    /**
     * @dev Add additional stake
     */
    function stakeAdditional(uint256 amount) external nonReentrant {
        require(providers[msg.sender].isActive, "StorageProvider: not a registered provider");
        require(amount > 0, "StorageProvider: amount must be greater than zero");

        vaultToken.safeTransferFrom(msg.sender, address(this), amount);
        providers[msg.sender].stakedAmount += amount;

        emit StakeAdded(msg.sender, amount);
    }

    /**
     * @dev Withdraw stake (only if no content hosted or after grace period)
     */
    function unstake(uint256 amount) external nonReentrant {
        Provider storage provider = providers[msg.sender];
        require(provider.isActive, "StorageProvider: not a registered provider");
        require(amount > 0, "StorageProvider: amount must be greater than zero");
        require(provider.stakedAmount >= amount, "StorageProvider: insufficient stake");

        uint256 remainingStake = provider.stakedAmount - amount;
        if (provider.contentCount > 0) {
            require(remainingStake >= MIN_STAKE, "StorageProvider: must maintain minimum stake while hosting content");
        }

        provider.stakedAmount = remainingStake;
        vaultToken.safeTransfer(msg.sender, amount);

        emit StakeWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Assign content to provider (called by coordinator)
     */
    function provideStorage(uint256 contentId, uint256 fileSizeGB) external {
        Provider storage provider = providers[msg.sender];
        require(provider.isActive, "StorageProvider: not a registered provider");
        require(
            provider.usedStorage + fileSizeGB <= provider.storageCapacity,
            "StorageProvider: insufficient capacity"
        );

        provider.usedStorage += fileSizeGB;
        provider.contentCount++;

        StorageRecord storage record = storageRecords[contentId];
        record.contentId = contentId;
        record.providers.push(msg.sender);
        record.lastVerified = block.timestamp;

        if (record.redundancyLevel == 0) {
            record.redundancyLevel = REDUNDANCY_REQUIREMENT;
        }

        emit StorageProvided(contentId, msg.sender);
    }

    /**
     * @dev Submit proof of storage
     */
    function submitProofOfStorage(uint256 contentId, bytes32 proof) external {
        Provider storage provider = providers[msg.sender];
        require(provider.isActive, "StorageProvider: not a registered provider");

        StorageRecord storage record = storageRecords[contentId];
        require(_isProviderForContent(contentId, msg.sender), "StorageProvider: not hosting this content");

        // Simple proof verification (in production, implement Merkle proof)
        require(proof != bytes32(0), "StorageProvider: invalid proof");

        record.lastVerified = block.timestamp;

        // Update uptime (simplified - in production, track more granularly)
        if (provider.uptime < 10000) {
            provider.uptime = (provider.uptime * 99 + 10000) / 100; // Gradually improve
        }

        // Update reputation
        if (provider.reputationScore < 1000) {
            provider.reputationScore += 1;
        }

        emit ProofSubmitted(contentId, msg.sender, block.timestamp);
    }

    /**
     * @dev Update storage capacity
     */
    function updateStorageCapacity(uint256 newCapacity) external {
        Provider storage provider = providers[msg.sender];
        require(provider.isActive, "StorageProvider: not a registered provider");
        require(newCapacity >= provider.usedStorage, "StorageProvider: capacity below used storage");

        provider.storageCapacity = newCapacity;
    }

    /**
     * @dev Slash provider for misbehavior (onlyOwner)
     */
    function slashProvider(address providerAddress, uint256 slashAmount, string memory reason) external onlyOwner {
        Provider storage provider = providers[providerAddress];
        require(provider.isActive, "StorageProvider: provider not active");
        require(provider.stakedAmount >= slashAmount, "StorageProvider: insufficient stake to slash");

        provider.stakedAmount -= slashAmount;
        provider.reputationScore = provider.reputationScore > 100 ? provider.reputationScore - 100 : 0;

        // Transfer slashed amount to owner (treasury)
        vaultToken.safeTransfer(owner(), slashAmount);

        emit ProviderSlashed(providerAddress, slashAmount, reason);
    }

    /**
     * @dev Distribute rewards to provider (called by RewardDistributor)
     */
    function distributeReward(address providerAddress, uint256 amount) external {
        require(providers[providerAddress].isActive, "StorageProvider: provider not active");
        pendingRewards[providerAddress] += amount;
    }

    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external nonReentrant {
        require(providers[msg.sender].isActive, "StorageProvider: not a registered provider");

        uint256 amount = pendingRewards[msg.sender];
        require(amount > 0, "StorageProvider: no rewards to claim");

        pendingRewards[msg.sender] = 0;
        vaultToken.safeTransfer(msg.sender, amount);

        emit RewardsClaimed(msg.sender, amount);
    }

    /**
     * @dev Get provider info
     */
    function getProviderInfo(address providerAddress) external view returns (Provider memory) {
        return providers[providerAddress];
    }

    /**
     * @dev Get content providers
     */
    function getContentProviders(uint256 contentId) external view returns (address[] memory) {
        return storageRecords[contentId].providers;
    }

    /**
     * @dev Find available providers with sufficient capacity
     */
    function findAvailableProviders(uint256 requiredCapacityGB, uint256 count)
        external
        view
        returns (address[] memory)
    {
        address[] memory availableProviders = new address[](count);
        uint256 found = 0;

        for (uint256 i = 0; i < providerList.length && found < count; i++) {
            address providerAddr = providerList[i];
            Provider memory provider = providers[providerAddr];

            if (
                provider.isActive &&
                provider.storageCapacity - provider.usedStorage >= requiredCapacityGB &&
                provider.uptime >= UPTIME_THRESHOLD
            ) {
                availableProviders[found] = providerAddr;
                found++;
            }
        }

        // Resize array if not enough providers found
        if (found < count) {
            address[] memory result = new address[](found);
            for (uint256 i = 0; i < found; i++) {
                result[i] = availableProviders[i];
            }
            return result;
        }

        return availableProviders;
    }

    /**
     * @dev Check if address is provider for specific content
     */
    function _isProviderForContent(uint256 contentId, address providerAddress)
        internal
        view
        returns (bool)
    {
        address[] memory contentProviders = storageRecords[contentId].providers;
        for (uint256 i = 0; i < contentProviders.length; i++) {
            if (contentProviders[i] == providerAddress) {
                return true;
            }
        }
        return false;
    }
}
