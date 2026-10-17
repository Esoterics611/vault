# DigitalVault

[![Contract tests](https://github.com/Esoterics611/vault/actions/workflows/test.yml/badge.svg)](https://github.com/Esoterics611/vault/actions/workflows/test.yml)

**Own your content the way you own a token.** Creators encrypt their work, store it on IPFS, and sell access on Base. When a buyer pays, a proxy re-encryption service hands them a decryption key without the content key ever being exposed, not even to the platform.

| | |
|---|---|
| **Network** | Base Sepolia (chain 84532) |
| **Contracts** | 4 deployed, source verified on Blockscout |
| **Tests** | 142 passing (`digitalvault-contracts`) |
| **Stack** | Solidity 0.8.24 · Flutter web/mobile · Node.js services · IPFS (Pinata) · PostgreSQL |

## How it works

```
 Creator                         Base Sepolia                        Buyer
 ───────                         ────────────                        ─────
 encrypt file (AES-256-GCM)
 upload ciphertext ──► IPFS
 register content ─────────────► ContentRegistry
 list for sale ────────────────► Marketplace ◄──────────────── pay in VLTC
                                 ReKeyRegistry ◄── re-key grant
                                       │
                          pre-proxy service re-encrypts the
                          content key for the buyer's public key
                                       │
                                       └──────────────────────► decrypt locally
```

The content key is wrapped for the creator and re-wrapped for each buyer with proxy re-encryption (PRE). The proxy only ever handles re-encryption keys, so it cannot read the content.

## Live contracts (Base Sepolia)

| Contract | Role | Address |
|---|---|---|
| VaultToken (VLTC) | ERC-20 with voting checkpoints, permit, pause | [`0x9583…70D3`](https://base-sepolia.blockscout.com/address/0x9583d1643354B9C254586966343D54bCB79970D3?tab=contract) |
| ContentRegistry | Ownership record for each piece of content | [`0xd469…41f0`](https://base-sepolia.blockscout.com/address/0xd469e2AA709bb01ab409eBb762c655FC641C41f0?tab=contract) |
| ReKeyRegistry | On-chain log of re-encryption grants | [`0xBC83…43aA`](https://base-sepolia.blockscout.com/address/0xBC835256b0D08DFeD09c7cE3B07eD945C6e243aA?tab=contract) |
| Marketplace | Listings, purchases and fees in VLTC | [`0xC763…91c5`](https://base-sepolia.blockscout.com/address/0xC763Ea95626100C0128c0d28E6DdED873eba91c5?tab=contract) |

## Repository

```
vault/
├── digitalvault-contracts/   Solidity contracts, Hardhat tests, deploy scripts
├── digitalvault-backend/
│   └── services/
│       ├── ipfs-gateway/     upload and fetch encrypted content      :3000
│       ├── pre-proxy/        proxy re-encryption of content keys
│       ├── dao-service/      VLTC governance voting
│       └── metadata-indexer/ indexes contract events
├── digitalvault-mobile/      Flutter app (web and mobile), EIP-1193 wallet connect
└── docs/                     specification, API reference, local setup
```

## Run it locally

```bash
# contracts
cd digitalvault-contracts && npm install && npx hardhat test

# IPFS gateway
cd digitalvault-backend/services/ipfs-gateway && npm install && node server.js   # http://localhost:3000

# web app
cd digitalvault-mobile && flutter build web --release
cd build/web && python3 -m http.server 8080                                     # http://localhost:8080
```

Copy each service's `.env.example` to `.env` and fill in your own values.

## Documentation

- [docs/PROJECT_SPEC.md](docs/PROJECT_SPEC.md) — technical specification
- [docs/API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md) — backend API reference
- [docs/MVP_SCOPE.md](docs/MVP_SCOPE.md) — what the MVP includes

## Security

Content is encrypted on the device before upload, and keys never leave it. `.env` files are git-ignored; never commit real keys. This is a testnet deployment and has not been audited.
