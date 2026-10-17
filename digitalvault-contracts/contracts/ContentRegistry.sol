// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ContentRegistry
 * @dev Core content management and ownership registry for DigitalVault
 *
 * This contract handles:
 * - Content registration with IPFS hashes
 * - Ownership tracking (creator vs current owner)
 * - Access model management
 * - View count analytics
 * - Ownership transfers
 */
contract ContentRegistry is Ownable, ReentrancyGuard, Pausable {
    // Week 6 - Custom errors for gas optimization (save ~500-1k gas per error)
    error InvalidContentHash();
    error InvalidMetadataHash();
    error EncryptedKeyRequired();
    error InvalidFileSize();
    error ContentDoesNotExist();
    error NewOwnerIsZeroAddress();
    error CallerNotAuthorized();
    error ContentNotActive();
    error UsePRETransferFunction();
    error CapsuleHashRequired();
    error PublicKeyRequired();
    error ContentDoesNotUsePRE();
    error CallerNotOwner();
    error ContentAlreadyInactive();
    error InvalidCapsuleHash();
    error InvalidPublicKey();
    error MarketplaceIsZeroAddress();
    enum ContentType { POETRY, JOURNAL, PHOTO, VIDEO }
    enum AccessModel { PRIVATE, PREVIEW_ALLOWED, PAY_PER_ACCESS, FOR_SALE }

    struct Content {
        bytes32 contentHash;        // IPFS hash of encrypted content (slot 1)
        bytes32 metadataHash;       // IPFS hash of metadata JSON (slot 2)
        address owner;              // Current owner (slot 3: 20 bytes)
        // Week 6 - Packed flags in same slot as owner (saves 2 storage slots!)
        ContentType contentType;    // Type of content (1 byte)
        AccessModel accessModel;    // How content can be accessed (1 byte)
        bool isActive;              // Soft delete flag (1 byte)
        uint8 capsuleVersion;       // PRE version for future upgrades (1 = Umbral) (1 byte)
        bool usesPRE;               // True if content uses PRE, false if legacy (1 byte)
        // 7 bytes free in slot 3
        address creator;            // Original creator (immutable) (slot 4: 20 bytes)
        // 12 bytes free in slot 4
        uint256 createdAt;          // Timestamp (slot 5)
        uint256 fileSize;           // Size in bytes (slot 6)
        bytes encryptedKey;         // Encrypted AES key (dynamic, separate slots)
        uint256 viewCount;          // Number of views (slot N)

        // PRE (Proxy Re-encryption) fields - Week 3 upgrade
        bytes32 capsuleHash;        // Hash of PRE capsule (slot N+1)
        bytes ownerPublicKey;       // Owner's public key for PRE (dynamic, separate slots)
    }

    // Content ID counter
    uint256 private _contentIdCounter;

    // Mapping from content ID to Content struct
    mapping(uint256 => Content) private _contents;

    // Mapping from creator address to their content IDs
    mapping(address => uint256[]) private _creatorContents;

    // Mapping from owner address to their content IDs
    mapping(address => uint256[]) private _ownerContents;

    // Week 4 - Authorization: trusted marketplaces can transfer on behalf of owners
    mapping(address => bool) private _trustedMarketplaces;

    // Maximum file size (100 MB)
    uint256 public constant MAX_FILE_SIZE = 100 * 1024 * 1024;

    // Events
    event ContentRegistered(
        uint256 indexed contentId,
        address indexed creator,
        ContentType contentType,
        uint256 timestamp
    );

    event ContentOwnershipTransferred(
        uint256 indexed contentId,
        address indexed from,
        address indexed to,
        uint256 price
    );

    event ContentOwnershipTransferredWithPRE(
        uint256 indexed contentId,
        address indexed from,
        address indexed to,
        uint256 price,
        bytes32 newCapsuleHash,
        bytes newOwnerPublicKey
    );

    event AccessModelUpdated(
        uint256 indexed contentId,
        AccessModel oldModel,
        AccessModel newModel
    );

    event ContentDeactivated(uint256 indexed contentId, address indexed owner);
    event ViewCountIncremented(uint256 indexed contentId, uint256 newCount);
    event MarketplaceAuthorized(address indexed marketplace, bool trusted);

    constructor(address initialOwner) Ownable(initialOwner) {
        _contentIdCounter = 1; // Start from 1
    }

    /**
     * @dev Register new content on the platform (Legacy - no PRE)
     * @param contentHash IPFS hash of the encrypted content
     * @param metadataHash IPFS hash of the metadata
     * @param encryptedKey Encrypted AES key
     * @param fileSize Size of the file in bytes
     * @param contentType Type of content
     * @param accessModel Initial access model
     * @return contentId The ID of the newly registered content
     */
    function registerContent(
        bytes32 contentHash,
        bytes32 metadataHash,
        bytes memory encryptedKey,
        uint256 fileSize,
        ContentType contentType,
        AccessModel accessModel
    ) external whenNotPaused nonReentrant returns (uint256) {
        return _registerContent(
            contentHash,
            metadataHash,
            encryptedKey,
            fileSize,
            contentType,
            accessModel,
            bytes32(0),      // No capsuleHash (legacy)
            new bytes(0),    // No ownerPublicKey (legacy)
            0,               // capsuleVersion = 0 (legacy)
            false            // usesPRE = false
        );
    }

    /**
     * @dev Register new content with PRE support (Week 3 - NEW)
     * @param contentHash IPFS hash of the encrypted content
     * @param metadataHash IPFS hash of the metadata
     * @param encryptedKey Encrypted AES key (for backwards compatibility)
     * @param fileSize Size of the file in bytes
     * @param contentType Type of content
     * @param accessModel Initial access model
     * @param capsuleHash Hash of the PRE capsule
     * @param ownerPublicKey Owner's public key for PRE
     * @return contentId The ID of the newly registered content
     */
    function registerContentWithPRE(
        bytes32 contentHash,
        bytes32 metadataHash,
        bytes memory encryptedKey,
        uint256 fileSize,
        ContentType contentType,
        AccessModel accessModel,
        bytes32 capsuleHash,
        bytes memory ownerPublicKey
    ) external whenNotPaused nonReentrant returns (uint256) {
        if (capsuleHash == bytes32(0)) revert CapsuleHashRequired();
        if (ownerPublicKey.length == 0) revert PublicKeyRequired();

        return _registerContent(
            contentHash,
            metadataHash,
            encryptedKey,
            fileSize,
            contentType,
            accessModel,
            capsuleHash,
            ownerPublicKey,
            1,              // capsuleVersion = 1 (Umbral)
            true            // usesPRE = true
        );
    }

    /**
     * @dev Internal helper for content registration
     */
    function _registerContent(
        bytes32 contentHash,
        bytes32 metadataHash,
        bytes memory encryptedKey,
        uint256 fileSize,
        ContentType contentType,
        AccessModel accessModel,
        bytes32 capsuleHash,
        bytes memory ownerPublicKey,
        uint8 capsuleVersion,
        bool usesPRE
    ) private returns (uint256) {
        if (contentHash == bytes32(0)) revert InvalidContentHash();
        if (metadataHash == bytes32(0)) revert InvalidMetadataHash();
        if (encryptedKey.length == 0) revert EncryptedKeyRequired();
        if (fileSize == 0 || fileSize > MAX_FILE_SIZE) revert InvalidFileSize();

        uint256 contentId = _contentIdCounter++;

        Content storage content = _contents[contentId];
        content.contentHash = contentHash;
        content.metadataHash = metadataHash;
        content.owner = msg.sender;
        content.creator = msg.sender;
        content.createdAt = block.timestamp;
        content.fileSize = fileSize;
        content.contentType = contentType;
        content.accessModel = accessModel;
        content.encryptedKey = encryptedKey;
        content.viewCount = 0;
        content.isActive = true;

        // PRE fields
        content.capsuleHash = capsuleHash;
        content.ownerPublicKey = ownerPublicKey;
        content.capsuleVersion = capsuleVersion;
        content.usesPRE = usesPRE;

        _creatorContents[msg.sender].push(contentId);
        _ownerContents[msg.sender].push(contentId);

        emit ContentRegistered(contentId, msg.sender, contentType, block.timestamp);

        return contentId;
    }

    /**
     * @dev Transfer ownership of content (Legacy - no PRE)
     * @param contentId ID of the content
     * @param newOwner Address of the new owner
     * @param newEncryptedKey New encrypted key for the new owner
     * @param price Price of the transfer (for event logging)
     */
    function transferOwnership(
        uint256 contentId,
        address newOwner,
        bytes memory newEncryptedKey,
        uint256 price
    ) external nonReentrant {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();
        if (newOwner == address(0)) revert NewOwnerIsZeroAddress();
        if (newEncryptedKey.length == 0) revert EncryptedKeyRequired();

        Content storage content = _contents[contentId];
        if (content.owner != msg.sender && !_trustedMarketplaces[msg.sender]) {
            revert CallerNotAuthorized();
        }
        if (!content.isActive) revert ContentNotActive();
        if (content.usesPRE) revert UsePRETransferFunction();

        address previousOwner = content.owner;
        content.owner = newOwner;
        content.encryptedKey = newEncryptedKey;

        // Update ownership mappings
        _removeFromOwnerContents(previousOwner, contentId);
        _ownerContents[newOwner].push(contentId);

        emit ContentOwnershipTransferred(contentId, previousOwner, newOwner, price);
    }

    /**
     * @dev Transfer ownership of PRE-enabled content (Week 3 - NEW)
     * @param contentId ID of the content
     * @param newOwner Address of the new owner
     * @param newEncryptedKey New encrypted key (for backwards compatibility)
     * @param price Price of the transfer (for event logging)
     * @param newCapsuleHash Hash of re-encrypted capsule for new owner
     * @param newOwnerPublicKey New owner's public key
     */
    function transferOwnershipWithPRE(
        uint256 contentId,
        address newOwner,
        bytes memory newEncryptedKey,
        uint256 price,
        bytes32 newCapsuleHash,
        bytes memory newOwnerPublicKey
    ) external nonReentrant {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();
        if (newOwner == address(0)) revert NewOwnerIsZeroAddress();
        if (newEncryptedKey.length == 0) revert EncryptedKeyRequired();
        if (newCapsuleHash == bytes32(0)) revert CapsuleHashRequired();
        if (newOwnerPublicKey.length == 0) revert PublicKeyRequired();

        Content storage content = _contents[contentId];
        if (content.owner != msg.sender && !_trustedMarketplaces[msg.sender]) {
            revert CallerNotAuthorized();
        }
        if (!content.isActive) revert ContentNotActive();
        if (!content.usesPRE) revert ContentDoesNotUsePRE();

        address previousOwner = content.owner;

        // Update ownership and PRE fields
        content.owner = newOwner;
        content.encryptedKey = newEncryptedKey;
        content.capsuleHash = newCapsuleHash;
        content.ownerPublicKey = newOwnerPublicKey;

        // Update ownership mappings
        _removeFromOwnerContents(previousOwner, contentId);
        _ownerContents[newOwner].push(contentId);

        emit ContentOwnershipTransferredWithPRE(
            contentId,
            previousOwner,
            newOwner,
            price,
            newCapsuleHash,
            newOwnerPublicKey
        );
    }

    /**
     * @dev Update access model for content
     * @param contentId ID of the content
     * @param newAccessModel New access model
     */
    function updateAccessModel(uint256 contentId, AccessModel newAccessModel) external {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();

        Content storage content = _contents[contentId];
        if (content.owner != msg.sender) revert CallerNotOwner();
        if (!content.isActive) revert ContentNotActive();

        AccessModel oldModel = content.accessModel;
        content.accessModel = newAccessModel;

        emit AccessModelUpdated(contentId, oldModel, newAccessModel);
    }

    /**
     * @dev Deactivate content (soft delete)
     * @param contentId ID of the content
     */
    function deactivateContent(uint256 contentId) external {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();

        Content storage content = _contents[contentId];
        if (content.owner != msg.sender) revert CallerNotOwner();
        if (!content.isActive) revert ContentAlreadyInactive();

        content.isActive = false;

        emit ContentDeactivated(contentId, msg.sender);
    }

    /**
     * @dev Increment view count for analytics
     * @param contentId ID of the content
     */
    function incrementViewCount(uint256 contentId) external {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();

        Content storage content = _contents[contentId];
        if (!content.isActive) revert ContentNotActive();

        content.viewCount++;

        emit ViewCountIncremented(contentId, content.viewCount);
    }

    /**
     * @dev Verify ownership of content
     * @param contentId ID of the content
     * @param potentialOwner Address to verify
     * @return bool True if the address is the owner
     */
    function verifyOwnership(uint256 contentId, address potentialOwner) external view returns (bool) {
        if (!_contentExists(contentId)) return false;
        return _contents[contentId].owner == potentialOwner;
    }

    /**
     * @dev Get content information
     * @param contentId ID of the content
     * @return Content struct
     */
    function getContentInfo(uint256 contentId) external view returns (Content memory) {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();
        return _contents[contentId];
    }

    /**
     * @dev Get all content IDs created by a specific address
     * @param creator Address of the creator
     * @return Array of content IDs
     */
    function getCreatorContents(address creator) external view returns (uint256[] memory) {
        return _creatorContents[creator];
    }

    /**
     * @dev Get all content IDs owned by a specific address
     * @param owner Address of the owner
     * @return Array of content IDs
     */
    function getOwnerContents(address owner) external view returns (uint256[] memory) {
        return _ownerContents[owner];
    }

    /**
     * @dev Pause contract (emergency only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Authorize/deauthorize a marketplace to transfer content on behalf of owners (Week 4 - NEW)
     * @param marketplace Address of the marketplace contract
     * @param trusted True to authorize, false to revoke
     */
    function setTrustedMarketplace(address marketplace, bool trusted) external onlyOwner {
        if (marketplace == address(0)) revert MarketplaceIsZeroAddress();
        _trustedMarketplaces[marketplace] = trusted;
        emit MarketplaceAuthorized(marketplace, trusted);
    }

    /**
     * @dev Check if a marketplace is trusted
     * @param marketplace Address to check
     * @return bool True if marketplace is trusted
     */
    function isTrustedMarketplace(address marketplace) external view returns (bool) {
        return _trustedMarketplaces[marketplace];
    }

    // PRE Helper Functions (Week 3 - NEW)

    /**
     * @dev Check if content uses PRE
     * @param contentId ID of the content
     * @return bool True if content uses PRE
     */
    function isContentPRE(uint256 contentId) external view returns (bool) {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();
        return _contents[contentId].usesPRE;
    }

    /**
     * @dev Get PRE capsule information
     * @param contentId ID of the content
     * @return capsuleHash Hash of the capsule
     * @return ownerPublicKey Owner's public key
     * @return capsuleVersion PRE version
     */
    function getPREInfo(uint256 contentId)
        external
        view
        returns (
            bytes32 capsuleHash,
            bytes memory ownerPublicKey,
            uint8 capsuleVersion
        )
    {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();
        Content memory content = _contents[contentId];
        if (!content.usesPRE) revert ContentDoesNotUsePRE();

        return (
            content.capsuleHash,
            content.ownerPublicKey,
            content.capsuleVersion
        );
    }

    /**
     * @dev Update capsule hash (for re-encryption operations)
     * @param contentId ID of the content
     * @param newCapsuleHash New capsule hash after re-encryption
     */
    function updateCapsuleHash(uint256 contentId, bytes32 newCapsuleHash) external {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();
        if (newCapsuleHash == bytes32(0)) revert InvalidCapsuleHash();

        Content storage content = _contents[contentId];
        if (content.owner != msg.sender) revert CallerNotOwner();
        if (!content.usesPRE) revert ContentDoesNotUsePRE();
        if (!content.isActive) revert ContentNotActive();

        content.capsuleHash = newCapsuleHash;
    }

    /**
     * @dev Update owner public key
     * @param contentId ID of the content
     * @param newPublicKey New public key
     */
    function updateOwnerPublicKey(uint256 contentId, bytes memory newPublicKey) external {
        if (!_contentExists(contentId)) revert ContentDoesNotExist();
        if (newPublicKey.length == 0) revert InvalidPublicKey();

        Content storage content = _contents[contentId];
        if (content.owner != msg.sender) revert CallerNotOwner();
        if (!content.usesPRE) revert ContentDoesNotUsePRE();
        if (!content.isActive) revert ContentNotActive();

        content.ownerPublicKey = newPublicKey;
    }

    /**
     * @dev Get all PRE-enabled content IDs for an owner
     * @param owner Address of the owner
     * @return Array of content IDs that use PRE
     */
    function getPREContentsByOwner(address owner) external view returns (uint256[] memory) {
        uint256[] memory allContents = _ownerContents[owner];
        uint256 preCount = 0;

        // First pass: count PRE contents
        for (uint256 i = 0; i < allContents.length; i++) {
            if (_contents[allContents[i]].usesPRE && _contents[allContents[i]].isActive) {
                preCount++;
            }
        }

        // Second pass: populate result
        uint256[] memory preContents = new uint256[](preCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allContents.length; i++) {
            if (_contents[allContents[i]].usesPRE && _contents[allContents[i]].isActive) {
                preContents[index] = allContents[i];
                index++;
            }
        }

        return preContents;
    }

    // Internal functions

    function _contentExists(uint256 contentId) internal view returns (bool) {
        return contentId > 0 && contentId < _contentIdCounter;
    }

    function _removeFromOwnerContents(address owner, uint256 contentId) internal {
        uint256[] storage contents = _ownerContents[owner];
        for (uint256 i = 0; i < contents.length; i++) {
            if (contents[i] == contentId) {
                contents[i] = contents[contents.length - 1];
                contents.pop();
                break;
            }
        }
    }
}
