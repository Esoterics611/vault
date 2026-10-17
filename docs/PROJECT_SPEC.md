# DigitalVault: Complete Implementation Prompt

## Project Overview
Build a decentralized content ownership platform for young content creators (late teens to early twenties) to privately store, prove ownership of, and monetize their original poetry, journals, photography, and short videos. The platform emphasizes complete anonymity, privacy, and social sharing capabilities while allowing creators to develop their craft and build their brand.

## Core Philosophy
- **Privacy First**: Complete anonymity for all users, content encrypted end-to-end
- **Creator Empowerment**: Amateur youth becoming content creators while developing their craft
- **Proof of Ownership**: Cryptographic proof of original authorship with timestamps
- **Flexible Monetization**: Multiple access models (free preview, pay-per-access, full ownership transfer)
- **Social Integration**: Built-in sharing to Instagram, TikTok, Twitter with ownership proof watermarks


## Target Users
**Demographics**: 16-25 years old, active on Instagram/TikTok, aspiring content creators

**Use Cases**:
- Poet sharing original work with proof of authorship
- Journaling with absolute privacy but option to monetize
- Photographer building portfolio with ownership verification
- Videographer creating short-form content with licensing options
- Artist wanting to share previews but protect full work

## Technical Stack

### Blockchain Layer
- **Network**: Base L2 (Ethereum L2)
- **Smart Contracts**: Solidity 0.8.20+
- **Development**: Hardhat framework
- **Testing**: Hardhat + Chai + Waffle
- **Deployment**: Base Sepolia (testnet) → Base Mainnet

### Storage Layer
- **Primary**: IPFS (InterPlanetary File System)
- **Pinning Service**: Pinata Cloud (free tier for development)
- **Incentive Layer**: Custom storage provider rewards
- **Backup**: Multiple pinning providers for redundancy

### Mobile Application
- **Framework**: Flutter (iOS + Android simultaneously)
- **Language**: Dart
- **Web3 Integration**: 
  - walletconnect_flutter
  - web3dart package
- **State Management**: Riverpod
- **Local Storage**: flutter_secure_storage (for keys)
- **Media**: 
  - image_picker
  - video_player
  - camera package
- **Encryption**: 
  - pointycastle (AES-256-GCM)
  - cryptography package

### Backend Services
- **IPFS Gateway**: Custom Node.js service
- **Metadata Indexer**: Node.js + PostgreSQL
- **API**: Express.js REST API
- **Storage Provider Coordinator**: Node.js service for provider management

## Detailed Requirements

### 1. Smart Contract Architecture

#### Contract 1: VaultToken.sol (ERC20)
```solidity
// Native token: VLTC (VaultCoin)
// Features:
- Standard ERC20 functionality
- Burnable (for deflation)
- Pausable (emergency stop)
- Snapshot (for governance)
- Permit (gasless approvals)
- Access control (minter, pauser roles)

// Token Economics:
- Total Supply: 1,000,000,000 VLTC
- Decimals: 18
- Initial Distribution:
  * 30% Presale (300M VLTC)
  * 20% Airdrop Program (200M VLTC)
  * 30% Liquidity Mining (300M VLTC - 4 year emission)
  * 10% Storage Provider Rewards (100M VLTC - 4 year emission)
  * 10% Treasury/Team (100M VLTC - 4 year linear vest)
```

#### Contract 2: ContentRegistry.sol
```solidity
// Core content management
struct Content {
    bytes32 contentHash;        // IPFS hash
    bytes32 metadataHash;       // IPFS metadata hash
    address owner;              // Current owner
    address creator;            // Original creator (immutable)
    uint256 createdAt;          // Timestamp
    uint256 fileSize;           // Size in bytes
    ContentType contentType;    // POETRY, JOURNAL, PHOTO, VIDEO
    AccessModel accessModel;    // PRIVATE, PREVIEW, PAY_ACCESS, FOR_SALE
    bytes encryptedKey;         // Encrypted AES key (only decryptable by owner)
    uint256 viewCount;          // Analytics
    bool isActive;              // Soft delete flag
}

enum ContentType { POETRY, JOURNAL, PHOTO, VIDEO }
enum AccessModel { PRIVATE, PREVIEW_ALLOWED, PAY_PER_ACCESS, FOR_SALE }

// Functions:
- registerContent(contentHash, encryptedKey, metadata, contentType, accessModel)
- transferOwnership(contentId, newOwner) 
- updateAccessModel(contentId, newAccessModel)
- grantTemporaryAccess(contentId, user, duration)
- deactivateContent(contentId)
- verifyOwnership(contentId, owner) returns (bool)
- getContentInfo(contentId) returns (Content)
- getCreatorContents(creator) returns (uint256[])
- incrementViewCount(contentId)

// Events:
- ContentRegistered(contentId, creator, contentType, timestamp)
- OwnershipTransferred(contentId, from, to, price)
- AccessGranted(contentId, user, expiresAt)
- AccessModelUpdated(contentId, oldModel, newModel)
- ContentDeactivated(contentId, owner)
```

#### Contract 3: Marketplace.sol
```solidity
// Content trading and access marketplace
struct Listing {
    uint256 contentId;
    address seller;
    uint256 price;              // In VLTC
    ListingType listingType;    // FULL_OWNERSHIP, ACCESS_KEY, TIMED_ACCESS
    uint256 accessDuration;     // For timed access (in seconds)
    uint256 maxKeys;            // Max keys to sell (0 = unlimited)
    uint256 soldKeys;           // Keys sold so far
    bool isActive;
    uint256 listedAt;
}

enum ListingType { FULL_OWNERSHIP, ACCESS_KEY, TIMED_ACCESS }

// Functions:
- createListing(contentId, price, listingType, accessDuration, maxKeys)
- cancelListing(listingId)
- purchaseListing(listingId) payable
- updateListingPrice(listingId, newPrice)
- getActiveListings(startIndex, count) returns (Listing[])
- getListingsByCreator(creator) returns (Listing[])
- getListingsByContentType(contentType) returns (Listing[])
- withdrawEarnings()

// Fee Structure:
- Platform Fee: 2.5% of sale
- Creator Royalty: 5% on secondary sales (if enabled)
- Storage Provider Cut: 1% (distributed to providers hosting content)

// Events:
- ListingCreated(listingId, contentId, seller, price, listingType)
- ListingPurchased(listingId, buyer, price, listingType)
- ListingCancelled(listingId, seller)
- PriceUpdated(listingId, oldPrice, newPrice)
- EarningsWithdrawn(seller, amount)
```

