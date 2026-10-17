// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ReKeyRegistry
 * @notice Manages re-encryption key grants for secure content ownership transfer
 * @dev Stores kfrag hashes on-chain, actual kfrags stored off-chain in proxy network
 *
 * This contract enables Proxy Re-encryption (PRE) for DigitalVault:
 * 1. Seller creates grant with kfrag hash
 * 2. Buyer requests re-encryption from proxy network
 * 3. Proxies verify kfrag hash matches blockchain record
 * 4. After successful transfer, grant is marked as used
 *
 * Security features:
 * - Grants expire after 7 days (configurable)
 * - Seller can revoke unused grants
 * - Grants can only be used once
 * - ReentrancyGuard protects state-changing functions
 */
contract ReKeyRegistry is Ownable, ReentrancyGuard {
    // Week 6 - Custom errors for gas optimization
    error EmptyArrays();
    error TooManyGrants();
    error ArrayLengthMismatch();
    error GrantAlreadyExists();
    error InvalidBuyerAddress();
    error CannotGrantToSelf();
    error InvalidKfragHash();
    error ThresholdMustBePositive();
    error InvalidThreshold();
    error TooManyShares();
    error GrantDoesNotExist();
    error NotAuthorized();
    error GrantNotActive();
    error GrantAlreadyUsed();
    error GrantExpired();
    error InvalidMarketplaceAddress();
    error OnlySellerCanRevoke();
    error CannotRevokeUsedGrant();

    constructor() Ownable(msg.sender) {}

    /// @notice Re-encryption grant for content transfer
    struct ReKeyGrant {
        uint256 contentId;      // Content being transferred
        address seller;         // Original owner creating grant
        address buyer;          // Designated recipient
        bytes32 kfragHash;      // Hash of re-encryption key fragments
        uint8 threshold;        // M in M-of-N threshold (e.g., 2)
        uint8 totalShares;      // N in M-of-N threshold (e.g., 3)
        uint256 createdAt;      // Timestamp of grant creation
        uint256 expiresAt;      // Expiration timestamp
        bool isActive;          // False if revoked
        bool isUsed;            // True after successful transfer
    }

    /// @notice Default expiration period (7 days)
    uint256 public constant DEFAULT_EXPIRATION = 7 days;

    /// @notice Mapping from contentId to grant
    mapping(uint256 => ReKeyGrant) public grants;

    /// @notice Mapping to track grants by seller
    mapping(address => uint256[]) private grantsBySeller;

    /// @notice Mapping to track grants by buyer
    mapping(address => uint256[]) private grantsByBuyer;

    /// @notice Week 4 - Authorization: trusted marketplaces can mark grants as used
    mapping(address => bool) private _trustedMarketplaces;

    // Events
    event GrantCreated(
        uint256 indexed contentId,
        address indexed seller,
        address indexed buyer,
        bytes32 kfragHash,
        uint8 threshold,
        uint8 totalShares,
        uint256 expiresAt
    );

    event GrantUsed(
        uint256 indexed contentId,
        address indexed buyer,
        uint256 timestamp
    );

    event GrantRevoked(
        uint256 indexed contentId,
        address indexed seller,
        uint256 timestamp
    );

    event MarketplaceAuthorized(
        address indexed marketplace,
        bool trusted
    );

    /**
     * @notice Create a new re-encryption grant
     * @param _contentId Content ID being transferred
     * @param _buyer Address of the buyer (recipient)
     * @param _kfragHash Hash of the re-encryption key fragments
     * @param _threshold Number of fragments needed (M in M-of-N)
     * @param _totalShares Total number of fragments generated (N in M-of-N)
     */
    function createGrant(
        uint256 _contentId,
        address _buyer,
        bytes32 _kfragHash,
        uint8 _threshold,
        uint8 _totalShares
    ) external nonReentrant {
        _createGrant(_contentId, _buyer, _kfragHash, _threshold, _totalShares);
    }

    /**
     * @notice Create multiple grants in a single transaction
     * @param _contentIds Array of content IDs
     * @param _buyers Array of buyer addresses
     * @param _kfragHashes Array of kfrag hashes
     * @param _thresholds Array of thresholds
     * @param _totalShares Array of total shares
     * @dev Maximum 50 grants per batch to prevent gas issues
     */
    function batchCreateGrants(
        uint256[] calldata _contentIds,
        address[] calldata _buyers,
        bytes32[] calldata _kfragHashes,
        uint8[] calldata _thresholds,
        uint8[] calldata _totalShares
    ) external nonReentrant {
        uint256 length = _contentIds.length;

        // Validate array lengths match
        if (length == 0) revert EmptyArrays();
        if (length > 50) revert TooManyGrants(); // Gas limit protection
        if (_buyers.length != length ||
            _kfragHashes.length != length ||
            _thresholds.length != length ||
            _totalShares.length != length) {
            revert ArrayLengthMismatch();
        }

        // Create all grants
        for (uint256 i = 0; i < length; i++) {
            _createGrant(
                _contentIds[i],
                _buyers[i],
                _kfragHashes[i],
                _thresholds[i],
                _totalShares[i]
            );
        }
    }

    /**
     * @notice Internal helper to create a grant
     * @dev Extracted to be reused by both createGrant and batchCreateGrants
     */
    function _createGrant(
        uint256 _contentId,
        address _buyer,
        bytes32 _kfragHash,
        uint8 _threshold,
        uint8 _totalShares
    ) private {
        // Validation - allow new grant if old one is used or doesn't exist
        ReKeyGrant storage existingGrant = grants[_contentId];
        if (existingGrant.contentId != 0 && !existingGrant.isUsed) {
            revert GrantAlreadyExists();
        }
        if (_buyer == address(0)) revert InvalidBuyerAddress();
        if (_buyer == msg.sender) revert CannotGrantToSelf();
        if (_kfragHash == bytes32(0)) revert InvalidKfragHash();
        if (_threshold == 0) revert ThresholdMustBePositive();
        if (_threshold > _totalShares) revert InvalidThreshold();
        if (_totalShares > 10) revert TooManyShares(); // Reasonable limit

        uint256 expiresAt = block.timestamp + DEFAULT_EXPIRATION;

        // Create grant
        grants[_contentId] = ReKeyGrant({
            contentId: _contentId,
            seller: msg.sender,
            buyer: _buyer,
            kfragHash: _kfragHash,
            threshold: _threshold,
            totalShares: _totalShares,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            isActive: true,
            isUsed: false
        });

        // Track grants
        grantsBySeller[msg.sender].push(_contentId);
        grantsByBuyer[_buyer].push(_contentId);

        emit GrantCreated(
            _contentId,
            msg.sender,
            _buyer,
            _kfragHash,
            _threshold,
            _totalShares,
            expiresAt
        );
    }

    /**
     * @notice Mark a grant as used after successful transfer
     * @param _contentId Content ID of the grant
     * @dev Only the buyer or trusted marketplace can mark a grant as used
     */
    function markGrantUsed(uint256 _contentId) external nonReentrant {
        ReKeyGrant storage grant = grants[_contentId];

        // Validation
        if (grant.contentId == 0) revert GrantDoesNotExist();
        if (grant.buyer != msg.sender && !_trustedMarketplaces[msg.sender]) {
            revert NotAuthorized();
        }
        if (!grant.isActive) revert GrantNotActive();
        if (grant.isUsed) revert GrantAlreadyUsed();
        if (block.timestamp >= grant.expiresAt) revert GrantExpired();

        // Mark as used
        grant.isUsed = true;

        emit GrantUsed(_contentId, grant.buyer, block.timestamp);
    }

    /**
     * @notice Authorize/deauthorize a marketplace to mark grants as used (Week 4 - NEW)
     * @param marketplace Address of the marketplace contract
     * @param trusted True to authorize, false to revoke
     */
    function setTrustedMarketplace(address marketplace, bool trusted) external onlyOwner {
        if (marketplace == address(0)) revert InvalidMarketplaceAddress();
        _trustedMarketplaces[marketplace] = trusted;
        emit MarketplaceAuthorized(marketplace, trusted);
    }

    /**
     * @notice Check if a marketplace is trusted
     * @param marketplace Address to check
     * @return bool True if marketplace is trusted
     */
    function isTrustedMarketplace(address marketplace) external view returns (bool) {
        return _trustedMarketplaces[marketplace];
    }

    /**
     * @notice Revoke an unused grant
     * @param _contentId Content ID of the grant to revoke
     * @dev Only the seller can revoke, and only if not yet used
     */
    function revokeGrant(uint256 _contentId) external nonReentrant {
        ReKeyGrant storage grant = grants[_contentId];

        // Validation
        if (grant.contentId == 0) revert GrantDoesNotExist();
        if (grant.seller != msg.sender) revert OnlySellerCanRevoke();
        if (!grant.isActive) revert GrantNotActive();
        if (grant.isUsed) revert CannotRevokeUsedGrant();

        // Revoke
        grant.isActive = false;

        emit GrantRevoked(_contentId, msg.sender, block.timestamp);
    }

    /**
     * @notice Check if a grant is currently active and valid
     * @param _contentId Content ID to check
     * @return bool True if grant exists, is active, not used, and not expired
     */
    function isGrantActive(uint256 _contentId) external view returns (bool) {
        ReKeyGrant memory grant = grants[_contentId];

        return grant.contentId != 0 &&     // Grant exists
               grant.isActive &&            // Not revoked
               !grant.isUsed &&             // Not consumed
               block.timestamp < grant.expiresAt;  // Not expired
    }

    /**
     * @notice Get complete grant information
     * @param _contentId Content ID to query
     * @return grant The complete ReKeyGrant struct
     */
    function verifyGrant(uint256 _contentId)
        external
        view
        returns (ReKeyGrant memory grant)
    {
        return grants[_contentId];
    }

    /**
     * @notice Get grant details (individual fields)
     * @param _contentId Content ID to query
     * @return seller Address of seller
     * @return buyer Address of buyer
     * @return kfragHash Hash of key fragments
     * @return threshold M in M-of-N
     * @return totalShares N in M-of-N
     * @return expiresAt Expiration timestamp
     * @return isActive Whether grant is active
     * @return isUsed Whether grant has been used
     */
    function getGrant(uint256 _contentId)
        external
        view
        returns (
            address seller,
            address buyer,
            bytes32 kfragHash,
            uint8 threshold,
            uint8 totalShares,
            uint256 expiresAt,
            bool isActive,
            bool isUsed
        )
    {
        ReKeyGrant memory grant = grants[_contentId];
        return (
            grant.seller,
            grant.buyer,
            grant.kfragHash,
            grant.threshold,
            grant.totalShares,
            grant.expiresAt,
            grant.isActive,
            grant.isUsed
        );
    }

    /**
     * @notice Get all grant IDs for a seller
     * @param _seller Address of the seller
     * @return uint256[] Array of content IDs
     */
    function getGrantsBySeller(address _seller)
        external
        view
        returns (uint256[] memory)
    {
        return grantsBySeller[_seller];
    }

    /**
     * @notice Get all grant IDs for a buyer
     * @param _buyer Address of the buyer
     * @return uint256[] Array of content IDs
     */
    function getGrantsByBuyer(address _buyer)
        external
        view
        returns (uint256[] memory)
    {
        return grantsByBuyer[_buyer];
    }

    /**
     * @notice Check if grant exists
     * @param _contentId Content ID to check
     * @return bool True if grant exists
     */
    function grantExists(uint256 _contentId) external view returns (bool) {
        return grants[_contentId].contentId != 0;
    }

    /**
     * @notice Verify kfrag hash matches recorded hash
     * @param _contentId Content ID
     * @param _kfragHash Hash to verify
     * @return bool True if hash matches
     */
    function verifyKfragHash(uint256 _contentId, bytes32 _kfragHash)
        external
        view
        returns (bool)
    {
        return grants[_contentId].kfragHash == _kfragHash;
    }

    /**
     * @notice Get only active grants for a buyer
     * @param _buyer Address of the buyer
     * @return uint256[] Array of content IDs with active grants
     * @dev Filters out expired, used, or revoked grants
     */
    function getActiveGrantsByBuyer(address _buyer)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory allGrants = grantsByBuyer[_buyer];
        uint256 activeCount = 0;

        // First pass: count active grants
        for (uint256 i = 0; i < allGrants.length; i++) {
            ReKeyGrant memory grant = grants[allGrants[i]];
            if (
                grant.isActive &&
                !grant.isUsed &&
                block.timestamp < grant.expiresAt
            ) {
                activeCount++;
            }
        }

        // Second pass: populate result array
        uint256[] memory activeGrants = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allGrants.length; i++) {
            ReKeyGrant memory grant = grants[allGrants[i]];
            if (
                grant.isActive &&
                !grant.isUsed &&
                block.timestamp < grant.expiresAt
            ) {
                activeGrants[index] = allGrants[i];
                index++;
            }
        }

        return activeGrants;
    }

    /**
     * @notice Get only active grants for a seller
     * @param _seller Address of the seller
     * @return uint256[] Array of content IDs with active grants
     * @dev Filters out expired, used, or revoked grants
     */
    function getActiveGrantsBySeller(address _seller)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory allGrants = grantsBySeller[_seller];
        uint256 activeCount = 0;

        // First pass: count active grants
        for (uint256 i = 0; i < allGrants.length; i++) {
            ReKeyGrant memory grant = grants[allGrants[i]];
            if (
                grant.isActive &&
                !grant.isUsed &&
                block.timestamp < grant.expiresAt
            ) {
                activeCount++;
            }
        }

        // Second pass: populate result array
        uint256[] memory activeGrants = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allGrants.length; i++) {
            ReKeyGrant memory grant = grants[allGrants[i]];
            if (
                grant.isActive &&
                !grant.isUsed &&
                block.timestamp < grant.expiresAt
            ) {
                activeGrants[index] = allGrants[i];
                index++;
            }
        }

        return activeGrants;
    }
}
