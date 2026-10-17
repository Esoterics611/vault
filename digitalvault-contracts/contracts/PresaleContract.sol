// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PresaleContract
 * @dev Manages VLTC token presale with vesting
 *
 * Round 1 (Private): 100M VLTC at $0.001, max $10k per wallet
 * Round 2 (Public): 200M VLTC at $0.002, max $5k per wallet
 * Cliff: 3 months for private, 1 month for public
 * Vesting: 12 months linear for private, 9 months for public
 */
contract PresaleContract is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct PresaleRound {
        uint256 roundNumber;
        uint256 startTime;
        uint256 endTime;
        uint256 pricePerToken;      // In wei (ETH)
        uint256 minPurchase;
        uint256 maxPurchase;
        uint256 totalAllocation;
        uint256 soldAmount;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool isActive;
    }

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
    }

    IERC20 public vaultToken;

    mapping(uint256 => PresaleRound) public presaleRounds;
    mapping(address => mapping(uint256 => uint256)) public purchases; // buyer => round => amount
    mapping(address => VestingSchedule) public vestingSchedules;

    uint256 public currentRound;
    address public fundsCollector;

    event RoundCreated(uint256 indexed roundNumber, uint256 allocation, uint256 pricePerToken);
    event TokensPurchased(address indexed buyer, uint256 indexed roundNumber, uint256 amount, uint256 cost);
    event TokensClaimed(address indexed buyer, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);

    constructor(
        address initialOwner,
        address _vaultToken,
        address _fundsCollector
    ) Ownable(initialOwner) {
        require(_vaultToken != address(0), "PresaleContract: vault token is zero address");
        require(_fundsCollector != address(0), "PresaleContract: funds collector is zero address");

        vaultToken = IERC20(_vaultToken);
        fundsCollector = _fundsCollector;
        currentRound = 0;
    }

    /**
     * @dev Create a presale round
     */
    function createPresaleRound(
        uint256 startTime,
        uint256 endTime,
        uint256 pricePerToken,
        uint256 minPurchase,
        uint256 maxPurchase,
        uint256 totalAllocation,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {
        require(startTime < endTime, "PresaleContract: invalid time range");
        require(pricePerToken > 0, "PresaleContract: invalid price");
        require(totalAllocation > 0, "PresaleContract: invalid allocation");

        currentRound++;

        PresaleRound storage round = presaleRounds[currentRound];
        round.roundNumber = currentRound;
        round.startTime = startTime;
        round.endTime = endTime;
        round.pricePerToken = pricePerToken;
        round.minPurchase = minPurchase;
        round.maxPurchase = maxPurchase;
        round.totalAllocation = totalAllocation;
        round.soldAmount = 0;
        round.cliffDuration = cliffDuration;
        round.vestingDuration = vestingDuration;
        round.isActive = true;

        emit RoundCreated(currentRound, totalAllocation, pricePerToken);
    }

    /**
     * @dev Buy tokens in presale
     */
    function buyTokens(uint256 roundNumber) external payable whenNotPaused nonReentrant {
        PresaleRound storage round = presaleRounds[roundNumber];
        require(round.isActive, "PresaleContract: round not active");
        require(block.timestamp >= round.startTime, "PresaleContract: round not started");
        require(block.timestamp <= round.endTime, "PresaleContract: round ended");

        uint256 tokenAmount = (msg.value * 10**18) / round.pricePerToken;
        require(tokenAmount >= round.minPurchase, "PresaleContract: below minimum purchase");

        uint256 totalPurchased = purchases[msg.sender][roundNumber] + tokenAmount;
        require(totalPurchased <= round.maxPurchase, "PresaleContract: exceeds maximum purchase");
        require(round.soldAmount + tokenAmount <= round.totalAllocation, "PresaleContract: round sold out");

        purchases[msg.sender][roundNumber] += tokenAmount;
        round.soldAmount += tokenAmount;

        // Update vesting schedule
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        if (schedule.totalAmount == 0) {
            schedule.startTime = round.endTime; // Vesting starts after round ends
            schedule.cliffDuration = round.cliffDuration;
            schedule.vestingDuration = round.vestingDuration;
        }
        schedule.totalAmount += tokenAmount;

        emit TokensPurchased(msg.sender, roundNumber, tokenAmount, msg.value);
    }

    /**
     * @dev Claim vested tokens
     */
    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "PresaleContract: no tokens to claim");

        uint256 claimable = calculateClaimableAmount(msg.sender);
        require(claimable > 0, "PresaleContract: no tokens available to claim");

        schedule.claimedAmount += claimable;
        vaultToken.safeTransfer(msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    /**
     * @dev Calculate claimable token amount
     */
    function calculateClaimableAmount(address buyer) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[buyer];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;

        // Before cliff, nothing is claimable
        if (block.timestamp < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = schedule.startTime + schedule.cliffDuration + schedule.vestingDuration;

        // After vesting period, all tokens are claimable
        if (block.timestamp >= vestingEnd) {
            return schedule.totalAmount - schedule.claimedAmount;
        }

        // During vesting, calculate linear unlock
        uint256 timeVested = block.timestamp - cliffEnd;
        uint256 totalVested = (schedule.totalAmount * timeVested) / schedule.vestingDuration;

        return totalVested - schedule.claimedAmount;
    }

    /**
     * @dev Get vesting schedule for a buyer
     */
    function getVestingSchedule(address buyer) external view returns (VestingSchedule memory) {
        return vestingSchedules[buyer];
    }

    /**
     * @dev Withdraw presale funds
     */
    function withdrawPresaleFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "PresaleContract: no funds to withdraw");

        (bool success, ) = fundsCollector.call{value: balance}("");
        require(success, "PresaleContract: withdrawal failed");

        emit FundsWithdrawn(fundsCollector, balance);
    }

    /**
     * @dev Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev End a round early
     */
    function endRound(uint256 roundNumber) external onlyOwner {
        presaleRounds[roundNumber].isActive = false;
    }
}
