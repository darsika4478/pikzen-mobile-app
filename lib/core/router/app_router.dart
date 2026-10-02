import '../../features/cart_checkout/widgets/cart_badge.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/admin/screens/admin_users_screen.dart';

import '../../features/auth/providers/auth_provider.dart';

import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/shop_approval_status_screen.dart';
import '../../features/cart_checkout/screens/cart_screen.dart';
import '../../features/cart_checkout/screens/checkout_screen.dart';
import '../../features/cart_checkout/screens/order_confirmation_screen.dart';
import '../../features/cart_checkout/screens/pickup_date_screen.dart';
import '../../features/cart_checkout/screens/pickup_time_screen.dart';
import '../../features/payments_tracking/screens/my_orders_screen.dart';
import '../../features/payments_tracking/screens/customer_order_details_screen.dart';
import '../../features/payments_tracking/screens/notifications_screen.dart';
import '../../features/payments_tracking/screens/notification_detail_screen.dart';
import '../../features/payments_tracking/screens/order_history_screen.dart';
import '../../features/payments_tracking/screens/order_tracking_screen.dart';
import '../../features/payments_tracking/screens/card_payment_screen.dart';
import '../../features/payments_tracking/screens/payment_selection_screen.dart';
import '../../features/payments_tracking/screens/payment_failure_screen.dart';
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
import '../../models/order_model.dart';
import '../../models/notification_model.dart';
import '../../models/payment_model.dart';
import '../../shared/screens/onboarding_screen.dart';
import '../../shared/screens/splash_screen.dart';