#### Contract 4: StorageProvider.sol
```solidity
// Decentralized storage provider network
struct Provider {
    address providerAddress;
    string ipfsNodeId;          // IPFS peer ID
    uint256 stakedAmount;       // VLTC staked
    uint256 storageCapacity;    // In GB
    uint256 usedStorage;        // In GB
    uint256 contentCount;       // Number of contents hosted
    uint256 uptime;             // Uptime percentage (basis points)
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

// Constants:
- MIN_STAKE: 1000 VLTC
- MIN_STORAGE_CAPACITY: 100 GB
- REDUNDANCY_REQUIREMENT: 3 providers minimum
- VERIFICATION_INTERVAL: 24 hours
- UPTIME_THRESHOLD: 9500 (95%)

// Functions:
- registerProvider(ipfsNodeId, storageCapacity) payable
- stakeAdditional() payable
- unstake(amount)
- provideStorage(contentId)
- submitProofOfStorage(contentId, proof)
- updateStorageCapacity(newCapacity)
- reportProviderDowntime(providerAddress)
- slashProvider(providerAddress, reason)
- claimRewards()
- getProviderInfo(providerAddress) returns (Provider)
- getContentProviders(contentId) returns (address[])
- findAvailableProviders(requiredCapacity) returns (address[])

// Proof of Storage:
- Merkle proof verification
- Challenge-response protocol every 24 hours
- Automatic slashing for failed proofs

// Events:
- ProviderRegistered(providerAddress, ipfsNodeId, stakedAmount)
- StorageProvided(contentId, providerAddress)
- ProofSubmitted(contentId, providerAddress, timestamp)
- ProviderSlashed(providerAddress, amount, reason)
- RewardsClaimed(providerAddress, amount)
```

#### Contract 5: RewardDistributor.sol
```solidity
// Token emission and reward distribution
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

// Emission Schedule (4 years):
Year 1: 40% of pool
Year 2: 30% of pool
Year 3: 20% of pool
Year 4: 10% of pool

// Functions:
- stake(amount)
- unstake(amount)
- claimRewards()
- distributeEpochRewards()
- calculateUserRewards(user) returns (uint256)
- calculateProviderRewards(provider) returns (uint256)
- calculateCreatorRewards(creator) returns (uint256)
- updateRewardRates(newRates)

// Reward Distribution:
- 50% Liquidity Providers (LP stakers)
- 30% Storage Providers (based on storage + uptime)
- 20% Content Creators (based on engagement + sales)

// Events:
- Staked(user, amount, timestamp)
- Unstaked(user, amount, timestamp)
- RewardsClaimed(user, amount)
- EpochDistributed(epochNumber, totalRewards)
```

#### Contract 6: DAOGovernor.sol
```solidity
// Based on OpenZeppelin Governor
// Governance token: VLTC (same as utility token)

// Governance Parameters:
- Voting Delay: 1 day
- Voting Period: 7 days
- Proposal Threshold: 100,000 VLTC (0.01% of supply)
- Quorum: 4% of total supply
- Timelock Delay: 48 hours

// Governable Parameters:
- Platform fees (min 0%, max 10%)
- Storage provider minimum stake
- Redundancy requirements
- Reward emission rates
- Emergency pause
- Treasury fund allocation

// Functions:
- propose(targets, values, calldatas, description)
- castVote(proposalId, support)
- castVoteWithReason(proposalId, support, reason)
- execute(proposalId)
- queue(proposalId)
- cancel(proposalId)
- delegate(delegatee)
- getVotes(account) returns (uint256)

// Proposal Types:
1. Parameter Change
2. Treasury Spend
3. Emergency Action
4. Protocol Upgrade
5. Partnership/Integration

// Events:
- ProposalCreated(proposalId, proposer, description)
- VoteCast(voter, proposalId, support, votes, reason)
- ProposalExecuted(proposalId)
- ProposalCanceled(proposalId)
```

#### Contract 7: AccessControl.sol
```solidity
// Manages content access permissions
struct AccessGrant {
    uint256 contentId;
    address grantee;
    uint256 grantedAt;
    uint256 expiresAt;
    AccessType accessType;
    bool isActive;
}

enum AccessType { PREVIEW, FULL_ACCESS, TIMED_ACCESS }

// Functions:
- grantAccess(contentId, user, accessType, duration)
- revokeAccess(contentId, user)
- verifyAccess(contentId, user) returns (bool, AccessType)
- extendAccess(contentId, user, additionalTime)
- batchGrantAccess(contentId, users[], accessType, duration)
- getActiveAccess(user) returns (AccessGrant[])
- generateAccessToken(contentId, user) returns (bytes32)
- verifyAccessToken(token) returns (bool, uint256 contentId)

// Access Token System:
- JWT-like tokens generated off-chain
- Signature verification on-chain
- Short-lived tokens (1 hour) for preview
- Long-lived tokens for purchased content

// Events:
- AccessGranted(contentId, grantee, accessType, expiresAt)
- AccessRevoked(contentId, grantee)
- AccessExtended(contentId, grantee, newExpiresAt)
- AccessTokenGenerated(contentId, user, tokenHash)
```

#### Contract 8: SocialVerification.sol
```solidity
// Links blockchain identities to social media (optionally)
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

// Functions:
- linkSocialProfile(platform, handle, signature)
- verifySocialProfile(platform, handle)
- unlinkSocialProfile(platform)
- getSocialProfile(walletAddress) returns (SocialProfile)
- getWalletByHandle(platform, handle) returns (address)

// Verification Process:
1. User posts verification code on social media
2. Oracle verifies post existence
3. Contract marks as verified
4. Optional: automated verification via social API

// Events:
- SocialLinked(walletAddress, platform, handle)
- SocialVerified(walletAddress, platform)
- SocialUnlinked(walletAddress, platform)
```

