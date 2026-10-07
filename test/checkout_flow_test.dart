import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/checkout_provider.dart';
import 'package:pikzen/features/cart_checkout/screens/checkout_screen.dart';
import 'package:pikzen/features/cart_checkout/screens/pickup_date_screen.dart';
import 'package:pikzen/features/cart_checkout/screens/pickup_time_screen.dart';
import 'package:pikzen/features/cart_checkout/screens/replacement_preference_screen.dart';
import 'package:pikzen/models/product_model.dart';
import 'package:pikzen/models/user_model.dart';

void main() {
  testWidgets(
    'checkout choices navigate and return with shared state on a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cart = CartProvider();
      final checkout = CheckoutProvider();
      final auth = AuthProvider(restore: false)
        ..user = const UserModel(
          id: 'customer',
          name: 'Customer',
          email: 'customer@example.com',
          role: 'customer',
        );
      addTearDown(cart.dispose);
      addTearDown(checkout.dispose);
      addTearDown(auth.dispose);
      expect(
        cart.add(
          const ProductModel(
            id: 'apple',
            name: 'Apple',
            priceMinor: 106000,
            currencyCode: 'LKR',
          ),
        ),
        isTrue,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: cart),
            ChangeNotifierProvider.value(value: checkout),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: appRouter,
          ),
        ),
      );
      appRouter.goNamed('checkout');
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(cart.totalMinor, 106000);
      await tester.scrollUntilVisible(
        find.text('Total'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rs. 1,060.00'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(PickupDateScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Quick Selection'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(ChoiceChip).first);
      await tester.drag(find.byType(ListView).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      expect(checkout.pickupDate, isNotNull);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(PickupTimeScreen), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      expect(checkout.pickupTime, isNotNull);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(ReplacementPreferenceScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Contact me'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -70));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contact me'));
      expect(checkout.preference, ReplacementPreference.contactMe);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PickupTimeScreen), findsOneWidget);
      expect(checkout.pickupTime, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
