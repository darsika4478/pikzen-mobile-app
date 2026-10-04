import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/customer_order_details_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/order_cancellation_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

class _OrderServiceStub extends OrderService {
  _OrderServiceStub(this.current);

  OrderModel current;
  final StreamController<OrderModel?> changes = StreamController.broadcast();
  int cancellationCount = 0;
  CancellationReason? savedReason;
  String? savedNote;

  @override
  Stream<OrderModel?> watchOrder(String orderId) async* {
    yield current;
    yield* changes.stream;
  }

  @override
  Future<void> markCustomerView(String orderId, String field) async {}

  @override
  Future<void> cancelOrder(
    String orderId, {
    required CancellationReason reason,
    String? note,
  }) async {
    if (orderId != current.id ||
        !OrderService.canCustomerCancel(current.status)) {
      throw const OrderActionException(
        'This order can no longer be cancelled.',
      );
    }
    cancellationCount++;
    savedReason = reason;
    savedNote = note;
    current = current.copyWith(status: 'cancelled');
    changes.add(current);
  }

  Future<void> dispose() => changes.close();
}

OrderModel _order({String status = 'preparing'}) => OrderModel(
  id: 'PZ202412001',
  userId: 'customer-1',
  createdAt: DateTime(2026, 9, 12, 9),
  pickupAt: DateTime(2026, 9, 12, 10),
  status: status,
  paymentMethod: 'card',
  paymentStatus: 'demo',
  totalMinor: 106200,
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

GoRouter _router(_OrderServiceStub service) => GoRouter(
  initialLocation: '/order-details',
  routes: [
    GoRoute(
      path: '/order-details',
      name: 'order-details',
      builder: (_, state) => CustomerOrderDetailsScreen(
        orderId: state.extra is Map
            ? (state.extra as Map)['orderId'] as String?
            : service.current.id,
        orderService: service,
        showCancellationSuccess:
            state.extra is Map &&
            (state.extra as Map)['showCancellationSuccess'] == true,
      ),
    ),
    GoRoute(
      path: '/order-cancellation',
      name: 'order-cancellation',
      builder: (_, state) => OrderCancellationScreen(
        orderId: state.extra is OrderModel
            ? (state.extra as OrderModel).id
            : state.extra as String?,
        orderService: service,
      ),
    ),
    GoRoute(
      path: '/my-orders',
      name: 'my-orders',
      builder: (_, _) => const Scaffold(body: Text('My Orders')),
    ),
  ],
);

void main() {
  testWidgets('reason, No, Yes, and live cancelled status follow one order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _OrderServiceStub(_order());
    final router = _router(service);
    addTearDown(router.dispose);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preparing'), findsOneWidget);

    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderCancellationScreen), findsOneWidget);
    expect(find.text('#PZ202412001'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -330));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Cancel Order'));
    await tester.pump();
    expect(find.text('Please select a cancellation reason.'), findsOneWidget);
    expect(service.cancellationCount, 0);

    await tester.tap(find.text('Changed my mind'));
    await tester.enterText(find.byType(TextField), 'Please cancel');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -330));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Cancel Order'));
    await tester.pumpAndSettle();
    expect(
      find.text('Are you sure you want to cancel this order?'),
      findsOneWidget,
    );
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderCancellationScreen), findsOneWidget);
    expect(find.text('Please cancel'), findsOneWidget);
    expect(service.cancellationCount, 0);

    await tester.tap(find.text('Yes, Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('The order has cancelled!'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(service.cancellationCount, 1);
    expect(service.savedReason, CancellationReason.changedMind);
    expect(service.savedNote, 'Please cancel');
    expect(find.byType(CustomerOrderDetailsScreen), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    final cancelButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel Order'),
    );
    expect(cancelButton.onPressed, isNull);
  });

  testWidgets('Keep Order returns without changing the order', (tester) async {
    final service = _OrderServiceStub(_order());
    final router = _router(service);
    addTearDown(router.dispose);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Changed my mind'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -330));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep Order'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerOrderDetailsScreen), findsOneWidget);
    expect(service.current.status, 'preparing');
    expect(service.cancellationCount, 0);
  });

  testWidgets('ready orders cannot open cancellation', (tester) async {
    final service = _OrderServiceStub(_order(status: 'ready'));
    final router = _router(service);
    addTearDown(router.dispose);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    final cancelButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel Order'),
    );
    expect(cancelButton.onPressed, isNull);
  });
}
