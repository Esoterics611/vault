# DigitalVault — Flutter App

Flutter web/mobile app for the DigitalVault platform.
Targets **Base Sepolia** testnet. Browser wallet connect via EIP-1193.

## Running

### Web (recommended for development)
```bash
flutter build web --release
cd build/web && python3 -m http.server 8080
# Open http://localhost:8080 in Chrome with MetaMask / Base Wallet installed
```

### Mobile
```bash
flutter run   # connects to Android/iOS device or emulator
```

## Architecture

```
lib/
├── app/
│   ├── app.dart            # Root widget + MaterialApp
│   ├── routes.dart         # Named routes
│   └── theme.dart          # Dark theme, #6C63FF accent
├── core/
│   ├── constants/
│   │   └── contract_addresses.dart   # On-chain addresses per chainId
│   ├── providers/
│   │   └── wallet_provider.dart      # WalletState + WalletNotifier (Riverpod)
│   └── services/
│       ├── web3_service.dart         # Web3Client wrapper (private key + browser wallet)
│       ├── contract_service.dart     # Contract call helpers
│       ├── ethereum_bridge.dart      # Conditional export: web vs stub
│       ├── ethereum_bridge_web.dart  # dart:js_util → window.ethereumBridge
│       └── ethereum_bridge_stub.dart # Mobile stub (throws UnsupportedError)
└── features/
    ├── auth/
    │   └── wallet_connect_page.dart  # Login screen — browser wallet on web
    ├── home/
    └── portfolio/                    # Blockchain content display
```

## Wallet connect flow

1. User clicks "Connect Wallet" on web
2. `EthereumBridge.requestAccounts()` → wallet popup (authorize)
3. `EthereumBridge.switchToBaseSepolia()` → switch chain (skipped if already on 84532)
4. `Web3Service.initWithBrowserWallet()` → set address, init RPC client
5. `WalletState` updated with address + ETH + VLTC balances

Write transactions (on web) are ABI-encoded locally via `web3dart`, then handed to the wallet
via `EthereumBridge.sendTransaction()` → `window.ethereum.request({ method: 'eth_sendTransaction' })`.

## JS bridge

`web/ethereum_bridge.js` is loaded in `web/index.html` before `flutter_bootstrap.js`.
It exposes `window.ethereumBridge` with: `isAvailable`, `requestAccounts`,
`getChainId`, `switchToBaseSepolia`, `sendTransaction`, `onAccountsChanged`.

## State management

Riverpod providers:
- `web3ServiceProvider` — shared `Web3Service` instance
- `contractServiceProvider` — shared `ContractService` instance
- `walletProvider` — `StateNotifierProvider<WalletNotifier, WalletState>`
- `walletAutoRefreshProvider` — `StreamProvider` refreshing balances every 30s

## Key dependencies

```yaml
flutter_riverpod: ^2.x
web3dart: ^2.x
http: ^1.x
```

## Environment notes

- No `.env` file in the Flutter app — config lives in `lib/core/constants/`
- Chain ID is hardcoded to `84532` (Base Sepolia) throughout
- `kIsWeb` guards all browser-wallet code — mobile path uses private key
