import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/order_history_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

void main() {
  final newerOrder = _order(
    id: 'PZ002',
    userId: 'customer-1',
    status: 'completed',
    createdAt: DateTime(2024, 12, 11),
    completedAt: DateTime(2024, 12, 12),
    productName: 'Fresh Milk',
    priceMinor: 1080,
    quantity: 2,
  );
  final olderOrder = _order(
    id: 'PZ001',
    userId: 'customer-1',
    status: 'collected',
    createdAt: DateTime(2024, 12, 10),
    productName: 'Red Apple',
    priceMinor: 3520,
  );

  testWidgets('filters, sorts, searches, and opens the selected order', (
    tester,
  ) async {
    final router = _router(
      orders: [
        olderOrder,
        _order(
          id: 'ongoing',
          userId: 'customer-1',
          status: 'preparing',
          createdAt: DateTime(2024, 12, 13),
        ),
        newerOrder,
        _order(
          id: 'private',
          userId: 'another-customer',
          status: 'completed',
          createdAt: DateTime(2024, 12, 14),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );

    expect(find.text('Order History'), findsOneWidget);
    expect(find.text('#PZ002'), findsOneWidget);
    expect(find.text('#PZ001'), findsOneWidget);
    expect(find.text('#ongoing'), findsNothing);
    expect(find.text('#private'), findsNothing);
    expect(find.text('LKR 21.60'), findsOneWidget);
    expect(find.text('LKR 35.20'), findsOneWidget);
    expect(find.text('12 Dec 2024'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('#PZ002')).dy,
      lessThan(tester.getTopLeft(find.text('#PZ001')).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'does-not-exist');
    await tester.pumpAndSettle();
    expect(find.text('No matching orders found.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pZ001');
    await tester.pumpAndSettle();
    expect(find.text('#PZ001'), findsOneWidget);
    expect(find.text('#PZ002'), findsNothing);

    await tester.tap(find.text('#PZ001'));
    await tester.pumpAndSettle();
    expect(find.text('Order Details for PZ001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows separate empty-history and no-search-results states', (
    tester,
  ) async {
    final router = _router(
      orders: [
        _order(
          id: 'still-preparing',
          userId: 'customer-1',
          status: 'preparing',
          createdAt: DateTime(2024, 12, 12),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    expect(find.text('No past orders yet.'), findsOneWidget);
  });

  testWidgets('shows loading and a safe error state for a live source', (
    tester,
  ) async {
    final pending = StreamController<List<OrderModel>>();
    addTearDown(pending.close);
    final router = _router(ordersStream: pending.stream);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.addError(StateError('sensitive repository detail'));
    await tester.pump();
    expect(
      find.text('Order history is unavailable right now.'),
      findsOneWidget,
    );
    expect(find.text('sensitive repository detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

OrderModel _order({
  required String id,
  required String userId,
  required String status,
  required DateTime createdAt,
  DateTime? completedAt,
  String? productName,
  int priceMinor = 0,
  int quantity = 1,
}) => OrderModel(
  id: id,
  userId: userId,
  status: status,
  createdAt: createdAt,
  completedAt: completedAt,
  items: productName == null
      ? const []
      : [
          CartItemModel(
            product: ProductModel(
              id: productName.toLowerCase().replaceAll(' ', '-'),
              name: productName,
              priceMinor: priceMinor,
              currencyCode: 'LKR',
            ),
            quantity: quantity,
          ),
        ],
);

GoRouter _router({
  List<OrderModel> orders = const [],
  Stream<List<OrderModel>>? ordersStream,
}) => GoRouter(
  initialLocation: '/order-history',
  routes: [
    GoRoute(
      path: '/order-history',
      name: 'order-history',
      builder: (context, state) => OrderHistoryScreen(
        currentUserId: 'customer-1',
        orders: orders,
        ordersStream: ordersStream,
      ),
    ),
    GoRoute(
      path: '/order-details',
      name: 'order-details',
      builder: (context, state) {
        final order = state.extra as OrderModel;
        return Scaffold(
          body: Center(child: Text('Order Details for ${order.id}')),
        );
      },
    ),
    GoRoute(
      path: '/my-orders',
      name: 'my-orders',
      builder: (context, state) => const Scaffold(body: Text('My Orders')),
    ),
  ],
);