#### Contract 9: PresaleContract.sol
```solidity
// Token presale management
struct PresaleRound {
    uint256 roundNumber;
    uint256 startTime;
    uint256 endTime;
    uint256 pricePerToken;      // In ETH
    uint256 minPurchase;
    uint256 maxPurchase;
    uint256 totalAllocation;
    uint256 soldAmount;
    bool isActive;
}

// Presale Structure:
Round 1 (Private): 100M VLTC at $0.001, max $10k per wallet
Round 2 (Public): 200M VLTC at $0.002, max $5k per wallet
Cliff: 3 months
Vesting: 12 months linear

// Functions:
- createPresaleRound(params)
- buyTokens() payable
- claimVestedTokens()
- getVestingSchedule(buyer) returns (schedule)
- withdrawPresaleFunds()
- emergencyPause()

// Anti-whale Measures:
- Maximum purchase limits per wallet
- KYC requirement for large purchases (optional)
- Vesting schedule prevents dumps

// Events:
- TokensPurchased(buyer, amount, round)
- TokensClaimed(buyer, amount)
- PresaleRoundCreated(roundNumber, allocation)
```

#### Contract 10: AirdropDistributor.sol
```solidity
// Manages airdrop campaigns
struct AirdropCampaign {
    uint256 campaignId;
    uint256 totalAllocation;
    uint256 perUserAmount;
    uint256 startTime;
    uint256 endTime;
    bytes32 merkleRoot;         // For Merkle tree verification
    mapping(address => bool) claimed;
    uint256 totalClaimed;
}

// Airdrop Categories:
1. Early Adopters: 50M VLTC (first 10,000 users)
2. Content Creators: 75M VLTC (users who upload content)
3. Storage Providers: 25M VLTC (first 100 providers)
4. Community Contributors: 50M VLTC (governance participants)

// Functions:
- createAirdropCampaign(allocation, perUser, merkleRoot)
- claimAirdrop(campaignId, proof[])
- checkEligibility(campaignId, user) returns (bool)
- getRemainingAllocation(campaignId) returns (uint256)

// Claiming Mechanism:
- Merkle tree for gas-efficient bulk airdrops
- Claim window: 90 days
- Unclaimed tokens return to treasury

// Events:
- CampaignCreated(campaignId, allocation)
- AirdropClaimed(campaignId, user, amount)
```

### 2. Flutter Mobile Application Structure

#### App Architecture
```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── routes.dart
│   └── theme.dart
├── core/
│   ├── constants/
│   │   ├── contract_addresses.dart
│   │   ├── api_endpoints.dart
│   │   └── app_constants.dart
│   ├── services/
│   │   ├── web3_service.dart
│   │   ├── encryption_service.dart
│   │   ├── ipfs_service.dart
│   │   ├── storage_service.dart
│   │   └── notification_service.dart
│   ├── models/
│   │   ├── content_model.dart
│   │   ├── user_model.dart
│   │   ├── listing_model.dart
│   │   └── transaction_model.dart
│   └── utils/
│       ├── encryption_utils.dart
│       ├── file_utils.dart
│       └── validation_utils.dart
├── features/
│   ├── authentication/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   ├── onboarding_page.dart
│   │   │   │   ├── wallet_connect_page.dart
│   │   │   │   └── create_wallet_page.dart
│   │   │   └── widgets/
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── repositories/
│   │       └── auth_repository.dart
│   ├── content_creation/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   ├── create_content_page.dart
│   │   │   │   ├── poetry_editor_page.dart
│   │   │   │   ├── journal_editor_page.dart
│   │   │   │   ├── photo_upload_page.dart
│   │   │   │   └── video_upload_page.dart
│   │   │   └── widgets/
│   │   │       ├── media_picker_widget.dart
│   │   │       ├── encryption_indicator.dart
│   │   │       └── upload_progress_widget.dart
│   │   ├── providers/
│   │   │   ├── content_creation_provider.dart
│   │   │   └── upload_provider.dart
│   │   └── repositories/
│   │       └── content_repository.dart
│   ├── portfolio/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   ├── my_content_page.dart
│   │   │   │   └── content_detail_page.dart
│   │   │   └── widgets/
│   │   │       ├── content_card.dart
│   │   │       ├── ownership_badge.dart
│   │   │       └── analytics_widget.dart
│   │   └── providers/
│   │       └── portfolio_provider.dart
│   ├── marketplace/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   ├── marketplace_home_page.dart
│   │   │   │   ├── browse_page.dart
│   │   │   │   ├── listing_detail_page.dart
│   │   │   │   └── purchase_page.dart
│   │   │   └── widgets/
│   │   │       ├── listing_card.dart
│   │   │       ├── price_widget.dart
│   │   │       └── purchase_button.dart
│   │   └── providers/
│   │       └── marketplace_provider.dart
│   ├── storage_provider/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   ├── provider_dashboard_page.dart
│   │   │   │   ├── stake_management_page.dart
│   │   │   │   └── earnings_page.dart
│   │   │   └── widgets/
│   │   │       ├── storage_stats_widget.dart
│   │   │       └── earnings_chart.dart
│   │   └── providers/
│   │       └── storage_provider_provider.dart
│   ├── social_sharing/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   └── share_content_page.dart
│   │   │   └── widgets/
│   │   │       ├── watermark_widget.dart
│   │   │       └── social_buttons.dart
│   │   └── services/
│   │       └── social_share_service.dart
│   ├── dao/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   ├── governance_page.dart
│   │   │   │   ├── proposals_page.dart
│   │   │   │   └── voting_page.dart
│   │   │   └── widgets/
│   │   │       └── proposal_card.dart
│   │   └── providers/
│   │       └── dao_provider.dart
│   └── wallet/
│       ├── presentation/
│       │   ├── pages/
│       │   │   ├── wallet_page.dart
│       │   │   ├── send_page.dart
│       │   │   └── receive_page.dart
│       │   └── widgets/
│       │       ├── balance_widget.dart
│       │       └── transaction_list.dart
│       └── providers/
│           └── wallet_provider.dart
└── shared/
    ├── widgets/
    │   ├── loading_indicator.dart
    │   ├── error_widget.dart
    │   └── success_dialog.dart
    └── extensions/
        └── context_extensions.dart
```

