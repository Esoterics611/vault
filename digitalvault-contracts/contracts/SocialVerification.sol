// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SocialVerification
 * @dev Links blockchain identities to social media accounts (optional)
 */
contract SocialVerification is Ownable {
    struct SocialProfile {
        address walletAddress;
        string instagramHandle;
        string tiktokHandle;
        string twitterHandle;
        bool instagramVerified;
        bool tiktokVerified;
        bool twitterVerified;
        uint256 verifiedAt;
    }

    mapping(address => SocialProfile) public profiles;
    mapping(bytes32 => address) public handleToWallet; // keccak256(platform, handle) => wallet

    event SocialLinked(address indexed walletAddress, string platform, string handle);
    event SocialVerified(address indexed walletAddress, string platform);
    event SocialUnlinked(address indexed walletAddress, string platform);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Link social profile
     */
    function linkSocialProfile(string memory platform, string memory handle) external {
        require(bytes(handle).length > 0, "SocialVerification: invalid handle");

        SocialProfile storage profile = profiles[msg.sender];
        profile.walletAddress = msg.sender;

        bytes32 handleHash = keccak256(abi.encodePacked(platform, handle));

        if (keccak256(bytes(platform)) == keccak256(bytes("instagram"))) {
            profile.instagramHandle = handle;
            handleToWallet[handleHash] = msg.sender;
        } else if (keccak256(bytes(platform)) == keccak256(bytes("tiktok"))) {
            profile.tiktokHandle = handle;
            handleToWallet[handleHash] = msg.sender;
        } else if (keccak256(bytes(platform)) == keccak256(bytes("twitter"))) {
            profile.twitterHandle = handle;
            handleToWallet[handleHash] = msg.sender;
        } else {
            revert("SocialVerification: invalid platform");
        }

        emit SocialLinked(msg.sender, platform, handle);
    }

    /**
     * @dev Verify social profile (onlyOwner or oracle)
     */
    function verifySocialProfile(address wallet, string memory platform) external onlyOwner {
        SocialProfile storage profile = profiles[wallet];
        require(profile.walletAddress != address(0), "SocialVerification: profile not found");

        if (keccak256(bytes(platform)) == keccak256(bytes("instagram"))) {
            profile.instagramVerified = true;
        } else if (keccak256(bytes(platform)) == keccak256(bytes("tiktok"))) {
            profile.tiktokVerified = true;
        } else if (keccak256(bytes(platform)) == keccak256(bytes("twitter"))) {
            profile.twitterVerified = true;
        } else {
            revert("SocialVerification: invalid platform");
        }

        profile.verifiedAt = block.timestamp;

        emit SocialVerified(wallet, platform);
    }

    /**
     * @dev Unlink social profile
     */
    function unlinkSocialProfile(string memory platform) external {
        SocialProfile storage profile = profiles[msg.sender];

        if (keccak256(bytes(platform)) == keccak256(bytes("instagram"))) {
            bytes32 handleHash = keccak256(abi.encodePacked(platform, profile.instagramHandle));
            delete handleToWallet[handleHash];
            profile.instagramHandle = "";
            profile.instagramVerified = false;
        } else if (keccak256(bytes(platform)) == keccak256(bytes("tiktok"))) {
            bytes32 handleHash = keccak256(abi.encodePacked(platform, profile.tiktokHandle));
            delete handleToWallet[handleHash];
            profile.tiktokHandle = "";
            profile.tiktokVerified = false;
        } else if (keccak256(bytes(platform)) == keccak256(bytes("twitter"))) {
            bytes32 handleHash = keccak256(abi.encodePacked(platform, profile.twitterHandle));
            delete handleToWallet[handleHash];
            profile.twitterHandle = "";
            profile.twitterVerified = false;
        } else {
            revert("SocialVerification: invalid platform");
        }

        emit SocialUnlinked(msg.sender, platform);
    }

    /**
     * @dev Get social profile
     */
    function getSocialProfile(address wallet) external view returns (SocialProfile memory) {
        return profiles[wallet];
    }

    /**
     * @dev Get wallet by social handle
     */
    function getWalletByHandle(string memory platform, string memory handle)
        external
        view
        returns (address)
    {
        bytes32 handleHash = keccak256(abi.encodePacked(platform, handle));
        return handleToWallet[handleHash];
    }
}
