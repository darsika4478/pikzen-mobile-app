import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/my_orders_screen.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

class _ListingService extends OrderService {
  _ListingService(this.orders) {
    changes = StreamController<List<OrderModel>>.broadcast(
      onListen: () => scheduleMicrotask(() => changes.add(orders)),
    );
  }

  List<OrderModel> orders;
  late final StreamController<List<OrderModel>> changes;
  String? queriedCustomer;
  final List<String> viewedOrders = [];

  @override
  Stream<List<OrderModel>> forCustomer(String customerId) {
    queriedCustomer = customerId;
    return changes.stream;
  }

  @override
  Future<void> markCustomerView(String orderId, String field) async {
    if (field == 'ordersListViewedAt') viewedOrders.add(orderId);
  }

  void publish(List<OrderModel> next) {
    orders = next;
    changes.add(next);
  }

  Future<void> dispose() => changes.close();
}

OrderModel _listingOrder(String id, String status) => OrderModel(
  id: id,
  userId: 'customer-1',
  status: status,
  createdAt: DateTime(2026, 9, 12),
  totalMinor: 2160,
  items: [
    CartItemModel(
      product: const ProductModel(
        id: 'apple',
        name: 'Apple',
        priceMinor: 2160,
        currencyCode: 'LKR',
      ),
      quantity: 1,
    ),
  ],
);

void main() {
  testWidgets(
    'reads customer orders, filters, and updates badges from stream',
    (tester) async {
      final service = _ListingService([
        _listingOrder('PZ-A', 'preparing'),
        _listingOrder('PZ-B', 'collected'),
        _listingOrder('PZ-C', 'cancelled'),
      ]);
      addTearDown(service.dispose);
      final router = GoRouter(
        initialLocation: '/my-orders',
        routes: [
          GoRoute(
            path: '/my-orders',
            name: 'my-orders',
            builder: (_, _) =>
                MyOrdersScreen(customerId: 'customer-1', orderService: service),
          ),
          GoRoute(
            path: '/order-details',
            name: 'order-details',
            builder: (_, state) =>
                Scaffold(body: Text('Details ${state.extra}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(service.queriedCustomer, 'customer-1');
      expect(service.viewedOrders, containsAll(['PZ-A', 'PZ-B', 'PZ-C']));
      expect(find.text('#PZ-A'), findsOneWidget);
      expect(find.text('#PZ-B'), findsOneWidget);
      expect(find.text('#PZ-C'), findsOneWidget);
      expect(find.text('Rs. 21.60'), findsNWidgets(3));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ongoing'));
      await tester.pumpAndSettle();
      expect(find.text('#PZ-A'), findsOneWidget);
      expect(find.text('#PZ-B'), findsNothing);
      service.publish([
        _listingOrder('PZ-A', 'ready'),
        _listingOrder('PZ-B', 'collected'),
        _listingOrder('PZ-C', 'cancelled'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Ready for Pickup'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      expect(find.text('#PZ-A'), findsNothing);
      expect(find.text('#PZ-B'), findsOneWidget);
      expect(find.text('#PZ-C'), findsOneWidget);
      await tester.tap(find.text('#PZ-C'));
      await tester.pumpAndSettle();
      expect(find.text('Details PZ-C'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the empty state and keeps filters and Past Orders usable',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/my-orders',
        routes: [
          GoRoute(
            path: '/my-orders',
            name: 'my-orders',
            builder: (context, state) => const MyOrdersScreen(),
          ),
          GoRoute(
            path: '/customer-home',
            name: 'customer-home',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Customer Home'))),
          ),
          GoRoute(
            path: '/order-history',
            name: 'order-history',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Order History'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );

      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('Start Shopping'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ongoing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Ongoing'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
            .selected,
        isTrue,
      );

      await tester.tap(find.byTooltip('Past Orders'));
      await tester.pumpAndSettle();
      expect(find.text('Order History'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('My Orders'), findsOneWidget);

      await tester.tap(find.text('Start Shopping'));
      await tester.pumpAndSettle();
      expect(find.text('Customer Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
