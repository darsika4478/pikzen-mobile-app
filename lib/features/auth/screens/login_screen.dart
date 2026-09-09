import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';

/// Placeholder login with temporary testing navigation only.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.login)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.login,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text('Temporary testing navigation'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.goNamed('customer-home'),
                  child: const Text(AppStrings.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