#### Key Features Implementation

**Authentication Flow:**
```dart
// 1. App Launch
- Check for existing wallet in secure storage
- If exists: Auto-connect
- If not: Show onboarding

// 2. Wallet Options
- Create New Wallet (generates seed phrase)
- Import Wallet (seed phrase/private key)
- Connect Wallet (WalletConnect)

// 3. Security
- Biometric authentication
- PIN code backup
- Encrypted local storage
```

**Content Creation Flow:**
```dart
// 1. Select Content Type
enum ContentType {
  poetry,
  journal,
  photo,
  video
}

// 2. Create/Capture Content
- Poetry: Rich text editor with markdown support
- Journal: Date-stamped private entries
- Photo: Camera/gallery with filters
- Video: Record up to 60 seconds, compression

// 3. Encryption
- Generate random AES-256 key
- Encrypt content locally
- Derive encryption key from wallet private key
- Store encrypted key in smart contract

// 4. Upload to IPFS
- Upload encrypted content to IPFS via Pinata
- Get IPFS hash (CID)
- Upload metadata JSON to IPFS

// 5. Mint on Blockchain
- Call ContentRegistry.registerContent()
- Store IPFS hashes and encrypted key
- Set initial access model
- Pay gas fee in VLTC

// 6. Confirmation
- Show ownership certificate
- Display blockchain transaction
- Enable social sharing
```

**Marketplace Flow:**
```dart
// Browse Content
- Grid/List view of available content
- Filter by content type, price, creator
- Search functionality
- Preview (if allowed by owner)

// Purchase Flow
1. Select content
2. View preview (watermarked/low-res)
3. Choose access type:
   - One-time access key
   - Timed access (7 days, 30 days)
   - Full ownership transfer
4. Confirm price in VLTC
5. Approve token spend
6. Purchase listing (calls Marketplace.purchaseListing)
7. Receive encrypted key
8. Decrypt and download content
```

**Social Sharing Features:**
```dart
// Watermark System
- Add "Owned on DigitalVault" text overlay
- Include QR code linking to verification page
- Display creator wallet address (last 6 chars)
- Add timestamp and content ID

// Share Destinations
- Instagram (image/video with watermark)
- TikTok (video with watermark)
- Twitter (image with ownership proof link)
- Save to camera roll (watermarked)

// Ownership Verification Page
- Web page: vault.app/verify/{contentId}
- Shows: Creator, timestamp, blockchain proof
- Displays: Current owner, view count, price history
```

**Storage Provider Features:**
```dart
// Provider Dashboard
- Total storage provided
- Active content count
- Earnings (lifetime and monthly)
- Uptime percentage
- Reputation score

// Become a Provider
1. Stake minimum VLTC
2. Enter IPFS node ID
3. Declare storage capacity
4. Wait for approval
5. Start earning rewards

// Earnings
- Base rewards from storage
- Bonus from content sales (1%)
- Uptime multiplier
- Reputation bonus
```

#### Mobile App Screens (Detailed)

**Screen 1: Onboarding/Splash**
- App logo animation
- "Your Creative Vault" tagline
- "Get Started" button
- "Already have a wallet?" link

**Screen 2: Wallet Setup**
- Create New Wallet
  - Generate seed phrase (12 words)
  - Write down warning
  - Verify seed phrase (select random words)
  - Set PIN/biometric
- Import Wallet
  - Enter seed phrase
  - Enter private key
  - Set PIN/biometric
- Connect Wallet
  - WalletConnect QR scan
  - MetaMask deep link

**Screen 3: Home Dashboard**
- Top Bar:
  - Profile icon (left)
  - Wallet balance (VLTC + ETH)
  - Notifications (right)
- Content Type Cards:
  - Poetry (fountain pen icon)
  - Journal (book icon)
  - Photography (camera icon)
  - Video (play icon)
- Quick Stats:
  - Total content pieces
  - Total earnings
  - Total views
- Navigation Bar:
  - Home
  - Create
  - Marketplace
  - Wallet
  - More

**Screen 4: Create Content**
- Content Type Selector (tabs at top)
- Poetry/Journal Editor:
  - Rich text editor
  - Title field
  - Body (markdown support)
  - Tags input
  - Privacy toggle
- Photo Upload:
  - Camera/gallery button
  - Crop/filter options
  - Caption field
  - Quality selector
- Video Upload:
  - Record button (60s timer)
  - Gallery import
  - Trim tool
  - Audio toggle
- Bottom Actions:
  - "Save Draft" (local)
  - "Publish" (to blockchain)
  - Access model selector
  - Price setting (if for sale)

**Screen 5: My Portfolio**
- Filter bar (All, Poetry, Journal, Photos, Videos)
- Sort options (Recent, Popular, Earnings)
- Grid view of content thumbnails
- Each card shows:
  - Thumbnail/preview
  - Title
  - Creation date
  - View count
  - Earnings (if sold)
  - Status badge (Private, Listed, Sold)
- Tap to view details

**Screen 6: Content Detail**
- Full content display (decrypted)
- Ownership badge with blockchain verification
- Stats:
  - Views
  - Shares
  - Earnings
  - Creation timestamp
- Actions:
  - Share (with watermark)
  - Edit
  - Change access model
  - List for sale
  - Delete
- Access Log (who has access)

**Screen 7: Marketplace Browse**
- Search bar at top
- Filters:
  - Content type
  - Price range
  - Access type
  - Creator verification
- Featured content carousel
- Grid of listings
- Each card shows:
  - Blurred/watermarked preview
  - Title
  - Creator (anonymous ID or verified handle)
  - Price
  - Access type badge
  - View count
- Pull to refresh

**Screen 8: Listing Detail**
- Preview content (watermarked/low-res)
- Full details:
  - Title
  - Description
  - Creator info
  - Creation date
  - File size
  - Content type
  - Blockchain verification
- Pricing:
  - Current price (VLTC)
  - USD equivalent
  - Access type
  - Keys remaining (if limited)
