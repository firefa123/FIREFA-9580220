import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/modules/persistent_cart_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirefaPersistentCartStore.instance.initialize();
  runApp(const FirefaApp());
}

class FirefaApp extends StatelessWidget {
  const FirefaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIREFA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const FirefaHomePage(),
    );
  }
}

class FirefaHomePage extends StatelessWidget {
  const FirefaHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 72,
                  color: AppTheme.primary,
                ),

                const SizedBox(height: 24),

                const Text(
                  'FIREFA',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Restaurant Operating System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,

                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },

                    child: const Text(
                      'Mulai Sekarang',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'FIREFA-9580220',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}