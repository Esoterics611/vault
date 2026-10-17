// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RewardDistributor
 * @dev Handles token emission and reward distribution over 4 years
 *
 * Emission Schedule:
 * Year 1: 40% of pool
 * Year 2: 30% of pool
 * Year 3: 20% of pool
 * Year 4: 10% of pool
 *
 * Distribution:
 * - 50% Liquidity Providers (LP stakers)
 * - 30% Storage Providers (based on storage + uptime)
 * - 20% Content Creators (based on engagement + sales)
 */
contract RewardDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct RewardEpoch {
        uint256 epochNumber;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRewards;
        uint256 liquidityMiningRewards;
        uint256 storageProviderRewards;
        uint256 creatorRewards;
        bool distributed;
    }

    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 lastClaimAt;
        uint256 accumulatedRewards;
    }

    IERC20 public vaultToken;

    // Total allocations (from VaultToken)
    uint256 public constant LIQUIDITY_MINING_ALLOCATION = 300_000_000 * 10**18; // 300M VLTC
    uint256 public constant STORAGE_REWARDS_ALLOCATION = 100_000_000 * 10**18;  // 100M VLTC
    uint256 public constant TOTAL_ALLOCATION = 400_000_000 * 10**18;            // 400M VLTC

    // Emission schedule (4 years)
    uint256 public constant YEAR_1_PERCENT = 4000; // 40%
    uint256 public constant YEAR_2_PERCENT = 3000; // 30%
    uint256 public constant YEAR_3_PERCENT = 2000; // 20%
    uint256 public constant YEAR_4_PERCENT = 1000; // 10%

    uint256 public constant EPOCH_DURATION = 7 days; // Weekly epochs
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    uint256 public startTime;
    uint256 public currentEpoch;

    mapping(uint256 => RewardEpoch) public epochs;
    mapping(address => StakeInfo) public stakes;

    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;

    // Distribution percentages (basis points)
    uint256 public liquidityProviderShare = 5000;   // 50%
    uint256 public storageProviderShare = 3000;     // 30%
    uint256 public creatorShare = 2000;             // 20%

    // Events
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount);
    event EpochDistributed(uint256 indexed epochNumber, uint256 totalRewards);

    constructor(address initialOwner, address _vaultToken) Ownable(initialOwner) {
        require(_vaultToken != address(0), "RewardDistributor: vault token is zero address");
        vaultToken = IERC20(_vaultToken);
        startTime = block.timestamp;
        currentEpoch = 0;
    }

    /**
     * @dev Stake VLTC tokens for liquidity mining rewards
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "RewardDistributor: amount must be greater than zero");

        vaultToken.safeTransferFrom(msg.sender, address(this), amount);

        StakeInfo storage stakeInfo = stakes[msg.sender];

        // Claim pending rewards before updating stake
        if (stakeInfo.amount > 0) {
            _claimRewards(msg.sender);
        }

        stakeInfo.amount += amount;
        stakeInfo.stakedAt = block.timestamp;
        stakeInfo.lastClaimAt = block.timestamp;

        totalStaked += amount;

        emit Staked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Unstake VLTC tokens
     */
    function unstake(uint256 amount) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount >= amount, "RewardDistributor: insufficient stake");

        // Claim rewards before unstaking
        _claimRewards(msg.sender);

        stakeInfo.amount -= amount;
        totalStaked -= amount;

        vaultToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external nonReentrant {
        _claimRewards(msg.sender);
    }

    /**
     * @dev Internal function to claim rewards
     */
    function _claimRewards(address user) internal {
        StakeInfo storage stakeInfo = stakes[user];
        uint256 rewards = calculateUserRewards(user);

        if (rewards > 0) {
            stakeInfo.accumulatedRewards = 0;
            stakeInfo.lastClaimAt = block.timestamp;
            totalRewardsDistributed += rewards;

            vaultToken.safeTransfer(user, rewards);

            emit RewardsClaimed(user, rewards);
        }
    }

    /**
     * @dev Calculate rewards for a user
     */
    function calculateUserRewards(address user) public view returns (uint256) {
        StakeInfo memory stakeInfo = stakes[user];

        if (stakeInfo.amount == 0 || totalStaked == 0) {
            return stakeInfo.accumulatedRewards;
        }

        uint256 timeStaked = block.timestamp - stakeInfo.lastClaimAt;
        uint256 currentYearRewards = _getCurrentYearRewards();

        // Calculate pro-rata share of liquidity mining rewards
        uint256 userShare = (stakeInfo.amount * 10000) / totalStaked; // basis points
        uint256 yearlyUserRewards = (currentYearRewards * liquidityProviderShare * userShare) / (10000 * 10000);

        // Pro-rate based on time staked
        uint256 earnedRewards = (yearlyUserRewards * timeStaked) / SECONDS_PER_YEAR;

        return stakeInfo.accumulatedRewards + earnedRewards;
    }

    /**
     * @dev Get current year rewards based on emission schedule
     */
    function _getCurrentYearRewards() internal view returns (uint256) {
        uint256 elapsed = block.timestamp - startTime;
        uint256 year = elapsed / SECONDS_PER_YEAR;

        if (year == 0) {
            return (TOTAL_ALLOCATION * YEAR_1_PERCENT) / 10000;
        } else if (year == 1) {
            return (TOTAL_ALLOCATION * YEAR_2_PERCENT) / 10000;
        } else if (year == 2) {
            return (TOTAL_ALLOCATION * YEAR_3_PERCENT) / 10000;
        } else if (year == 3) {
            return (TOTAL_ALLOCATION * YEAR_4_PERCENT) / 10000;
        } else {
            return 0; // No more emissions after 4 years
        }
    }

    /**
     * @dev Distribute epoch rewards (called by keeper or anyone)
     */
    function distributeEpochRewards() external nonReentrant {
        uint256 expectedEpoch = (block.timestamp - startTime) / EPOCH_DURATION;
        require(expectedEpoch > currentEpoch, "RewardDistributor: epoch not ready");

        uint256 epochRewards = _getCurrentYearRewards() / 52; // Weekly distribution

        RewardEpoch storage epoch = epochs[currentEpoch];
        epoch.epochNumber = currentEpoch;
        epoch.startTime = startTime + (currentEpoch * EPOCH_DURATION);
        epoch.endTime = epoch.startTime + EPOCH_DURATION;
        epoch.totalRewards = epochRewards;
        epoch.liquidityMiningRewards = (epochRewards * liquidityProviderShare) / 10000;
        epoch.storageProviderRewards = (epochRewards * storageProviderShare) / 10000;
        epoch.creatorRewards = (epochRewards * creatorShare) / 10000;
        epoch.distributed = true;

        currentEpoch++;

        emit EpochDistributed(currentEpoch - 1, epochRewards);
    }

    /**
     * @dev Update reward distribution percentages (onlyOwner)
     */
    function updateRewardShares(
        uint256 _liquidityProviderShare,
        uint256 _storageProviderShare,
        uint256 _creatorShare
    ) external onlyOwner {
        require(
            _liquidityProviderShare + _storageProviderShare + _creatorShare == 10000,
            "RewardDistributor: shares must sum to 10000"
        );

        liquidityProviderShare = _liquidityProviderShare;
        storageProviderShare = _storageProviderShare;
        creatorShare = _creatorShare;
    }

    /**
     * @dev Get stake info for a user
     */
    function getStakeInfo(address user) external view returns (StakeInfo memory) {
        return stakes[user];
    }

    /**
     * @dev Get current epoch information
     */
    function getCurrentEpochInfo() external view returns (RewardEpoch memory) {
        return epochs[currentEpoch > 0 ? currentEpoch - 1 : 0];
    }

    /**
     * @dev Emergency withdraw (onlyOwner) - for contract upgrades
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "RewardDistributor: zero address");
        vaultToken.safeTransfer(to, amount);
    }
}