- Actions:
  - "Preview" (if allowed)
  - "Purchase Access Key"
  - "Buy Full Ownership"
  - "Report Content"
- Reviews/Ratings (future feature)

**Screen 9: Purchase Confirmation**
- Content preview
- Purchase summary:
  - Access type
  - Duration (if timed)
  - Price breakdown:
    * Content price
    * Platform fee
    * Gas estimate
    * Total
- Wallet balance check
- Approve transaction button
- Transaction status:
  - Approving VLTC spend
  - Purchasing listing
  - Receiving access key
  - Success/failure message

**Screen 10: Wallet**
- Balance card:
  - VLTC balance (large)
  - ETH balance (small)
  - USD equivalent
- Quick actions:
  - Send
  - Receive
  - Buy VLTC
  - Swap
- Transaction history:
  - Chronological list
  - Icons for type (purchase, sale, reward, etc.)
  - Amount with +/- color coding
  - Timestamp
  - Status (pending, confirmed)
- Portfolio value chart

**Screen 11: Storage Provider Dashboard**
- Header:
  - "Provider" badge
  - Reputation score (stars)
- Stats cards:
  - Staked VLTC
  - Storage provided (GB)
  - Content pieces hosted
  - Uptime percentage
- Earnings section:
  - Total earnings
  - This month
  - Pending rewards
  - "Claim Rewards" button
- Performance chart (last 30 days)
- Hosted content list

**Screen 12: DAO Governance**
- Active proposals list
- Each proposal card:
  - Title
  - Description (truncated)
  - Proposer
  - Status (Active, Passed, Failed)
  - Voting deadline
  - Current votes (For/Against/Abstain)
  - Your vote indicator
- Filter: Active, Closed, My Votes
- "Create Proposal" button (if eligible)
- Your voting power display

**Screen 13: Settings/More**
- Profile section:
  - Anonymous ID
  - Joined date
  - Total content
  - Optional: Link social profiles
- Security:
  - Change PIN
  - Enable biometrics
  - Export seed phrase (with warning)
  - View private key (with warning)
- App settings:
  - Theme (light/dark)
  - Language
  - Notifications
  - Auto-lock timeout
- Support:
  - Help center
  - Report bug
  - Contact support
- About:
  - Version
  - Terms of service
  - Privacy policy
  - Open source licenses

### 3. Backend Services

#### Service 1: IPFS Gateway API
```javascript
// Express.js API
// Endpoints:

POST /api/ipfs/upload
- Accepts encrypted file
- Pins to IPFS via Pinata
- Returns IPFS hash (CID)
- Saves metadata to database

GET /api/ipfs/content/:cid
- Retrieves content from IPFS
- Checks access permissions
- Returns encrypted content

POST /api/ipfs/metadata
- Uploads metadata JSON
- Returns metadata CID

GET /api/ipfs/pin-status/:cid
- Checks if content is pinned
- Returns pinning status and provider count

DELETE /api/ipfs/unpin/:cid
- Owner-only endpoint
- Unpins content from IPFS
- Updates database
```

#### Service 2: Metadata Indexer
```javascript
// Node.js service + PostgreSQL
// Continuously indexes blockchain events

// Database Schema:

Table: contents
- content_id (uint256, primary key)
- content_hash (bytes32)
- metadata_hash (bytes32)
- owner (address, indexed)
- creator (address, indexed)
- created_at (timestamp)
- file_size (bigint)
- content_type (enum)
- access_model (enum)
- view_count (int)
- is_active (boolean)

Table: listings
- listing_id (uint256, primary key)
- content_id (uint256, foreign key)
- seller (address, indexed)
- price (bigint)
- listing_type (enum)
- access_duration (int)
- max_keys (int)
- sold_keys (int)
- is_active (boolean)
- listed_at (timestamp)

Table: transactions
- tx_hash (string, primary key)
- from_address (address, indexed)
- to_address (address, indexed)
- content_id (uint256)
- amount (bigint)
- transaction_type (enum)
- timestamp (timestamp)
- status (enum)

Table: providers
- provider_address (address, primary key)
- ipfs_node_id (string)
- staked_amount (bigint)
- storage_capacity (bigint)
- used_storage (bigint)
- content_count (int)
- uptime (decimal)
- reputation_score (int)
- is_active (boolean)

// Functions:
- indexNewContent(event)
- indexListingCreated(event)
- indexPurchase(event)
- indexProviderRegistered(event)
- updateContentStats()
- calculateProviderMetrics()

// API Endpoints:
GET /api/contents?owner=&type=&limit=&offset=
GET /api/listings?type=&priceRange=&limit=
GET /api/transactions/:address
GET /api/providers?minReputation=&minCapacity=
GET /api/analytics/overview
```

#### Service 3: Storage Provider Coordinator
```javascript
// Manages provider network

// Functions:
- assignContentToProviders(contentId, fileSize)
  * Finds 3 available providers with capacity
  * Distributes content for redundancy
  * Records assignments in smart contract

- verifyStorageProof(contentId, providerId, proof)
  * Validates Merkle proofs
  * Updates uptime metrics
  * Issues challenges

- monitorProviderHealth()
  * Pings providers every 5 minutes
  * Records downtime
  * Triggers slashing if needed

- rebalanceStorage()
  * Redistributes content from failed providers
  * Maintains 3x redundancy
  * Optimizes provider utilization

// Challenge-Response Protocol:
1. Service generates random challenge
2. Provider must return Merkle proof within 5 minutes
3. Proof verified against content hash
4. Success: update uptime
5. Failure: slash stake and reassign content
```

#### Service 4: Notification Service
```javascript
// Push notifications and alerts

// Types of Notifications:
1. Content Purchased
2. Access Key Sold
3. New Bid Received
4. Governance Proposal Created
5. Proposal Vote Deadline
6. Rewards Claimed
7. Storage Provider Warning
8. Price Drop Alert

// Delivery Channels:
- Firebase Cloud Messaging (mobile push)
- Email (optional, if user provides)
- In-app notifications

// Database Schema:
Table: notifications
- notification_id (uuid, primary key)
- user_address (address, indexed)
- notification_type (enum)
- title (string)
- message (string)
- related_id (string)
- is_read (boolean)
- created_at (timestamp)

// Functions:
- sendNotification(address, type, data)
- markAsRead(notificationId)
- getUserNotifications(address, limit, offset)
- subscribeToTopic(address, topic)
```

