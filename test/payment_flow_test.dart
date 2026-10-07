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
import 'package:pikzen/features/payments_tracking/screens/payment_failure_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_selection_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_result_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/payment_model.dart';
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
  DemoPaymentDetails? lastDetails;
  final saved = <String, OrderModel>{};

  @override
  Future<OrderModel> createOrderOnce(
    OrderModel value, {
    required String paymentMethod,
    required String paymentStatus,
    DemoPaymentDetails paymentDetails = const DemoPaymentDetails(),
  }) async {
    calls++;
    lastDetails = paymentDetails;
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

GoRouter router(
  OrderModel order,
  RecordingOrders orders, {
  String initialLocation = '/card-payment',
}) => GoRouter(
  initialLocation: initialLocation,
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
      path: '/ewallet-payment',
      name: 'ewallet-payment',
      builder: (_, _) => DemoPaymentSelectionScreen(
        method: PaymentMethod.ewallet,
        checkout: PaymentCheckoutData(orderDraft: order),
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
      path: '/payment-failure',
      name: 'payment-failure',
      builder: (_, state) {
        final checkout = PaymentCheckoutData.fromExtra(state.extra);
        final args = state.extra as Map<String, Object?>;
        return PaymentFailureScreen(
          paymentMethod: args['paymentMethod'] as String? ?? 'card',
          orderDraft: checkout.orderDraft,
          message: args['errorMessage'] as String?,
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

Future<void> fillCard(
  WidgetTester tester, {
  String number = '4242424242424242',
  String? expiry,
}) async {
  expiry ??=
      '12/${((DateTime.now().year + 2) % 100).toString().padLeft(2, '0')}';
  await tester.enterText(find.byType(TextFormField).at(0), number);
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
      expect(find.text('Demo Payment Complete'), findsOneWidget);
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
      expect(orders.lastDetails?.cardLast4, '4242');
      expect(orders.lastDetails?.provider, 'Demo card');
      await tester.tap(find.byKey(const Key('paymentSuccessContent')));
      await tester.pumpAndSettle();
      expect(find.text('Saved order order-123'), findsOneWidget);
    },
  );

  testWidgets('failed order save keeps the cart and opens failure screen', (
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
    expect(find.byType(PaymentFailureScreen), findsOneWidget);
    expect(find.text('Save failed'), findsOneWidget);
    expect(find.byType(PaymentResultScreen), findsNothing);
  });

  testWidgets('declined demo test card never saves an order', (tester) async {
    final orders = RecordingOrders();
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
    await fillCard(tester, number: DemoCards.declined);
    await tester.tap(find.text('Pay LKR 1,060.00'));
    await tester.pumpAndSettle();
    expect(orders.calls, 0);
    expect(cart.count, 1);
    expect(find.byType(PaymentFailureScreen), findsOneWidget);
    expect(find.textContaining('declined'), findsOneWidget);
  });

  testWidgets('expired dummy card is rejected by the form', (tester) async {
    final orders = RecordingOrders();
    final appRouter = router(draft(), orders);
    addTearDown(appRouter.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await fillCard(tester, expiry: '01/20');
    await tester.tap(find.text('Pay LKR 1,060.00'));
    await tester.pumpAndSettle();
    expect(orders.calls, 0);
    expect(find.text('This card has expired'), findsOneWidget);
  });

  test('demo card helpers expose only last four digits and expiry', () {
    expect(DemoCards.last4('4242 4242 4242 1234'), '1234');
    expect(DemoCards.declineReason(DemoCards.approved), isNull);
    expect(DemoCards.declineReason(DemoCards.insufficientFunds), isNotNull);
    final now = DateTime(2026, 10, 7);
    expect(DemoCards.isExpired('09/26', now: now), isTrue);
    expect(DemoCards.isExpired('10/26', now: now), isFalse);
  });

  test('receipt reference is stable for an order ID', () {
    expect(PaymentModel.referenceFor('aB3dE6gH9jK'), 'DEMO-AB3DE6GH');
    expect(PaymentModel.referenceFor('order-123'), 'DEMO-ORDER123');
  });

  testWidgets('wallet order clears cart only after successful save', (
    tester,
  ) async {
    final orders = RecordingOrders(gate: Completer<void>());
    final cart = CartProvider()..add(product);
    final appRouter = router(
      draft(),
      orders,
      initialLocation: '/ewallet-payment',
    );
    addTearDown(appRouter.dispose);
    addTearDown(cart.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.tap(find.text('FriMi'));
    await tester.pump();
    await tester.tap(find.text('Pay with e-Wallet'));
    await tester.pump();
    expect(orders.calls, 1);
    expect(cart.count, 1);
    orders.gate!.complete();
    await tester.pumpAndSettle();
    expect(cart.count, 0);
    expect(find.text('Demo Payment Complete'), findsOneWidget);
    expect(orders.saved['order-123']!.paymentMethod, 'ewallet');
  });

  testWidgets('wallet save failure keeps purchased items in cart', (
    tester,
  ) async {
    final orders = RecordingOrders(fail: true);
    final cart = CartProvider()..add(product);
    final appRouter = router(
      draft(),
      orders,
      initialLocation: '/ewallet-payment',
    );
    addTearDown(appRouter.dispose);
    addTearDown(cart.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.tap(find.text('FriMi'));
    await tester.pump();
    await tester.tap(find.text('Pay with e-Wallet'));
    await tester.pumpAndSettle();
    expect(cart.count, 1);
    expect(find.byType(PaymentFailureScreen), findsOneWidget);
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
