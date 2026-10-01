import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/customer_order_details_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/order_tracking_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

void main() {
  final order = OrderModel(
    id: 'PZ-4821',
    userId: 'customer-1',
    createdAt: DateTime(2026, 7, 3, 8),
    pickupAt: DateTime(2026, 7, 4, 10),
    items: [
      CartItemModel(
        product: const ProductModel(
          id: 'apple',
          name: 'Red Apple',
          priceMinor: 590,
          currencyCode: 'LKR',
        ),
        quantity: 2,
      ),
      CartItemModel(
        product: const ProductModel(
          id: 'milk',
          name: 'Fresh Milk',
          priceMinor: 690,
          currencyCode: 'LKR',
        ),
        quantity: 1,
      ),
    ],
  );

  testWidgets(
    'shows selected order data and keeps it through tracking navigation',
    (tester) async {
      final router = _router(order);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );

      expect(find.text('#PZ-4821'), findsOneWidget);
      expect(find.text('4 Jul 2026'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('ITEMS (2)'), findsOneWidget);
      expect(find.text('Red Apple'), findsOneWidget);
      expect(find.text('Quantity: 2'), findsOneWidget);
      expect(find.text('LKR 11.80'), findsOneWidget);
      expect(find.text('Fresh Milk'), findsOneWidget);
      expect(find.text('LKR 6.90'), findsOneWidget);
      expect(find.text('LKR 18.70'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel Order'),
      );
      expect(cancelButton.onPressed, isNull);

      await tester.tap(find.text('Track Order'));
      await tester.pumpAndSettle();
      expect(find.text('Track Your Order'), findsOneWidget);
      expect(find.text('PIKZEN PICKUP'), findsOneWidget);
      expect(find.text('#PZ-4821'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('Status unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back to Order Details'));
      await tester.pumpAndSettle();
      expect(find.text('Order Details'), findsOneWidget);

      await tester.tap(find.text('Track Order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Order Details'));
      await tester.pumpAndSettle();
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Red Apple'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing order shows an explanatory empty state', (tester) async {
    final router = _router(null);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );

    expect(find.text('Order details unavailable'), findsOneWidget);
    expect(
      find.text('Open this page from an order in My Orders.'),
      findsOneWidget,
    );
    expect(find.text('Track Order'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router(OrderModel? order) => GoRouter(
  initialLocation: '/order-details',
  routes: [
    GoRoute(
      path: '/order-details',
      name: 'order-details',
      builder: (context, state) => CustomerOrderDetailsScreen(order: order),
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
      path: '/my-orders',
      name: 'my-orders',
      builder: (context, state) => const Scaffold(body: Text('My Orders')),
    ),
  ],
);