### 4. Token Economics Details

#### Presale Structure
```
Round 1: Private Sale
- Allocation: 100M VLTC (10% of total supply)
- Price: $0.001 per VLTC
- Min: $100 / Max: $10,000 per wallet
- Total Raise: $100,000
- Vesting: 3 month cliff, 12 month linear
- Participants: Early supporters, angels

Round 2: Public Sale
- Allocation: 200M VLTC (20% of total supply)
- Price: $0.002 per VLTC
- Min: $50 / Max: $5,000 per wallet
- Total Raise: $400,000
- Vesting: 1 month cliff, 9 month linear
- Participants: Public via launchpad

Total Raised: $500,000
Use of Funds:
- 40% Development (team, audits)
- 30% Liquidity provision
- 20% Marketing
- 10% Legal and operational
```

#### Airdrop Campaigns
```
Campaign 1: Early Adopters
- Allocation: 50M VLTC
- Eligibility: First 10,000 registered users
- Amount: 5,000 VLTC per user
- Vesting: Immediate

Campaign 2: Content Creators
- Allocation: 75M VLTC
- Eligibility: Users who upload at least 5 pieces
- Amount: Based on engagement (1,000-10,000 VLTC)
- Vesting: 3 month linear

Campaign 3: Storage Providers
- Allocation: 25M VLTC
- Eligibility: First 100 registered providers
- Amount: 250,000 VLTC per provider
- Vesting: 6 month linear

Campaign 4: Community Contributors
- Allocation: 50M VLTC
- Eligibility: DAO participants, bug bounties
- Amount: Variable based on contribution
- Vesting: Immediate

Total Airdrop: 200M VLTC (20% of supply)
```

#### Liquidity Mining
```
Pool 1: VLTC/ETH Uniswap V3
- Allocation: 150M VLTC over 4 years
- Year 1: 60M (40%)
- Year 2: 45M (30%)
- Year 3: 30M (20%)
- Year 4: 15M (10%)
- APR Range: 50-150% (decreasing)

Pool 2: VLTC Single-Sided Staking
- Allocation: 150M VLTC over 4 years
- Same emission schedule as Pool 1
- APR Range: 30-80%
- Bonus: Governance voting power multiplier

Total Liquidity Mining: 300M VLTC (30%)
```

#### Storage Provider Rewards
```
Total Allocation: 100M VLTC over 4 years
- Year 1: 40M
- Year 2: 30M
- Year 3: 20M
- Year 4: 10M

Reward Distribution (per epoch = 24 hours):
- Base reward: Proportional to storage provided
- Uptime multiplier: 0.5x to 2x based on uptime
- Reputation bonus: Up to 1.5x for top providers
- Sales bonus: 1% of content sale price

Example Calculation:
Provider A: 1TB storage, 99% uptime, 950 reputation
Base reward = (1TB / total_network_storage) * daily_emission
Uptime multiplier = 1.8x (for 99% uptime)
Reputation bonus = 1.4x (for 950/1000 score)
Daily reward = base * 1.8 * 1.4 = ~2.5x base
```

#### Team and Treasury
```
Team Allocation: 50M VLTC (5%)
- Vesting: 1 year cliff, 4 year linear
- Lock: Cannot transfer until year 2

Treasury: 50M VLTC (5%)
- Use: Development, partnerships, emergencies
- Governance: DAO controlled after year 1
- Multi-sig: 5-of-9 initially
```

### 5. Security Implementation

#### Smart Contract Security
```solidity
// All contracts include:

1. ReentrancyGuard (OpenZeppelin)
2. Pausable (emergency stop)
3. Access Control (role-based)
4. Upgradeable (transparent proxy)
5. Rate limiting (prevent spam)
6. Input validation
7. Integer overflow protection (Solidity 0.8+)
8. Front-running prevention (commit-reveal for sensitive ops)

// Specific Protections:

Marketplace:
- Pull payment pattern
- Escrow for all trades
- Approval checks before transfers
- Price manipulation prevention

Content Registry:
- Only owner can transfer
- Content existence checks
- Size limits enforced
- Duplicate prevention

Storage Provider:
- Minimum stake enforced
- Slashing timelock (24h delay)
- Dispute resolution period
- Multi-sig for critical functions
```

#### Mobile App Security
```dart
// Encryption
- All content encrypted with AES-256-GCM
- Keys derived from user's private key using PBKDF2
- Encryption performed locally before upload
- No unencrypted data in memory longer than necessary

// Key Management
- Private keys stored in iOS Keychain / Android Keystore
- Never logged or transmitted
- Biometric protection required for key access
- Seed phrase encrypted with user PIN

// Network Security
- All API calls over HTTPS
- Certificate pinning
- Request signing with wallet signature
- Rate limiting on client side

// Local Storage
- Encrypted SQLite database for cache
- No sensitive data in SharedPreferences
- Automatic data clearing on logout
- Secure deletion of temporary files

// Code Security
- Obfuscation for production builds
- Jailbreak/root detection
- Screenshot prevention for sensitive screens
- Clipboard clearing after copying addresses
```

#### Backend Security
```javascript
// API Security
- JWT authentication for all endpoints
- Rate limiting (100 req/min per IP)
- CORS configured properly
- Request validation with Joi
- SQL injection prevention (parameterized queries)
- XSS protection
- CSRF tokens

// IPFS Security
- Content address verification
- File size limits (100MB max)
- Malware scanning (ClamAV)
- Encrypted storage only
- Access control on retrieval

// Database Security
- Connection pooling
- Prepared statements
- Regular backups (daily)
- Encryption at rest
- Read replicas for queries
- Write permissions restricted

// Infrastructure Security
- AWS/GCP with VPC
- DDoS protection (Cloudflare)
- WAF rules
- Intrusion detection
- Log monitoring (ELK stack)
- Automated security updates
```

### 6. Testing Strategy

