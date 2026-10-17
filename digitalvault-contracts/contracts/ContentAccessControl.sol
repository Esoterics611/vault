// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ContentAccessControl
 * @dev Manages content access permissions and tokens
 */
contract ContentAccessControl is Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    enum AccessType { PREVIEW, FULL_ACCESS, TIMED_ACCESS }

    struct AccessGrant {
        uint256 contentId;
        address grantee;
        uint256 grantedAt;
        uint256 expiresAt;
        AccessType accessType;
        bool isActive;
    }

    mapping(uint256 => mapping(address => AccessGrant)) public accessGrants;
    mapping(bytes32 => bool) public usedTokens;

    event AccessGranted(
        uint256 indexed contentId,
        address indexed grantee,
        AccessType accessType,
        uint256 expiresAt
    );

    event AccessRevoked(uint256 indexed contentId, address indexed grantee);
    event AccessExtended(uint256 indexed contentId, address indexed grantee, uint256 newExpiresAt);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Grant access to content
     */
    function grantAccess(
        uint256 contentId,
        address user,
        AccessType accessType,
        uint256 duration
    ) external {
        require(user != address(0), "AccessControl: zero address");

        uint256 expiresAt = duration > 0 ? block.timestamp + duration : type(uint256).max;

        AccessGrant storage grant = accessGrants[contentId][user];
        grant.contentId = contentId;
        grant.grantee = user;
        grant.grantedAt = block.timestamp;
        grant.expiresAt = expiresAt;
        grant.accessType = accessType;
        grant.isActive = true;

        emit AccessGranted(contentId, user, accessType, expiresAt);
    }

    /**
     * @dev Revoke access
     */
    function revokeAccess(uint256 contentId, address user) external {
        AccessGrant storage grant = accessGrants[contentId][user];
        require(grant.isActive, "AccessControl: access not active");

        grant.isActive = false;

        emit AccessRevoked(contentId, user);
    }

    /**
     * @dev Verify if user has access
     */
    function verifyAccess(uint256 contentId, address user)
        external
        view
        returns (bool hasAccess, AccessType accessType)
    {
        AccessGrant memory grant = accessGrants[contentId][user];

        if (!grant.isActive) {
            return (false, AccessType.PREVIEW);
        }

        if (block.timestamp > grant.expiresAt) {
            return (false, AccessType.PREVIEW);
        }

        return (true, grant.accessType);
    }

    /**
     * @dev Extend access duration
     */
    function extendAccess(uint256 contentId, address user, uint256 additionalTime) external {
        AccessGrant storage grant = accessGrants[contentId][user];
        require(grant.isActive, "AccessControl: access not active");

        grant.expiresAt += additionalTime;

        emit AccessExtended(contentId, user, grant.expiresAt);
    }
}
