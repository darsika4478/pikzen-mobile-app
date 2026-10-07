import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/payments_tracking/screens/card_payment_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_method_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_result_screen.dart';

void main() {
  group('Card payment flow', () {
    testWidgets('card option opens details and back returns to methods', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(CardPaymentScreen), findsOneWidget);
      expect(find.text('Pay LKR 2,450.00'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentMethodScreen), findsOneWidget);
    });

    testWidgets('any 16-digit dummy card passes format validation', (
      tester,
    ) async {
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _enterCard(tester, '4242 4242 4242 4243', expiry: '12/30');
      await tester.tap(find.text('Pay LKR 2,450.00'));
      await tester.pumpAndSettle();

      expect(find.byType(CardPaymentScreen), findsOneWidget);
      expect(find.text('Enter 16 digits'), findsNothing);
      expect(find.byType(PaymentResultScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a past MM/YY passes demo format validation', (tester) async {
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _enterCard(tester, '9876543210123456', expiry: '12/20');
      await tester.tap(find.text('Pay LKR 2,450.00'));
      await tester.pumpAndSettle();

      expect(find.text('Use MM/YY'), findsNothing);
      expect(find.byType(PaymentResultScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fewer than 16 digits are rejected', (tester) async {
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _enterCard(tester, '111122223333444');
      await tester.tap(find.text('Pay LKR 2,450.00'));
      await tester.pumpAndSettle();

      expect(find.text('Enter 16 digits'), findsOneWidget);
      expect(find.byType(PaymentResultScreen), findsNothing);
    });

    testWidgets('holder name, MM/YY, and 3-digit CVV are required', (
      tester,
    ) async {
      final router = _router(initialLocation: '/card-payment');
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.tap(find.text('Pay LKR 2,450.00'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the cardholder name'), findsOneWidget);
      expect(find.text('Use MM/YY'), findsOneWidget);
      expect(find.text('Enter the 3-digit CVV'), findsOneWidget);
      expect(find.byType(PaymentResultScreen), findsNothing);
    });

    testWidgets('invalid expiry month and short CVV are rejected', (
      tester,
    ) async {
      final router = _router(initialLocation: '/card-payment');
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await _enterCard(tester, '1111222233334444', expiry: '13/30', cvv: '12');
      await tester.tap(find.text('Pay LKR 2,450.00'));
      await tester.pumpAndSettle();

      expect(find.text('Use MM/YY'), findsOneWidget);
      expect(find.text('Enter the 3-digit CVV'), findsOneWidget);
      expect(find.byType(PaymentResultScreen), findsNothing);
    });
  });
}

Future<void> _enterCard(
  WidgetTester tester,
  String number, {
  String holder = 'Test User',
  String expiry = '12/30',
  String cvv = '123',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), number);
  await tester.enterText(find.byType(TextFormField).at(1), holder);
  await tester.enterText(find.byType(TextFormField).at(2), expiry);
  await tester.enterText(find.byType(TextFormField).at(3), cvv);
}

Widget _app(GoRouter router) =>
    MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router);

GoRouter _router({String initialLocation = '/payment-method'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/payment-method',
      name: 'payment-method',
      builder: (context, state) => const PaymentMethodScreen(
        amountMinor: 245000,
        orderId: 'PZ-DEMO-101',
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
          amountMinor: amount is int ? amount : 245000,
          currencyCode: currency is String ? currency : 'LKR',
          orderId: orderId is String ? orderId : null,
        );
      },
    ),
    GoRoute(
      path: '/payment-result',
      name: 'payment-result',
      builder: (context, state) {
        final extra = state.extra;
        final orderId = extra is Map ? extra['orderId'] : null;
        final amount = extra is Map ? extra['amountMinor'] : null;
        final currency = extra is Map ? extra['currencyCode'] : null;
        final isDemo = extra is Map ? extra['isDemo'] : null;
        return PaymentResultScreen(
          orderId: orderId is String ? orderId : null,
          amountMinor: amount is int ? amount : null,
          currencyCode: currency is String ? currency : 'LKR',
          isDemo: isDemo is bool ? isDemo : true,
        );
      },
    ),
    GoRoute(
      path: '/customer-home',
      name: 'customer-home',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Customer Home'))),
    ),
  ],
);
