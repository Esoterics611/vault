import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/wallet_provider.dart';

class WalletConnectPage extends ConsumerStatefulWidget {
  const WalletConnectPage({super.key});

  @override
  ConsumerState<WalletConnectPage> createState() => _WalletConnectPageState();
}

class _WalletConnectPageState extends ConsumerState<WalletConnectPage> {
  final _privateKeyController = TextEditingController();
  bool _showPrivateKeyField = false; // mobile only — hidden by default on web

  // ─── Browser wallet (web) ──────────────────────────────────────────────────

  Future<void> _connectBrowserWallet() async {
    await ref.read(walletProvider.notifier).connectWithBrowserWallet();
    _handleResult();
  }

  // ─── Private key (mobile / dev) ───────────────────────────────────────────

  Future<void> _connectWithPrivateKey() async {
    final privateKey = _privateKeyController.text.trim();
    if (privateKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a private key')),
      );
      return;
    }
    await ref.read(walletProvider.notifier).connectWallet(privateKey);
    _handleResult();
  }

  void _handleResult() {
    final walletState = ref.read(walletProvider);
    if (!mounted) return;

    if (walletState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected: ${walletState.address?.substring(0, 10)}…'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (walletState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(walletState.error!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _privateKeyController.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ──────────────────────────────────────────────────
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Color(0xFF6C63FF),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'DigitalVault',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Base Sepolia Testnet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // ── Web: MetaMask button ───────────────────────────────────
                  if (kIsWeb) ...[
                    _ConnectWalletButton(
                      isLoading: walletState.isLoading,
                      onPressed: _connectBrowserWallet,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Works with Base Wallet, MetaMask, Coinbase Wallet, and any browser wallet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 8),
                    // Dev escape hatch: show private key option
                    TextButton(
                      onPressed: () => setState(
                          () => _showPrivateKeyField = !_showPrivateKeyField),
                      child: Text(
                        _showPrivateKeyField
                            ? 'Hide dev options'
                            : 'Use private key (dev only)',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],

                  // ── Mobile: always show private key ───────────────────────
                  if (!kIsWeb || _showPrivateKeyField) ...[
                    if (kIsWeb) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        '⚠️  Dev only — never use a real private key here',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _privateKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Private Key',
                        hintText: '0x…',
                        prefixIcon: const Icon(Icons.key),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: walletState.error,
                      ),
                      onSubmitted: (_) => _connectWithPrivateKey(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          walletState.isLoading ? null : _connectWithPrivateKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: walletState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Connect with Key',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],

                  // ── Connected status ───────────────────────────────────────
                  if (walletState.isConnected) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connected',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(walletState.address ?? '',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ETH: ${walletState.formattedEthBalance}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                              Text('VLTC: ${walletState.formattedVltcBalance}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Error ──────────────────────────────────────────────────
                  if (walletState.error != null && !walletState.isConnected) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        walletState.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Generic wallet connect button ────────────────────────────────────────────

class _ConnectWalletButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _ConnectWalletButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.account_balance_wallet,
                        color: Color(0xFF6C63FF), size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Connect Wallet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }
}
