// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ContentRegistry.sol";
import "./ReKeyRegistry.sol";

/**
 * @title Marketplace
 * @dev Content trading and access marketplace for DigitalVault
 *
 * Features:
 * - Full ownership transfers
 * - Access key sales (multiple)
 * - Timed access passes
 * - Platform fees and creator royalties
 * - Storage provider rewards
 */
contract Marketplace is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Week 6 - Custom errors for gas optimization
    error VaultTokenIsZeroAddress();
    error ContentRegistryIsZeroAddress();
    error ReKeyRegistryIsZeroAddress();
    error FeeCollectorIsZeroAddress();
    error PriceMustBeGreaterThanZero();
    error AccessDurationRequired();
    error ListingDoesNotExist();
    error CallerIsNotSeller();
    error ListingNotActive();
    error KfragHashRequired();
    error CapsuleHashRequired();
    error PublicKeyRequired();
    error CannotBuyOwnListing();
    error ListingSoldOut();
    error NoEarningsToWithdraw();
    error StorageProviderIsZeroAddress();
    error PlatformFeeTooHigh();
    error RoyaltyTooHigh();
    error StorageCutTooHigh();

    enum ListingType { FULL_OWNERSHIP, ACCESS_KEY, TIMED_ACCESS }

    struct Listing {
        uint256 contentId;
        address seller;
        uint256 price;              // In VLTC
        ListingType listingType;
        uint256 accessDuration;     // For timed access (in seconds)
        uint256 maxKeys;            // Max keys to sell (0 = unlimited)
        uint256 soldKeys;           // Keys sold so far
        bool isActive;
        uint256 listedAt;
    }

    IERC20 public vaultToken;
    ContentRegistry public contentRegistry;
    ReKeyRegistry public reKeyRegistry;  // Week 4 - NEW

    uint256 private _listingIdCounter;
    mapping(uint256 => Listing) private _listings;
    mapping(address => uint256) private _earnings;

    // Fee structure (in basis points, 1 bp = 0.01%)
    uint256 public platformFee = 250;           // 2.5%
    uint256 public creatorRoyalty = 500;        // 5%
    uint256 public storageProviderCut = 100;    // 1%

    address public feeCollector;
    address public storageProviderContract;

    // Events
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed contentId,
        address indexed seller,
        uint256 price,
        ListingType listingType
    );

    event ListingPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price,
        ListingType listingType
    );

    event ListingPurchasedWithPRE(
        uint256 indexed listingId,
        uint256 indexed contentId,
        address indexed buyer,
        uint256 price,
        bytes32 kfragHash
    );

    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event PriceUpdated(uint256 indexed listingId, uint256 oldPrice, uint256 newPrice);
    event EarningsWithdrawn(address indexed seller, uint256 amount);
    event FeesUpdated(uint256 platformFee, uint256 creatorRoyalty, uint256 storageProviderCut);

    constructor(
        address initialOwner,
        address _vaultToken,
        address _contentRegistry,
        address _reKeyRegistry,  // Week 4 - NEW
        address _feeCollector
    ) Ownable(initialOwner) {
        if (_vaultToken == address(0)) revert VaultTokenIsZeroAddress();
        if (_contentRegistry == address(0)) revert ContentRegistryIsZeroAddress();
        if (_reKeyRegistry == address(0)) revert ReKeyRegistryIsZeroAddress();
        if (_feeCollector == address(0)) revert FeeCollectorIsZeroAddress();

        vaultToken = IERC20(_vaultToken);
        contentRegistry = ContentRegistry(_contentRegistry);
        reKeyRegistry = ReKeyRegistry(_reKeyRegistry);  // Week 4 - NEW
        feeCollector = _feeCollector;
        _listingIdCounter = 1;
    }

    /**
     * @dev Create a new listing
     */
    function createListing(
        uint256 contentId,
        uint256 price,
        ListingType listingType,
        uint256 accessDuration,
        uint256 maxKeys
    ) external whenNotPaused nonReentrant returns (uint256) {
        if (price == 0) revert PriceMustBeGreaterThanZero();
        if (!contentRegistry.verifyOwnership(contentId, msg.sender)) {
            revert CallerIsNotSeller();
        }

        if (listingType == ListingType.TIMED_ACCESS) {
            if (accessDuration == 0) revert AccessDurationRequired();
        }

        uint256 listingId = _listingIdCounter++;

        Listing storage listing = _listings[listingId];
        listing.contentId = contentId;
        listing.seller = msg.sender;
        listing.price = price;
        listing.listingType = listingType;
        listing.accessDuration = accessDuration;
        listing.maxKeys = maxKeys;
        listing.soldKeys = 0;
        listing.isActive = true;
        listing.listedAt = block.timestamp;

        emit ListingCreated(listingId, contentId, msg.sender, price, listingType);

        return listingId;
    }

    /**
     * @dev Cancel a listing
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        if (!_listingExists(listingId)) revert ListingDoesNotExist();

        Listing storage listing = _listings[listingId];
        if (listing.seller != msg.sender) revert CallerIsNotSeller();
        if (!listing.isActive) revert ListingNotActive();

        listing.isActive = false;

        emit ListingCancelled(listingId, msg.sender);
    }

    /**
     * @dev Purchase a listing (Legacy - no PRE)
     */
    function purchaseListing(uint256 listingId, bytes memory newEncryptedKey)
        external
        whenNotPaused
        nonReentrant
    {
        _purchaseListing(listingId, newEncryptedKey, bytes32(0), bytes32(0), new bytes(0), 2, 3);
    }

    /**
     * @dev Purchase a PRE-enabled listing (Week 4 - NEW)
     * @param listingId The ID of the listing to purchase
     * @param newEncryptedKey New encrypted key for buyer
     * @param kfragHash Hash of re-encryption key fragments
     * @param newCapsuleHash Hash of re-encrypted capsule for buyer
     * @param threshold M in M-of-N threshold (e.g., 2)
     * @param totalShares N in M-of-N threshold (e.g., 3)
     */
    function purchaseListingWithPRE(
        uint256 listingId,
        bytes memory newEncryptedKey,
        bytes32 kfragHash,
        bytes32 newCapsuleHash,
        bytes memory newOwnerPublicKey,
        uint8 threshold,
        uint8 totalShares
    )
        external
        whenNotPaused
        nonReentrant
    {
        if (kfragHash == bytes32(0)) revert KfragHashRequired();
        if (newCapsuleHash == bytes32(0)) revert CapsuleHashRequired();
        if (newOwnerPublicKey.length == 0) revert PublicKeyRequired();

        _purchaseListing(
            listingId,
            newEncryptedKey,
            kfragHash,
            newCapsuleHash,
            newOwnerPublicKey,
            threshold,
            totalShares
        );
    }

    /**
     * @dev Internal purchase logic (Week 4 - refactored)
     */
    function _purchaseListing(
        uint256 listingId,
        bytes memory newEncryptedKey,
        bytes32 kfragHash,
        bytes32 newCapsuleHash,
        bytes memory newOwnerPublicKey,
        uint8 threshold,
        uint8 totalShares
    )
        private
    {
        if (!_listingExists(listingId)) revert ListingDoesNotExist();

        Listing storage listing = _listings[listingId];
        if (!listing.isActive) revert ListingNotActive();
        if (msg.sender == listing.seller) revert CannotBuyOwnListing();

        // Check if sold out (for limited key listings)
        if (listing.maxKeys > 0) {
            if (listing.soldKeys >= listing.maxKeys) revert ListingSoldOut();
        }

        // Handle payment distribution
        _distributePayment(listing);


        // Handle ownership transfer for full ownership listings
        if (listing.listingType == ListingType.FULL_OWNERSHIP) {
            // Determine if content uses PRE
            bool isPRE = contentRegistry.isContentPRE(listing.contentId);

            if (isPRE && kfragHash != bytes32(0)) {
                // PRE content transfer flow
                // Step 1: Create re-encryption grant
                reKeyRegistry.createGrant(
                    listing.contentId,
                    msg.sender,
                    kfragHash,
                    threshold,
                    totalShares
                );

                // Step 2: Transfer ownership with new PRE data
                contentRegistry.transferOwnershipWithPRE(
                    listing.contentId,
                    msg.sender,
                    newEncryptedKey,
                    listing.price,
                    newCapsuleHash,
                    newOwnerPublicKey
                );

                // Step 3: Mark grant as used
                reKeyRegistry.markGrantUsed(listing.contentId);

                emit ListingPurchasedWithPRE(
                    listingId,
                    listing.contentId,
                    msg.sender,
                    listing.price,
                    kfragHash
                );
            } else {
                // Legacy content transfer flow
                contentRegistry.transferOwnership(
                    listing.contentId,
                    msg.sender,
                    newEncryptedKey,
                    listing.price
                );

                emit ListingPurchased(listingId, msg.sender, listing.price, listing.listingType);
            }

            listing.isActive = false; // Full ownership can only be sold once
        } else {
            // Access key or timed access - no ownership transfer
            listing.soldKeys++;
            emit ListingPurchased(listingId, msg.sender, listing.price, listing.listingType);
        }
    }

    /**
     * @dev Update listing price
     */
    function updateListingPrice(uint256 listingId, uint256 newPrice) external {
        if (!_listingExists(listingId)) revert ListingDoesNotExist();
        if (newPrice == 0) revert PriceMustBeGreaterThanZero();

        Listing storage listing = _listings[listingId];
        if (listing.seller != msg.sender) revert CallerIsNotSeller();
        if (!listing.isActive) revert ListingNotActive();

        uint256 oldPrice = listing.price;
        listing.price = newPrice;

        emit PriceUpdated(listingId, oldPrice, newPrice);
    }

    /**
     * @dev Withdraw accumulated earnings
     */
    function withdrawEarnings() external nonReentrant {
        uint256 amount = _earnings[msg.sender];
        if (amount == 0) revert NoEarningsToWithdraw();

        _earnings[msg.sender] = 0;
        vaultToken.safeTransfer(msg.sender, amount);

        emit EarningsWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Get listing information
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        if (!_listingExists(listingId)) revert ListingDoesNotExist();
        return _listings[listingId];
    }

    /**
     * @dev Get earnings for an address
     */
    function getEarnings(address seller) external view returns (uint256) {
        return _earnings[seller];
    }

    /**
     * @dev Set storage provider contract address
     */
    function setStorageProviderContract(address _storageProviderContract) external onlyOwner {
        if (_storageProviderContract == address(0)) revert StorageProviderIsZeroAddress();
        storageProviderContract = _storageProviderContract;
    }

    /**
     * @dev Update fee structure (onlyOwner)
     */
    function updateFees(
        uint256 _platformFee,
        uint256 _creatorRoyalty,
        uint256 _storageProviderCut
    ) external onlyOwner {
        if (_platformFee > 1000) revert PlatformFeeTooHigh(); // Max 10%
        if (_creatorRoyalty > 1000) revert RoyaltyTooHigh(); // Max 10%
        if (_storageProviderCut > 500) revert StorageCutTooHigh(); // Max 5%

        platformFee = _platformFee;
        creatorRoyalty = _creatorRoyalty;
        storageProviderCut = _storageProviderCut;

        emit FeesUpdated(platformFee, creatorRoyalty, storageProviderCut);
    }

    /**
     * @dev Pause marketplace
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause marketplace
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // Internal functions
    function _listingExists(uint256 listingId) internal view returns (bool) {
        return listingId > 0 && listingId < _listingIdCounter;
    }

    /**
     * @dev Distribute payment for a purchase (Week 4 - extracted)
     */
    function _distributePayment(Listing storage listing) private {
        uint256 price = listing.price;

        // Transfer VLTC from buyer to this contract
        vaultToken.safeTransferFrom(msg.sender, address(this), price);

        // Calculate fees
        uint256 platformFeeAmount = (price * platformFee) / 10000;
        uint256 storageProviderAmount = (price * storageProviderCut) / 10000;
        uint256 sellerAmount = price - platformFeeAmount - storageProviderAmount;

        // Get content info to determine if royalty applies
        ContentRegistry.Content memory content = contentRegistry.getContentInfo(listing.contentId);

        if (content.creator != listing.seller) {
            // Secondary sale - apply royalty
            uint256 royaltyAmount = (price * creatorRoyalty) / 10000;
            sellerAmount -= royaltyAmount;
            _earnings[content.creator] += royaltyAmount;
        }

        // Distribute payments
        _earnings[listing.seller] += sellerAmount;
        vaultToken.safeTransfer(feeCollector, platformFeeAmount);

        if (storageProviderContract != address(0)) {
            vaultToken.safeTransfer(storageProviderContract, storageProviderAmount);
        } else {
            vaultToken.safeTransfer(feeCollector, storageProviderAmount);
        }
    }
}