#### Smart Contract Testing
```javascript
// Hardhat test suites

describe("ContentRegistry", () => {
  // Unit tests
  - "should register content correctly"
  - "should prevent duplicate registration"
  - "should transfer ownership securely"
  - "should enforce size limits"
  - "should update access models"
  - "should handle deactivation"
  
  // Integration tests
  - "should integrate with Marketplace"
  - "should work with AccessControl"
  - "should emit correct events"
  
  // Edge cases
  - "should handle zero address"
  - "should handle max uint values"
  - "should handle empty content"
  
  // Gas tests
  - "should stay under gas limit"
  - "should optimize for common operations"
});

// Test Coverage Target: 95%+
// Tools: Hardhat, Chai, Waffle, Hardhat Coverage
```

#### Mobile App Testing
```dart
// Unit Tests (test/)
- Encryption/decryption functions
- Wallet operations
- Data models
- Utility functions

// Widget Tests
- Individual screen rendering
- Button interactions
- Form validation
- Navigation

// Integration Tests
- Complete user flows
- API integration
- Smart contract interaction
- IPFS upload/download

// Tools:
- flutter_test package
- mockito for mocking
- integration_test package
- Golden tests for UI consistency

// Coverage Target: 80%+
```

#### Backend Testing
```javascript
// Jest test suites
- API endpoint tests
- Database operations
- Event indexing
- Provider coordination
- Notification delivery

// Load Testing
- Artillery for load tests
- Target: 1000 concurrent users
- Response time: <500ms for 95th percentile

// Security Testing
- OWASP ZAP automated scans
- Manual penetration testing
- Dependency vulnerability scanning
```

### 7. Deployment Process

#### Smart Contract Deployment

**Step 1: Local Development**
```bash
# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Check coverage
npx hardhat coverage

# Deploy to local network
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost
```

**Step 2: Testnet Deployment (Base Sepolia)**
```bash
# Configure Base Sepolia in hardhat.config.js
networks: {
  baseSepolia: {
    url: "https://sepolia.base.org",
    accounts: [PRIVATE_KEY],
    chainId: 84532
  }
}

# Deploy contracts
npx hardhat run scripts/deploy-testnet.js --network baseSepolia

# Verify on Basescan
npx hardhat verify --network baseSepolia DEPLOYED_ADDRESS "constructor args"

# Initialize contracts
npx hardhat run scripts/initialize.js --network baseSepolia
```

**Step 3: Audit**
```bash
# Automated tools
- Slither
- Mythril
- Echidna

# Manual audit
- CertiK (recommended)
- OpenZeppelin
- Trail of Bits

# Bug bounty
- ImmuneFi program ($50k max bounty)
```

**Step 4: Mainnet Deployment (Base)**
```bash
# Final checks
- All tests passing
- Audit completed and issues resolved
- Multi-sig wallet setup
- Timelock configured

# Deploy
npx hardhat run scripts/deploy-mainnet.js --network base

# Verify
npx hardhat verify --network base DEPLOYED_ADDRESS

# Transfer ownership to multi-sig
npx hardhat run scripts/transfer-ownership.js --network base

# Announce contract addresses
```

#### Mobile App Deployment

**iOS Deployment**
```bash
# 1. Build release
flutter build ios --release

# 2. Archive in Xcode
# Product -> Archive

# 3. Submit to App Store Connect
# Automatically upload via Xcode
# Or use: xcrun altool --upload-app -f app.ipa

# 4. TestFlight
# Add external testers
# Collect feedback

# 5. App Store Review
# Submit for review
# Provide demo account
# Explain crypto functionality
```

**Android Deployment**
```bash
# 1. Build release
flutter build appbundle --release

# 2. Sign with key
# Uses key from android/key.properties

# 3. Upload to Google Play Console
# Create release in production track
# Upload app-release.aab

# 4. Internal testing
# Add testers
# Roll out to 100 users

# 5. Open testing
# Public beta
# Collect feedback

# 6. Production
# Staged rollout (20% -> 50% -> 100%)
```

#### Backend Deployment

**Infrastructure Setup (AWS)**
```bash
# 1. VPC and Security Groups
terraform apply -var-file=production.tfvars

# 2. ECS for containers
- IPFS Gateway API
- Metadata Indexer
- Storage Coordinator
- Notification Service

# 3. RDS PostgreSQL
- Multi-AZ deployment
- Automated backups
- Read replicas

# 4. ElastiCache Redis
- Caching layer
- Session management

# 5. S3 for static assets
- CDN via CloudFront

# 6. Load Balancer
- ALB for API routing
- Health checks
- Auto-scaling

# 7. Monitoring
- CloudWatch logs
- Datadog APM
- PagerDuty alerts
```

**CI/CD Pipeline**
```yaml
# GitHub Actions workflow

name: Deploy Backend
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Run tests
      - Check coverage
      
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - Build Docker images
      - Push to ECR
      
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - Update ECS services
      - Run database migrations
      - Smoke tests
      - Rollback if failed
```

### 8. Go-to-Market Strategy

#### Pre-Launch (2 months before)
1. **Community Building**
   - Launch Discord server
   - Twitter account (@DigitalVaultApp)
   - Medium blog for updates
   - Waitlist page

2. **Influencer Outreach**
   - Partner with poetry/art influencers
   - TikTok creators in target demographic
   - Micro-influencers (10k-100k followers)

3. **Presale**
   - Private round to angels
   - Public round via launchpad
   - Clear tokenomics communication

#### Launch Week
1. **Airdrop Campaign 1**
   - First 10,000 users get 5,000 VLTC
   - Referral bonuses
   - Social media amplification

2. **App Store Launch**
   - Press release
   - Product Hunt launch
   - Twitter Spaces AMA

3. **Creator Partnerships**
   - Onboard 50 known creators
   - Exclusive content drops
   - Revenue sharing deals

#### Post-Launch (First 90 days)
1. **User Acquisition**
   - Instagram/TikTok ads
   - Content creator programs
   - University partnerships
   - Campus ambassadors

2. **Feature Rollouts**
   - Week 4: Enhanced social sharing
   - Week 8: Collaborative content
   - Week 12: Subscription tiers

