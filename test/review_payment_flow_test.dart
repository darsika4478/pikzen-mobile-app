import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/checkout_provider.dart';
import 'package:pikzen/features/cart_checkout/screens/review_order_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/card_payment_screen.dart';
import 'package:pikzen/features/payments_tracking/screens/payment_method_screen.dart';
import 'package:pikzen/models/payment_model.dart';
import 'package:pikzen/models/product_model.dart';
import 'package:pikzen/models/user_model.dart';

void main() {
  testWidgets('review reads cart and checkout and payment selection returns', (
    tester,
  ) async {
    final cart = CartProvider();
    final checkout = CheckoutProvider();
    final auth = AuthProvider(restore: false)
      ..user = const UserModel(
        id: 'customer',
        name: 'Test',
        email: 'test@example.com',
      );
    addTearDown(cart.dispose);
    addTearDown(checkout.dispose);
    addTearDown(auth.dispose);
    cart.add(
      const ProductModel(
        id: 'a',
        name: 'Fresh Apple',
        priceMinor: 53000,
        currencyCode: 'LKR',
        stockQuantity: 10,
        unit: 'each',
      ),
    );
    cart.add(
      const ProductModel(
        id: 'a',
        name: 'Fresh Apple',
        priceMinor: 53000,
        currencyCode: 'LKR',
        stockQuantity: 10,
        unit: 'each',
      ),
    );
    final day = DateTime.now().add(const Duration(days: 2));
    checkout.setPickupDate(day);
    checkout.setPickupTime(DateTime(day.year, day.month, day.day, 10));
    checkout.setPreference(ReplacementPreference.contactMe);
    final router = GoRouter(
      initialLocation: '/review-order',
      routes: [
        GoRoute(
          path: '/review-order',
          name: 'review-order',
          builder: (_, _) => const ReviewOrderScreen(),
        ),
        GoRoute(
          path: '/payment-method',
          name: 'payment-method',
          builder: (_, _) => const PaymentMethodScreen(),
        ),
        GoRoute(
          path: '/pickup-date',
          name: 'pickup-date',
          builder: (_, _) => const Scaffold(body: Text('Pickup Date')),
        ),
        GoRoute(
          path: '/replacement-preference',
          name: 'replacement-preference',
          builder: (_, _) => const Scaffold(body: Text('Replacement Editor')),
        ),
        GoRoute(
          path: '/cart',
          name: 'cart',
          builder: (_, _) => const Scaffold(body: Text('Existing Cart')),
        ),
        GoRoute(
          path: '/card-payment',
          name: 'card-payment',
          builder: (_, state) {
            final data = PaymentCheckoutData.fromExtra(state.extra);
            return CardPaymentScreen(amountMinor: data.totalMinor);
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: checkout),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    expect(find.text('Fresh Apple'), findsOneWidget);
    expect(find.text('Item Breakdown (2 items)'), findsOneWidget);
    expect(find.text('Contact me'), findsOneWidget);
    expect(find.text('Rs. 1,060.00'), findsWidgets);
    expect(find.textContaining('10:00 AM'), findsOneWidget);
    await tester.tap(find.text('Change').first);
    await tester.pumpAndSettle();
    expect(find.text('Pickup Date'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Replacement Editor'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View All'));
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.text('Existing Cart'), findsOneWidget);
    router.goNamed('review-order');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Payment Method'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Payment Method'));
    await tester.tap(find.text('Payment Method'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentMethodScreen), findsOneWidget);
    await tester.tap(find.text('Cash on Pickup'));
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(checkout.paymentMethod, PaymentMethod.cashOnPickup);
    expect(find.byType(ReviewOrderScreen), findsOneWidget);
    expect(find.text('Cash on Pickup'), findsOneWidget);
    expect(find.text('Total Due'), findsOneWidget);
    await tester.ensureVisible(find.text('Cash on Pickup'));
    await tester.tap(find.text('Cash on Pickup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit / Debit Card'));
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm & Place Order'));
    await tester.tap(find.text('Confirm & Place Order'));
    await tester.pumpAndSettle();
    expect(find.byType(CardPaymentScreen), findsOneWidget);
    expect(find.text('Pay LKR 1,060.00'), findsOneWidget);
    expect(checkout.reviewedAt, isNotNull);
  });

  testWidgets('card form validates and requires an order draft', (
    tester,
  ) async {
    final checkout = CheckoutProvider();
    addTearDown(checkout.dispose);
    final router = GoRouter(
      initialLocation: '/card-payment',
      routes: [
        GoRoute(
          path: '/card-payment',
          name: 'card-payment',
          builder: (_, _) => const CardPaymentScreen(amountMinor: 106000),
        ),
        GoRoute(
          path: '/review-order',
          name: 'review-order',
          builder: (_, _) => const Scaffold(body: Text('Review')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: checkout,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    expect(find.text('Pay LKR 1,060.00'), findsOneWidget);
    await tester.tap(find.text('Pay LKR 1,060.00'));
    await tester.pump();
    expect(find.text('Enter 16 digits'), findsOneWidget);
    expect(checkout.paymentAttemptCount, 0);
    final expiry =
        '12/${((DateTime.now().year + 2) % 100).toString().padLeft(2, '0')}';
    await tester.enterText(
      find.byType(TextFormField).at(0),
      '4242424242424242',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(2), expiry);
    await tester.enterText(find.byType(TextFormField).at(3), '123');
    await tester.tap(find.text('Pay LKR 1,060.00'));
    await tester.pump();
    expect(checkout.paymentAttemptStatus, isNull);
    expect(checkout.paymentAttemptCount, 0);
    expect(
      find.text(
        'Checkout details are unavailable. Please review your order again.',
      ),
      findsOneWidget,
    );
  });
}
