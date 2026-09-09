import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Temporary testing navigation to the existing placeholder screens.
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Home')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Temporary testing navigation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Forgot Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('forgot-password'),
            ),
            ListTile(
              title: const Text('Login'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('login'),
            ),
            ListTile(
              title: const Text('Sign Up'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('signup'),
            ),
            ListTile(
              title: const Text('Cart'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('cart'),
            ),
            ListTile(
              title: const Text('Checkout'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('checkout'),
            ),
            ListTile(
              title: const Text('Order Confirmation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('order-confirmation'),
            ),
            ListTile(
              title: const Text('Pickup Date'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('pickup-date'),
            ),
            ListTile(
              title: const Text('Pickup Time'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('pickup-time'),
            ),
            ListTile(
              title: const Text('My Orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('my-orders'),
            ),
            ListTile(
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('notifications'),
            ),
            ListTile(
              title: const Text('Order Tracking'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('order-tracking'),
            ),
            ListTile(
              title: const Text('Payment Method'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('payment-method'),
            ),
            ListTile(
              title: const Text('Payment Result'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('payment-result'),
            ),

            ListTile(
              title: const Text('Product Details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('product-details'),
            ),

            ListTile(
              title: const Text('Edit Profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('edit-profile'),
            ),

            ListTile(
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('settings'),
            ),
            ListTile(
              title: const Text('Add/Edit Product'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('add-edit-product'),
            ),
            ListTile(
              title: const Text('Incoming Orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('incoming-orders'),
            ),
            ListTile(
              title: const Text('Inventory / Stock Update'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('inventory'),
            ),
            ListTile(
              title: const Text('Prepare Order / Order Details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('prepare-order'),
            ),
            ListTile(
              title: const Text('Product Management'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('product-management'),
            ),
            ListTile(
              title: const Text('Shop Dashboard'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('shop-dashboard'),
            ),
            ListTile(
              title: const Text('Onboarding'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('onboarding'),
            ),
            ListTile(
              title: const Text('Splash'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('splash'),
            ),
          ],
        ),
      ),
    );
  }
}