// Shared routes. Login destinations are selected from the authenticated profile.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final path = state.uri.path;
    const shopPaths = {
      '/shop-dashboard',
      '/add-edit-product',
      '/incoming-orders',
      '/inventory',
      '/prepare-order',
      '/product-management',
    };
    if (path == '/admin/users' && auth.user?.role != 'admin') {
      return '/login';
    }
    if (path == '/shop-pending' || path == '/shop-rejected') {
      return switch (auth.destination) {
        'shop-pending' when path == '/shop-pending' => null,
        'shop-pending' => '/shop-pending',
        'shop-rejected' when path == '/shop-rejected' => null,
        'shop-rejected' => '/shop-rejected',
        'shop-dashboard' => '/shop-dashboard',
        'customer-home' => '/customer-home',
        AuthProvider.adminRoute => '/admin/users',
        _ => '/login',
      };
    }
    if (shopPaths.contains(path) && auth.user?.isApprovedShop != true) {
      return switch (auth.destination) {
        'shop-pending' => '/shop-pending',
        'shop-rejected' => '/shop-rejected',
        _ => '/login',
      };
    }
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _CustomerNavigationShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => SearchScreen(
            query: state.uri.queryParameters['q'] ?? '',
            category: state.uri.queryParameters['category'],
          ),
        ),
        GoRoute(
          path: '/customer-home',
          name: 'customer-home',
          builder: (context, state) => const CustomerHomeScreen(),
        ),
        GoRoute(
          path: '/categories',
          name: 'categories',
          redirect: (context, state) =>
              state.uri.queryParameters['category'] == null
              ? null
              : Uri(
                  path: '/search',
                  queryParameters: {
                    'category': state.uri.queryParameters['category']!,
                  },
                ).toString(),
          builder: (context, state) =>
              CategoriesScreen(category: state.uri.queryParameters['category']),
        ),
        GoRoute(
          path: '/cart',
          name: 'cart',
          builder: (context, state) => const CartScreen(),
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
        GoRoute(
          path: '/edit-profile',
          name: 'edit-profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/notification-details',
          name: 'notification-details',
          builder: (context, state) => NotificationDetailScreen(
            arguments: state.extra is NotificationDetailArguments
                ? state.extra as NotificationDetailArguments
                : state.extra is NotificationModel
                ? NotificationDetailArguments(
                    notification: state.extra as NotificationModel,
                  )
                : null,
          ),
        ),
        GoRoute(
          path: '/order-history',
          name: 'order-history',
          builder: (context, state) => const OrderHistoryScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/admin/users',
      name: 'admin-users',
      builder: (context, state) => const AdminUsersScreen(),
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
      path: '/shop-pending',
      name: 'shop-pending',
      builder: (context, state) =>
          const ShopApprovalStatusScreen(rejected: false),
    ),
    GoRoute(
      path: '/shop-rejected',
      name: 'shop-rejected',
      builder: (context, state) =>
          const ShopApprovalStatusScreen(rejected: true),
    ),
    GoRoute(
      path: '/checkout',
      name: 'checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/order-confirmation',
      name: 'order-confirmation',
      builder: (context, state) {
        final checkout = PaymentCheckoutData.fromExtra(state.extra);
        return OrderConfirmationScreen(
          orderDraft: checkout.orderDraft,
          amountMinor: checkout.totalMinor,
          currencyCode: checkout.currency,
          orderId: checkout.id,
        );
      },
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
      path: '/order-details',
      name: 'order-details',
      builder: (context, state) => CustomerOrderDetailsScreen(
        order: state.extra is OrderModel ? state.extra as OrderModel : null,
        orderId: state.extra is String ? state.extra as String : null,
      ),
    ),
    GoRoute(
      path: '/order-tracking',
      name: 'order-tracking',
      builder: (context, state) => OrderTrackingScreen(
        order: state.extra is OrderModel ? state.extra as OrderModel : null,
        orderId: state.extra is String ? state.extra as String : null,
      ),
    ),
    GoRoute(
      path: '/payment-method',
      name: 'payment-method',
      builder: (context, state) {
        final args = state.extra is Map ? state.extra as Map : const {};
        final checkout = PaymentCheckoutData.fromExtra(state.extra);
        final selectedMethod = args['selectedMethod'];
        return PaymentMethodScreen(
          amountMinor: checkout.totalMinor,
          currencyCode: checkout.currency,
          orderId: checkout.id,
          selectedMethod: selectedMethod is String ? selectedMethod : 'card',
          orderDraft: checkout.orderDraft,
        );
      },
    ),
    GoRoute(
      path: '/card-payment',
      name: 'card-payment',
      builder: (context, state) {
        final checkout = PaymentCheckoutData.fromExtra(state.extra);
        return CardPaymentScreen(
          amountMinor: checkout.totalMinor,
          currencyCode: checkout.currency,
          orderId: checkout.id,
          orderDraft: checkout.orderDraft,
        );
      },
    ),
    GoRoute(
      path: '/ewallet-payment',
      name: 'ewallet-payment',
      builder: (context, state) => DemoPaymentSelectionScreen(
        method: PaymentMethod.ewallet,
        checkout: PaymentCheckoutData.fromExtra(state.extra),
      ),
    ),
    GoRoute(
      path: '/online-banking-payment',
      name: 'online-banking-payment',
      builder: (context, state) => DemoPaymentSelectionScreen(
        method: PaymentMethod.onlineBanking,
        checkout: PaymentCheckoutData.fromExtra(state.extra),
      ),
    ),
    GoRoute(
      path: '/payment-result',
      name: 'payment-result',
      builder: (context, state) {
        final args = state.extra is Map ? state.extra as Map : const {};
        final orderId = args['orderId'];
        final amountMinor = args['amountMinor'];
        final currencyCode = args['currencyCode'];
        final isDemo = args['isDemo'];
        final order = args['order'];
        final paymentMethod = args['paymentMethod'];
        final paymentStatus = args['paymentStatus'];
        return PaymentResultScreen(
          orderId: orderId is String ? orderId : null,
          amountMinor: amountMinor is int ? amountMinor : null,
          currencyCode: currencyCode is String ? currencyCode : 'LKR',
          isDemo: isDemo is bool ? isDemo : true,
          order: order is OrderModel ? order : null,
          paymentMethod: paymentMethod is String ? paymentMethod : 'card',
          paymentStatus: paymentStatus is String ? paymentStatus : null,
        );
      },
    ),
    GoRoute(
      path: '/payment-failure',
      name: 'payment-failure',
      builder: (context, state) {
        final args = state.extra is Map ? state.extra as Map : const {};
        final checkout = PaymentCheckoutData.fromExtra(state.extra);
        final paymentMethod = args['paymentMethod'];
        return PaymentFailureScreen(
          paymentMethod: paymentMethod is String ? paymentMethod : 'card',
          amountMinor: checkout.totalMinor,
          currencyCode: checkout.currency,
          orderId: checkout.id,
          orderDraft: checkout.orderDraft,
        );
      },
    ),
    GoRoute(
      path: '/product-details',
      name: 'product-details',
      builder: (context, state) => ProductDetailsScreen(
        productId: state.uri.queryParameters['id'] ?? '',
      ),
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
    '/cart',
    '/favourites',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final index = location == '/edit-profile' ? 4 : _paths.indexOf(location);
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
          NavigationDestination(icon: CartBadge(), label: 'Cart'),
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
