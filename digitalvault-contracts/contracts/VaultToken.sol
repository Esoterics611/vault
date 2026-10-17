// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title VaultToken
 * @dev VLTC - The native utility token for DigitalVault platform
 *
 * Token Economics:
 * - Total Supply: 1,000,000,000 VLTC (1 billion)
 * - Decimals: 18
 * - Features: Burnable, Pausable, Snapshot, Permit, Access Control
 *
 * Initial Distribution:
 * - 30% Presale (300M VLTC)
 * - 20% Airdrop Program (200M VLTC)
 * - 30% Liquidity Mining (300M VLTC - 4 year emission)
 * - 10% Storage Provider Rewards (100M VLTC - 4 year emission)
 * - 10% Treasury/Team (100M VLTC - 4 year linear vest)
 */
contract VaultToken is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Votes,
    ERC20Permit,
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant PRESALE_ALLOCATION = 300_000_000 * 10**18; // 30%
    uint256 public constant AIRDROP_ALLOCATION = 200_000_000 * 10**18; // 20%
    uint256 public constant LIQUIDITY_MINING_ALLOCATION = 300_000_000 * 10**18; // 30%
    uint256 public constant STORAGE_REWARDS_ALLOCATION = 100_000_000 * 10**18; // 10%
    uint256 public constant TREASURY_ALLOCATION = 100_000_000 * 10**18; // 10%

    address public presaleContract;
    address public airdropContract;
    address public rewardDistributor;
    address public treasury;

    event AllocationSet(string allocationType, address indexed contractAddress, uint256 amount);

    /**
     * @dev Constructor that sets up initial roles and mints total supply
     * @param admin Address that will have admin role
     */
    constructor(address admin)
        ERC20("VaultCoin", "VLTC")
        ERC20Permit("VaultCoin")
    {
        require(admin != address(0), "VaultToken: admin is zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Mint total supply to this contract, to be distributed according to tokenomics
        _mint(address(this), TOTAL_SUPPLY);
    }

    /**
     * @dev Set presale contract address and transfer allocation
     * @param _presaleContract Address of the presale contract
     */
    function setPresaleContract(address _presaleContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_presaleContract != address(0), "VaultToken: presale is zero address");
        require(presaleContract == address(0), "VaultToken: presale already set");

        presaleContract = _presaleContract;
        _transfer(address(this), presaleContract, PRESALE_ALLOCATION);

        emit AllocationSet("Presale", presaleContract, PRESALE_ALLOCATION);
    }

    /**
     * @dev Set airdrop contract address and transfer allocation
     * @param _airdropContract Address of the airdrop contract
     */
    function setAirdropContract(address _airdropContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_airdropContract != address(0), "VaultToken: airdrop is zero address");
        require(airdropContract == address(0), "VaultToken: airdrop already set");

        airdropContract = _airdropContract;
        _transfer(address(this), airdropContract, AIRDROP_ALLOCATION);

        emit AllocationSet("Airdrop", airdropContract, AIRDROP_ALLOCATION);
    }

    /**
     * @dev Set reward distributor address and transfer allocations
     * @param _rewardDistributor Address of the reward distributor contract
     */
    function setRewardDistributor(address _rewardDistributor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_rewardDistributor != address(0), "VaultToken: reward distributor is zero address");
        require(rewardDistributor == address(0), "VaultToken: reward distributor already set");

        rewardDistributor = _rewardDistributor;
        uint256 totalRewards = LIQUIDITY_MINING_ALLOCATION + STORAGE_REWARDS_ALLOCATION;
        _transfer(address(this), rewardDistributor, totalRewards);

        emit AllocationSet("RewardDistributor", rewardDistributor, totalRewards);
    }

    /**
     * @dev Set treasury address and transfer allocation
     * @param _treasury Address of the treasury
     */
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "VaultToken: treasury is zero address");
        require(treasury == address(0), "VaultToken: treasury already set");

        treasury = _treasury;
        _transfer(address(this), treasury, TREASURY_ALLOCATION);

        emit AllocationSet("Treasury", treasury, TREASURY_ALLOCATION);
    }


    /**
     * @dev Pauses all token transfers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses token transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Mint new tokens (for rewards distribution only)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