3. **Liquidity Mining**
   - Launch VLTC/ETH pool on Uniswap
   - Provide initial liquidity ($500k)
   - Start reward emissions

4. **DAO Launch**
   - First governance proposal
   - Treasury vote
   - Community-driven features

### 9. Monitoring and Analytics

#### Smart Contract Monitoring
```javascript
// Dune Analytics Dashboards
- Total Value Locked (TVL)
- Daily Active Users (DAU)
- Content registrations (by type)
- Marketplace volume
- Average content price
- Storage provider count
- Token distribution

// On-chain Metrics
- Gas usage trends
- Failed transactions
- Contract interactions
- Token transfers
- Staking statistics

// Alerts
- Unusual trading volume
- Large token transfers
- Contract pause events
- Failed provider proofs
```

#### Mobile App Analytics
```dart
// Firebase Analytics Events
- User registration
- Content created (by type)
- Content purchased
- Wallet connected
- Social share
- Provider registered

// User Metrics
- Daily/Monthly Active Users
- Retention (D1, D7, D30)
- Session length
- Feature usage
- Conversion funnels
- Crash reports

// Performance Monitoring
- App load time
- Screen render time
- Network request latency
- IPFS upload speed
- Transaction confirmation time
```

#### Backend Monitoring
```javascript
// Application Metrics
- API response times
- Error rates
- Request throughput
- Database query performance
- IPFS pin success rate
- Indexer lag

// Infrastructure Metrics
- CPU/Memory usage
- Network I/O
- Disk usage
- Container health
- Database connections

// Alerts
- API error rate > 1%
- Response time > 1s
- Database connection pool full
- IPFS pinning failures
- Indexer lag > 10 blocks
```

### 10. Regulatory Considerations

#### Compliance
1. **Securities Law**
   - VLTC may be classified as utility token
   - No investment contract claims
   - Clear utility description
   - Proper disclaimer

2. **Data Privacy**
   - GDPR compliance (EU users)
   - CCPA compliance (CA users)
   - Data deletion on request
   - Privacy policy

3. **Content Moderation**
   - No CSAM (Child Sexual Abuse Material)
   - Illegal content reporting
   - DMCA takedown process
   - Content policy

4. **KYC/AML**
   - Not required for users (decentralized)
   - Required for presale >$10k
   - Provider identification optional
   - Transaction monitoring

#### Legal Documents
```
1. Terms of Service
2. Privacy Policy
3. Cookie Policy
4. Content Policy
5. DMCA Policy
6. Token Sale Agreement
7. Risk Disclosures
8. Disclaimer
```

## Implementation Timeline

### Month 1-2: Foundation
- Week 1-2: Smart contract development
- Week 3-4: Contract testing and optimization
- Week 5-6: Mobile app scaffolding
- Week 7-8: Backend services setup

### Month 3-4: Core Features
- Week 9-10: Content upload/storage
- Week 11-12: Marketplace implementation
- Week 13-14: Wallet integration
- Week 15-16: Social sharing

### Month 5: Testing & Audit
- Week 17-18: Contract audit
- Week 19-20: App beta testing
- Week 21-22: Bug fixes and improvements

### Month 6: Launch Preparation
- Week 23: Testnet deployment
- Week 24: Community building
- Week 25: Presale execution
- Week 26: MAINNET LAUNCH 🚀

### Month 7-12: Growth
- Ongoing feature development
- User acquisition campaigns
- DAO activation
- Ecosystem expansion

## Success Metrics

### Year 1 Targets
- 50,000+ registered users
- 500,000+ content pieces stored
- 100+ active storage providers
- $2M+ in content traded
- 10,000+ DAO participants
- $10M+ market cap (VLTC)
- 95%+ uptime
- <$0.05 avg transaction cost

## Repository Structure

When you're ready to implement, create the following repositories:

```
digitalvault-contracts/
├── contracts/
│   ├── VaultToken.sol
│   ├── ContentRegistry.sol
│   ├── Marketplace.sol
│   ├── StorageProvider.sol
│   ├── RewardDistributor.sol
│   ├── DAOGovernor.sol
│   ├── AccessControl.sol
│   ├── SocialVerification.sol
│   ├── PresaleContract.sol
│   └── AirdropDistributor.sol
├── scripts/
│   ├── deploy.js
│   ├── deploy-testnet.js
│   ├── deploy-mainnet.js
│   ├── initialize.js
│   └── verify.js
├── test/
│   ├── VaultToken.test.js
│   ├── ContentRegistry.test.js
│   ├── Marketplace.test.js
│   └── integration/
└── hardhat.config.js

digitalvault-mobile/
├── lib/
│   ├── main.dart
│   ├── app/
│   ├── core/
│   ├── features/
│   └── shared/
├── test/
├── integration_test/
├── android/
├── ios/
└── pubspec.yaml

digitalvault-backend/
├── services/
│   ├── ipfs-gateway/
│   ├── metadata-indexer/
│   ├── storage-coordinator/
│   └── notification-service/
├── shared/
│   ├── database/
│   ├── utils/
│   └── config/
├── tests/
└── docker-compose.yml

digitalvault-infra/
├── terraform/
│   ├── aws/
│   ├── networking/
│   └── monitoring/
├── kubernetes/
└── scripts/
```

## Final Notes

This is a comprehensive plan for building DigitalVault from scratch. The project emphasizes:

1. **Privacy**: Complete anonymity and encryption
2. **Youth Focus**: Interface and features for 16-25 demographic
3. **Creator Empowerment**: Monetization for amateur creators
4. **Social Integration**: Built-in sharing with ownership proof
5. **Decentralization**: True ownership via blockchain
6. **Economics**: Fair token distribution and sustainable rewards

The implementation should be done iteratively:
1. Start with core contracts (ContentRegistry, Marketplace, VaultToken)
2. Build basic mobile app (wallet, upload, browse)
3. Deploy backend services (IPFS gateway, indexer)
4. Add advanced features (DAO, storage providers, social)
5. Launch with presale and airdrop campaigns

Remember: Move fast, test thoroughly, prioritize security, and listen to your community.

Ready to build the future of creative ownership? Let's go! 🚀
