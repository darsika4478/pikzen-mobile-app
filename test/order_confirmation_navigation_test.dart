import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/cart_checkout/screens/order_placed_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

class _ConfirmationOrders extends OrderService {
  _ConfirmationOrders(this.order);
  final OrderModel order;

  @override
  Stream<OrderModel?> watchOrder(String orderId) => Stream.value(order);

  @override
  Future<void> markCustomerView(String orderId, String field) async {}
}

void main() {
  final order = OrderModel(
    id: 'PZ202412001',
    userId: 'customer-1',
    createdAt: DateTime(2026, 9, 12),
    pickupAt: DateTime(2026, 9, 13, 10),
    status: 'placed',
    totalMinor: 106200,
    paymentMethod: 'card',
    paymentStatus: 'demo',
    items: [
      CartItemModel(
        product: const ProductModel(
          id: 'apple',
          name: 'Red Apple',
          priceMinor: 10500,
          currencyCode: 'LKR',
        ),
        quantity: 2,
      ),
    ],
  );

  GoRouter router() => GoRouter(
    initialLocation: '/order-confirmation',
    routes: [
      GoRoute(
        path: '/order-confirmation',
        name: 'order-confirmation',
        builder: (_, _) => OrderPlacedScreen(
          orderId: order.id,
          orderService: _ConfirmationOrders(order),
        ),
      ),
      GoRoute(
        path: '/my-orders',
        name: 'my-orders',
        builder: (_, _) => const Scaffold(body: Text('My Orders')),
      ),
      GoRoute(
        path: '/order-details',
        name: 'order-details',
        builder: (_, state) => Scaffold(body: Text('Order ${state.extra}')),
      ),
      GoRoute(
        path: '/customer-home',
        name: 'customer-home',
        builder: (_, _) => const Scaffold(body: Text('Customer Home')),
      ),
      GoRoute(
        path: '/order-tracking',
        name: 'order-tracking',
        builder: (_, state) => Scaffold(body: Text('Tracking ${state.extra}')),
      ),
    ],
  );

  testWidgets('View Order opens the saved order with no payment back stack', (
    tester,
  ) async {
    final appRouter = router();
    addTearDown(appRouter.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: appRouter),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Order'));
    await tester.pumpAndSettle();
    expect(find.text('Order ${order.id}'), findsOneWidget);
    expect(appRouter.canPop(), isFalse);
  });

  testWidgets('Back to Home goes to existing customer home', (tester) async {
    final appRouter = router();
    addTearDown(appRouter.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: appRouter),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Customer Home'), findsOneWidget);
    expect(appRouter.canPop(), isFalse);
  });
}
