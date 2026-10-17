import 'package:flutter/material.dart';
import '../features/auth/wallet_connect_page.dart';
import '../features/home/home_page.dart';
import '../features/content/create_content_page.dart';
import '../features/marketplace/marketplace_page.dart';
import '../features/governance/dao_page.dart';
import '../features/transactions/transaction_history_page.dart';

// Splash Page
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToWalletConnect();
  }

  Future<void> _navigateToWalletConnect() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(Routes.walletSetup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 16),
            const Text(
              'DigitalVault',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class Routes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String walletSetup = '/wallet-setup';
  static const String home = '/home';
  static const String createContent = '/create-content';
  static const String portfolio = '/portfolio';
  static const String marketplace = '/marketplace';
  static const String dao = '/dao';
  static const String wallet = '/wallet';
  static const String settings = '/settings';
  static const String transactions = '/transactions';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case walletSetup:
        return MaterialPageRoute(builder: (_) => const WalletConnectPage());
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case createContent:
        return MaterialPageRoute(builder: (_) => const CreateContentPage());
      case marketplace:
        return MaterialPageRoute(builder: (_) => const MarketplacePage());
      case dao:
        return MaterialPageRoute(builder: (_) => const DAOPage());
      case transactions:
        return MaterialPageRoute(builder: (_) => const TransactionHistoryPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
