import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/constants/app_colors.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/core/services/payment_service.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/payments_tracking/screens/card_payment_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/order_tracking_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_result_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

const product = ProductModel(
  id: 'apple',
  name: 'Apple',
  priceMinor: 106000,
  currencyCode: 'LKR',
  stockQuantity: 10,
);

OrderModel draft({String status = 'placed'}) => OrderModel(
  id: 'order-123',
  userId: 'customer-1',
  createdAt: DateTime(2026, 10, 3, 9),
  pickupAt: DateTime(2026, 10, 4, 10),
  replacementPreference: 'contactMe',
  items: const [CartItemModel(product: product, quantity: 1)],
  totalMinor: 106000,
  currencyCode: 'LKR',
  status: status,
);

class RecordingOrders extends OrderService {
  RecordingOrders({this.gate, this.fail = false});
  final Completer<void>? gate;
  bool fail;
  int calls = 0;
  final saved = <String, OrderModel>{};

  @override
  Future<OrderModel> createOrderOnce(
    OrderModel value, {
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    if (fail) throw const OrderActionException('Save failed');
    return saved.putIfAbsent(
      value.id,
      () => value.copyWith(
        status: 'placed',
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
      ),
    );
  }
}

GoRouter router(OrderModel order, RecordingOrders orders) => GoRouter(
  initialLocation: '/card-payment',
  routes: [
    GoRoute(
      path: '/card-payment',
      name: 'card-payment',
      builder: (_, _) => CardPaymentScreen(
        orderDraft: order,
        demoPayments: DemoPaymentService(orders: orders),
      ),
    ),
    GoRoute(
      path: '/payment-result',
      name: 'payment-result',
      builder: (_, state) {
        final args = state.extra as Map<String, Object?>;
        return PaymentResultScreen(
          order: args['order'] as OrderModel,
          orderId: args['orderId'] as String,
        );
      },
    ),
    GoRoute(
      path: '/order-confirmation',
      name: 'order-confirmation',
      builder: (_, state) => Scaffold(body: Text('Saved order ${state.extra}')),
    ),
    GoRoute(
      path: '/customer-home',
      name: 'customer-home',
      builder: (_, _) => const Scaffold(body: Text('Home')),
    ),
  ],
);

Future<void> fillCard(WidgetTester tester) async {
  final expiry =
      '12/${((DateTime.now().year + 2) % 100).toString().padLeft(2, '0')}';
  await tester.enterText(find.byType(TextFormField).at(0), '4242424242424242');
  await tester.enterText(find.byType(TextFormField).at(1), 'Test User');
  await tester.enterText(find.byType(TextFormField).at(2), expiry);
  await tester.enterText(find.byType(TextFormField).at(3), '123');
}

void main() {
  testWidgets(
    'validated demo pay saves once, clears purchased items, and opens confirmation',
    (tester) async {
      final orders = RecordingOrders(gate: Completer<void>());
      final cart = CartProvider()..add(product);
      final appRouter = router(draft(), orders);
      addTearDown(appRouter.dispose);
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await fillCard(tester);
      await tester.tap(find.text('Pay LKR 1,060.00'));
      await tester.pump();
      expect(orders.calls, 1);
      expect(cart.count, 1);
      expect(find.text('Processing...'), findsOneWidget);
      orders.gate!.complete();
      await tester.pumpAndSettle();
      expect(orders.calls, 1);
      expect(cart.count, 0);
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('#order-123'), findsOneWidget);
      expect(find.text('LKR 1,060.00'), findsOneWidget);
      expect(orders.saved['order-123']!.items.single.product.name, 'Apple');
      expect(orders.saved['order-123']!.pickupAt, DateTime(2026, 10, 4, 10));
      expect(orders.saved['order-123']!.replacementPreference, 'contactMe');
      expect(orders.saved['order-123']!.paymentMethod, 'card');
      expect(orders.saved['order-123']!.paymentStatus, 'demo');
      final stored = orders.saved['order-123']!.toFirestore();
      expect(stored.containsKey('cardNumber'), isFalse);
      expect(stored.containsKey('cvv'), isFalse);
      await tester.tap(find.byKey(const Key('paymentSuccessContent')));
      await tester.pumpAndSettle();
      expect(find.text('Saved order order-123'), findsOneWidget);
    },
  );

  testWidgets('failed order save keeps the cart and payment screen', (
    tester,
  ) async {
    final orders = RecordingOrders(fail: true);
    final cart = CartProvider()..add(product);
    final appRouter = router(draft(), orders);
    addTearDown(appRouter.dispose);
    addTearDown(cart.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await fillCard(tester);
    await tester.tap(find.text('Pay LKR 1,060.00'));
    await tester.pumpAndSettle();
    expect(cart.count, 1);
    expect(find.byType(CardPaymentScreen), findsOneWidget);
    expect(find.byType(PaymentResultScreen), findsNothing);
  });

  for (final entry in {
    'placed': 0,
    'accepted': 1,
    'preparing': 2,
    'ready': 3,
    'collected': 4,
  }.entries) {
    testWidgets('tracking highlights ${entry.key} from the order status', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(order: draft(status: entry.key)),
        ),
      );
      expect(find.text('Track Your Order'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(entry.value));
      expect(find.text('Order Placed'), findsWidgets);
      final activeLabel = switch (entry.key) {
        'placed' => 'Order Placed',
        'accepted' => 'Accepted',
        'preparing' => 'Preparing',
        'ready' => 'Ready for Pickup',
        _ => 'Collected',
      };
      final texts = tester.widgetList<Text>(find.text(activeLabel));
      expect(
        texts.any((text) => text.style?.color == AppColors.primary),
        isTrue,
      );
    });
  }
}
