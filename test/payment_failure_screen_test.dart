import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/card_payment_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_failure_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_method_screen.dart';

void main() {
  group('Payment failure flow', () {
    testWidgets('shows friendly failure state and retry reopens card form', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      expect(find.text('Payment Failed'), findsOneWidget);
      expect(find.text("We couldn't process your payment."), findsOneWidget);
      expect(
        find.text('Please try again or choose another method.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.byType(CardPaymentScreen), findsOneWidget);
      expect(find.text('Pay LKR 2,450.00'), findsOneWidget);
      expect(find.text('4242 4242 4242 4242'), findsNothing);
    });

    testWidgets('hides raw Firebase error codes', (tester) async {
      final router = _router(message: 'NOT_FOUND');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      expect(find.text('NOT_FOUND'), findsNothing);
      expect(
        find.text('Unable to place your order. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'another method returns to selection preserving checkout data',
      (tester) async {
        final router = _router(paymentMethod: 'eWallet');
        addTearDown(router.dispose);

        await tester.pumpWidget(_app(router));
        await tester.tap(find.text('Choose Another Method'));
        await tester.pumpAndSettle();

        expect(find.byType(PaymentMethodScreen), findsOneWidget);
        expect(find.text('e-Wallet'), findsOneWidget);
        expect(find.text('Pay LKR 2,450.00'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Android back returns to the card payment step', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(CardPaymentScreen), findsOneWidget);
      expect(find.text('Pay LKR 2,450.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _app(GoRouter router) =>
    MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router);

GoRouter _router({String paymentMethod = 'card', String? message}) => GoRouter(
  initialLocation: '/payment-failure',
  routes: [
    GoRoute(
      path: '/payment-failure',
      name: 'payment-failure',
      builder: (context, state) => PaymentFailureScreen(
        paymentMethod: paymentMethod,
        amountMinor: 245000,
        currencyCode: 'LKR',
        orderId: 'PZ-ORDER-1',
        message: message,
      ),
    ),
    GoRoute(
      path: '/card-payment',
      name: 'card-payment',
      builder: (context, state) {
        final extra = state.extra;
        final amount = extra is Map ? extra['amountMinor'] : null;
        final currency = extra is Map ? extra['currencyCode'] : null;
        final orderId = extra is Map ? extra['orderId'] : null;
        return CardPaymentScreen(
          amountMinor: amount is int ? amount : null,
          currencyCode: currency is String ? currency : 'LKR',
          orderId: orderId is String ? orderId : null,
        );
      },
    ),
    GoRoute(
      path: '/payment-method',
      name: 'payment-method',
      builder: (context, state) {
        final extra = state.extra;
        final amount = extra is Map ? extra['amountMinor'] : null;
        final currency = extra is Map ? extra['currencyCode'] : null;
        final orderId = extra is Map ? extra['orderId'] : null;
        final method = extra is Map ? extra['selectedMethod'] : null;
        return PaymentMethodScreen(
          amountMinor: amount is int ? amount : null,
          currencyCode: currency is String ? currency : 'LKR',
          orderId: orderId is String ? orderId : null,
          selectedMethod: method is String ? method : 'card',
        );
      },
    ),
    GoRoute(
      path: '/order-confirmation',
      name: 'order-confirmation',
      builder: (context, state) => const Scaffold(),
    ),
  ],
);
