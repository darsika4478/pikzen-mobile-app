import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/cart_checkout/screens/cart_screen.dart';
import '../../features/cart_checkout/screens/checkout_screen.dart';
import '../../features/cart_checkout/screens/order_confirmation_screen.dart';
import '../../features/cart_checkout/screens/pickup_date_screen.dart';
import '../../features/cart_checkout/screens/pickup_time_screen.dart';
import '../../features/payments_tracking/screens/my_orders_screen.dart';
import '../../features/payments_tracking/screens/notifications_screen.dart';
import '../../features/payments_tracking/screens/order_tracking_screen.dart';
import '../../features/payments_tracking/screens/payment_method_screen.dart';
import '../../features/payments_tracking/screens/payment_result_screen.dart';
import '../../features/product_discovery/screens/categories_screen.dart';
import '../../features/product_discovery/screens/customer_home_screen.dart';
import '../../features/product_discovery/screens/favourites_screen.dart';
import '../../features/product_discovery/screens/product_details_screen.dart';
import '../../features/product_discovery/screens/search_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/shop_management/screens/add_edit_product_screen.dart';
import '../../features/shop_management/screens/incoming_orders_screen.dart';
import '../../features/shop_management/screens/inventory_screen.dart';
import '../../features/shop_management/screens/prepare_order_screen.dart';
import '../../features/shop_management/screens/product_management_screen.dart';
import '../../features/shop_management/screens/shop_dashboard_screen.dart';
import '../../shared/screens/onboarding_screen.dart';
import '../../shared/screens/splash_screen.dart';

// Temporary testing navigation. No authentication checks are performed.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _CustomerNavigationShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/customer-home',
          name: 'customer-home',
          builder: (context, state) => const CustomerHomeScreen(),
        ),
        GoRoute(
          path: '/categories',
          name: 'categories',
          builder: (context, state) => const CategoriesScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/favourites',
          name: 'favourites',
          builder: (context, state) => const FavouritesScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(path: '/', redirect: (context, state) => '/splash'),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/cart',
      name: 'cart',
      builder: (context, state) => const CartScreen(),
    ),
    GoRoute(
      path: '/checkout',
      name: 'checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/order-confirmation',
      name: 'order-confirmation',
      builder: (context, state) => const OrderConfirmationScreen(),
    ),
    GoRoute(
      path: '/pickup-date',
      name: 'pickup-date',
      builder: (context, state) => const PickupDateScreen(),
    ),
    GoRoute(
      path: '/pickup-time',
      name: 'pickup-time',
      builder: (context, state) => const PickupTimeScreen(),
    ),
    GoRoute(
      path: '/my-orders',
      name: 'my-orders',
      builder: (context, state) => const MyOrdersScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/order-tracking',
      name: 'order-tracking',
      builder: (context, state) => const OrderTrackingScreen(),
    ),
    GoRoute(
      path: '/payment-method',
      name: 'payment-method',
      builder: (context, state) => const PaymentMethodScreen(),
    ),
    GoRoute(
      path: '/payment-result',
      name: 'payment-result',
      builder: (context, state) => const PaymentResultScreen(),
    ),

    GoRoute(
      path: '/product-details',
      name: 'product-details',
      builder: (context, state) => const ProductDetailsScreen(),
    ),

    GoRoute(
      path: '/edit-profile',
      name: 'edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),

    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/add-edit-product',
      name: 'add-edit-product',
      builder: (context, state) => const AddEditProductScreen(),
    ),
    GoRoute(
      path: '/incoming-orders',
      name: 'incoming-orders',
      builder: (context, state) => const IncomingOrdersScreen(),
    ),
    GoRoute(
      path: '/inventory',
      name: 'inventory',
      builder: (context, state) => const InventoryScreen(),
    ),
    GoRoute(
      path: '/prepare-order',
      name: 'prepare-order',
      builder: (context, state) => const PrepareOrderScreen(),
    ),
    GoRoute(
      path: '/product-management',
      name: 'product-management',
      builder: (context, state) => const ProductManagementScreen(),
    ),
    GoRoute(
      path: '/shop-dashboard',
      name: 'shop-dashboard',
      builder: (context, state) => const ShopDashboardScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
  ],
);

/// Temporary customer navigation shared by the five existing tab screens.
class _CustomerNavigationShell extends StatelessWidget {
  const _CustomerNavigationShell({required this.location, required this.child});

  final String location;
  final Widget child;

  static const _paths = [
    '/customer-home',
    '/categories',
    '/search',
    '/favourites',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final index = _paths.indexOf(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            label: 'Categories',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'Favourites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
