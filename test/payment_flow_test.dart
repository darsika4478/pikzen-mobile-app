import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/services/payment_service.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/cart_checkout/screens/order_confirmation_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/card_payment_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_selection_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_failure_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_method_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_result_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/payment_model.dart';
import 'package:pikzen/models/product_model.dart';

const _checkout = PaymentCheckoutData(
  amountMinor: 987650,
  currencyCode: 'LKR',
  orderId: 'PZ-DEMO-1',
);

void main() {
  for (final method in PaymentMethod.values) {
    testWidgets('${method.identifier} uses the shared amount and demo result', (
      tester,
    ) async {
      final orders = _RecordingOrderService();
      Map<String, Object?>? result;
      final router = _router(
        checkout: _checkout,
        payments: DemoPaymentService(orders: orders),
        onResult: (extra) => result = extra,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await _open(tester, method);
      await _submit(tester, method);

      expect(find.byType(PaymentResultScreen), findsOneWidget);
      expect(find.text('LKR 9,876.50'), findsOneWidget);
      expect(find.text('PZ-DEMO-1'), findsOneWidget);
      expect(find.text(method.label), findsOneWidget);
      expect(result!['paymentMethod'], method.identifier);
      expect(result!['paymentStatus'], method.paymentStatus);
      expect(result!['isDemo'], isTrue);
      expect(result!['order'], isNull);
      expect(
        orders.calls,
        isEmpty,
      ); // Without a draft, the demo creates nothing.
      expect(find.byType(TextFormField), findsNothing);
      if (method == PaymentMethod.cashOnPickup) {
        expect(find.text('Payment due at pickup'), findsOneWidget);
        expect(find.text('Payment Successful!'), findsNothing);
        expect(find.text('Demo payment complete'), findsNothing);
      } else {
        expect(find.text('Demo payment complete'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('View My Orders'));
      await tester.tap(find.text('View My Orders'));
      await tester.pumpAndSettle();
      expect(find.text('My Orders destination'), findsOneWidget);
      expect(orders.calls, isEmpty);
    });

    testWidgets(
      '${method.identifier} confirms the same draft with safe metadata',
      (tester) async {
        final draft = _draft();
        final orders = _RecordingOrderService();
        final checkout = PaymentCheckoutData(
          amountMinor: 1,
          currencyCode: 'USD',
          orderId: 'stale-id',
          orderDraft: draft,
        );
        Map<String, Object?>? result;
        final router = _router(
          checkout: checkout,
          payments: DemoPaymentService(orders: orders),
          onResult: (extra) => result = extra,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router));
        await _open(tester, method);
        expect(
          orders.calls,
          isEmpty,
        ); // Opening a payment screen has no writes.
        await _submit(tester, method, amount: 'LKR 1,234.56');

        expect(orders.calls, hasLength(1));
        expect(identical(orders.calls.single.draft, draft), isTrue);
        expect(orders.calls.single.method, method.identifier);
        expect(orders.calls.single.status, method.paymentStatus);
        expect(find.text(draft.id), findsOneWidget);
        expect(find.text('LKR 1,234.56'), findsOneWidget);
        expect(find.text('USD 0.01'), findsNothing);
        expect(result!['order'], same(orders.saved[draft.id]));
        expect(
          result!.keys,
          unorderedEquals([
            'order',
            'orderId',
            'amountMinor',
            'currencyCode',
            'paymentMethod',
            'paymentStatus',
            'isDemo',
          ]),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${method.identifier} back retains checkout and selection', (
      tester,
    ) async {
      final router = _router(checkout: _checkout);
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await _open(tester, method);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentMethodScreen), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      _expectEntry(tester, method);
      if (method == PaymentMethod.card) {
        expect(find.text('Pay LKR 9,876.50'), findsOneWidget);
      } else {
        expect(find.text('LKR 9,876.50'), findsOneWidget);
      }
    });

    testWidgets(
      '${method.identifier} direct Android back restores safe state',
      (tester) async {
        final router = _router(
          checkout: _checkout,
          method: method,
          initialLocation: '/${method.routeName}',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final selection = tester.widget<PaymentMethodScreen>(
          find.byType(PaymentMethodScreen),
        );
        expect(selection.selectedMethod, method.identifier);
        expect(selection.amountMinor, _checkout.totalMinor);
        expect(selection.currencyCode, _checkout.currency);
        expect(selection.orderId, _checkout.id);
      },
    );

    testWidgets('${method.identifier} failure retry opens the correct entry', (
      tester,
    ) async {
      final router = _router(
        checkout: _checkout,
        method: method,
        initialLocation: '/payment-failure',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      _expectEntry(tester, method);
      if (method == PaymentMethod.card) {
        expect(find.text('Pay LKR 9,876.50'), findsOneWidget);
      } else {
        expect(find.text('LKR 9,876.50'), findsOneWidget);
      }
    });

    testWidgets(
      '${method.identifier} choose another method retains the draft',
      (tester) async {
        final draft = _draft();
        final router = _router(
          checkout: PaymentCheckoutData(orderDraft: draft),
          method: method,
          initialLocation: '/payment-failure',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router));
        await tester.tap(find.text('Choose Another Method'));
        await tester.pumpAndSettle();
        final selection = tester.widget<PaymentMethodScreen>(
          find.byType(PaymentMethodScreen),
        );
        expect(selection.selectedMethod, method.identifier);
        expect(selection.orderDraft, same(draft));
        expect(selection.amountMinor, draft.effectiveTotalMinor);
      },
    );
  }

  for (final method in [PaymentMethod.ewallet, PaymentMethod.onlineBanking]) {
    testWidgets(
      '${method.identifier} supports every sample and selects only one',
      (tester) async {
        final router = _router(
          checkout: _checkout,
          method: method,
          initialLocation: '/${method.routeName}',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_app(router));
        final button = method == PaymentMethod.ewallet
            ? 'Pay with e-Wallet'
            : 'Continue Payment';
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, button),
              )
              .onPressed,
          isNull,
        );
        expect(find.byType(TextField), findsNothing);
        final options = method == PaymentMethod.ewallet
            ? ['FriMi', 'Dialog Pay', 'eZ Cash', 'mCash']
            : [
                'Bank of Ceylon',
                "People's Bank",
                'Commercial Bank',
                'Sampath Bank',
                'HNB',
                'NDB',
              ];
        for (final option in options) {
          await tester.ensureVisible(find.byKey(ValueKey(option)));
          await tester.tap(find.byKey(ValueKey(option)));
          await tester.pump();
          for (final candidate in options) {
            expect(
              tester
                  .widget<Semantics>(find.byKey(ValueKey(candidate)))
                  .properties
                  .selected,
              candidate == option,
            );
          }
        }
        expect(find.text('LKR 9,876.50'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, button),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets(
    'cash confirmation blocks repeat taps and creates no order on success rebuild',
    (tester) async {
      final gate = Completer<void>();
      final orders = _RecordingOrderService(gate: gate);
      final router = _router(
        checkout: PaymentCheckoutData(orderDraft: _draft()),
        payments: DemoPaymentService(orders: orders),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await _open(tester, PaymentMethod.cashOnPickup);
      expect(orders.calls, isEmpty);
      await tester.tap(find.text('Confirm Order'));
      await tester.tap(find.text('Confirm Order'));
      await tester.pump();
      expect(orders.calls, hasLength(1));
      expect(find.text('Confirming...'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(orders.saved, hasLength(1));
      final result = tester.widget<PaymentResultScreen>(
        find.byType(PaymentResultScreen),
      );
      expect(result.order!.paymentStatus, 'unpaid');
      await tester.pump();
      expect(orders.calls, hasLength(1));
    },
  );

  testWidgets('failed order persistence retries using the original draft ID', (
    tester,
  ) async {
    final orders = _RecordingOrderService(failOnce: true);
    final router = _router(
      checkout: PaymentCheckoutData(orderDraft: _draft()),
      payments: DemoPaymentService(orders: orders),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await _open(tester, PaymentMethod.cashOnPickup);
    await tester.tap(find.text('Confirm Order'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderConfirmationScreen), findsOneWidget);
    expect(
      find.text('The order could not be saved. Please try again.'),
      findsOneWidget,
    );
    // The snackbar temporarily covers the bottom confirmation button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Order'));
    await tester.pumpAndSettle();
    expect(orders.calls.map((call) => call.draft.id), [
      'PZ-DRAFT-1',
      'PZ-DRAFT-1',
    ]);
    expect(orders.saved, hasLength(1));
    expect(find.byType(PaymentResultScreen), findsOneWidget);
  });

  testWidgets('leaving card entry discards sensitive form input', (
    tester,
  ) async {
    final router = _router(checkout: _checkout);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await _open(tester, PaymentMethod.card);
    await _fillCard(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.controller!.text, isEmpty);
    }
  });

  testWidgets(
    'missing checkout values never become an invented total or order',
    (tester) async {
      final router = _router(
        method: PaymentMethod.cashOnPickup,
        initialLocation: '/order-confirmation',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      expect(find.text('Not available from checkout'), findsOneWidget);
      await tester.tap(find.text('Confirm Order'));
      await tester.pumpAndSettle();
      expect(find.text('Demo order confirmed'), findsOneWidget);
      expect(
        tester
            .widget<PaymentResultScreen>(find.byType(PaymentResultScreen))
            .order,
        isNull,
      );
    },
  );

  for (final route in [
    '/payment-method',
    ...PaymentMethod.values.map((method) => '/${method.routeName}'),
    '/payment-result',
    '/payment-failure',
  ]) {
    testWidgets('$route fits a small screen with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = _router(checkout: _checkout, initialLocation: route);
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'application routes connect the wallet, bank and cash demo flows',
    (tester) async {
      appRouter.goNamed(
        'payment-method',
        extra: _checkout.toExtra(PaymentMethod.card),
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: appRouter),
      );
      for (final method in [
        PaymentMethod.ewallet,
        PaymentMethod.onlineBanking,
        PaymentMethod.cashOnPickup,
      ]) {
        appRouter.goNamed('payment-method', extra: _checkout.toExtra(method));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        _expectEntry(tester, method);
        await _submit(tester, method);
        expect(find.byType(PaymentResultScreen), findsOneWidget);
        expect(find.text('LKR 9,876.50'), findsOneWidget);
        expect(
          tester
              .widget<PaymentResultScreen>(find.byType(PaymentResultScreen))
              .paymentMethod,
          method.identifier,
        );
      }
    },
  );
}

Future<void> _open(WidgetTester tester, PaymentMethod method) async {
  await tester.ensureVisible(find.text(method.label));
  await tester.tap(find.text(method.label));
  await tester.pump();
  expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> _fillCard(WidgetTester tester) async {
  for (final entry in [
    '1111222233334444',
    'Test User',
    '1230',
    '123',
  ].asMap().entries) {
    await tester.enterText(
      find.byType(TextFormField).at(entry.key),
      entry.value,
    );
  }
}

Future<void> _submit(
  WidgetTester tester,
  PaymentMethod method, {
  String amount = 'LKR 9,876.50',
}) async {
  switch (method) {
    case PaymentMethod.card:
      await _fillCard(tester);
      await tester.tap(find.text('Pay $amount'));
    case PaymentMethod.ewallet:
      await tester.tap(find.byKey(const ValueKey('FriMi')));
      await tester.pump();
      await tester.tap(find.text('Pay with e-Wallet'));
    case PaymentMethod.onlineBanking:
      await tester.tap(find.byKey(const ValueKey('Bank of Ceylon')));
      await tester.pump();
      await tester.tap(find.text('Continue Payment'));
    case PaymentMethod.cashOnPickup:
      await tester.tap(find.text('Confirm Order'));
  }
  await tester.pumpAndSettle();
}

void _expectEntry(WidgetTester tester, PaymentMethod method) {
  switch (method) {
    case PaymentMethod.card:
      expect(find.byType(CardPaymentScreen), findsOneWidget);
    case PaymentMethod.cashOnPickup:
      expect(find.byType(OrderConfirmationScreen), findsOneWidget);
    case PaymentMethod.ewallet || PaymentMethod.onlineBanking:
      expect(find.byType(DemoPaymentSelectionScreen), findsOneWidget);
      expect(
        tester
            .widget<DemoPaymentSelectionScreen>(
              find.byType(DemoPaymentSelectionScreen),
            )
            .method,
        method,
      );
  }
}

Widget _app(GoRouter router, {double textScale = 1}) => MaterialApp.router(
  theme: AppTheme.lightTheme,
  routerConfig: router,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
);

GoRouter _router({
  PaymentCheckoutData checkout = const PaymentCheckoutData(),
  PaymentMethod method = PaymentMethod.card,
  String initialLocation = '/payment-method',
  DemoPaymentService? payments,
  void Function(Map<String, Object?>)? onResult,
}) {
  PaymentCheckoutData data(GoRouterState state) => state.extra == null
      ? checkout
      : PaymentCheckoutData.fromExtra(state.extra);
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/payment-method',
        name: 'payment-method',
        builder: (context, state) {
          final args = state.extra is Map ? state.extra as Map : const {};
          final selected = args['selectedMethod'];
          final value = data(state);
          return PaymentMethodScreen(
            amountMinor: value.totalMinor,
            currencyCode: value.currency,
            orderId: value.id,
            orderDraft: value.orderDraft,
            selectedMethod: selected is String ? selected : method.identifier,
          );
        },
      ),
      GoRoute(
        path: '/card-payment',
        name: 'card-payment',
        builder: (context, state) {
          final value = data(state);
          return CardPaymentScreen(
            amountMinor: value.totalMinor,
            currencyCode: value.currency,
            orderId: value.id,
            orderDraft: value.orderDraft,
            demoPayments: payments,
          );
        },
      ),
      for (final selected in [
        PaymentMethod.ewallet,
        PaymentMethod.onlineBanking,
      ])
        GoRoute(
          path: '/${selected.routeName}',
          name: selected.routeName,
          builder: (context, state) => DemoPaymentSelectionScreen(
            method: selected,
            checkout: data(state),
            demoPayments: payments,
          ),
        ),
      GoRoute(
        path: '/order-confirmation',
        name: 'order-confirmation',
        builder: (context, state) {
          final value = data(state);
          return OrderConfirmationScreen(
            amountMinor: value.totalMinor,
            currencyCode: value.currency,
            orderId: value.id,
            orderDraft: value.orderDraft,
            demoPayments: payments,
          );
        },
      ),
      GoRoute(
        path: '/payment-result',
        name: 'payment-result',
        builder: (context, state) {
          final args = state.extra is Map
              ? Map<String, Object?>.from(state.extra as Map)
              : checkout.successExtra(method, null);
          onResult?.call(args);
          return PaymentResultScreen(
            order: args['order'] as OrderModel?,
            orderId: args['orderId'] as String?,
            amountMinor: args['amountMinor'] as int?,
            currencyCode: args['currencyCode'] as String? ?? 'LKR',
            paymentMethod: args['paymentMethod'] as String? ?? 'card',
            paymentStatus: args['paymentStatus'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/payment-failure',
        name: 'payment-failure',
        builder: (context, state) {
          final value = data(state);
          return PaymentFailureScreen(
            paymentMethod: method.identifier,
            amountMinor: value.totalMinor,
            currencyCode: value.currency,
            orderId: value.id,
            orderDraft: value.orderDraft,
          );
        },
      ),
      for (final destination in ['my-orders', 'customer-home', 'checkout'])
        GoRoute(
          path: '/$destination',
          name: destination,
          builder: (context, state) => Scaffold(
            body: Text(
              destination == 'my-orders'
                  ? 'My Orders destination'
                  : destination,
            ),
          ),
        ),
    ],
  );
}

OrderModel _draft() => OrderModel(
  id: 'PZ-DRAFT-1',
  userId: 'customer-1',
  createdAt: DateTime.utc(2026, 10, 1),
  totalMinor: 123456,
  currencyCode: 'LKR',
  items: const [
    CartItemModel(
      product: ProductModel(
        id: 'product-1',
        name: 'Groceries',
        priceMinor: 123456,
        currencyCode: 'LKR',
      ),
      quantity: 1,
    ),
  ],
);

class _OrderCall {
  const _OrderCall(this.draft, this.method, this.status);
  final OrderModel draft;
  final String method;
  final String status;
}

class _RecordingOrderService extends OrderService {
  _RecordingOrderService({this.gate, this.failOnce = false});
  final Completer<void>? gate;
  bool failOnce;
  final calls = <_OrderCall>[];
  final saved = <String, OrderModel>{};

  @override
  Future<OrderModel> createOrderOnce(
    OrderModel draft, {
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    calls.add(_OrderCall(draft, paymentMethod, paymentStatus));
    if (failOnce) {
      failOnce = false;
      throw const OrderActionException('Test order persistence failure.');
    }
    if (gate != null) await gate!.future;
    return saved.putIfAbsent(
      draft.id,
      () => draft.copyWith(
        status: 'placed',
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
      ),
    );
  }
}
