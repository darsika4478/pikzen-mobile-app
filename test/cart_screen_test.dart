import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/cart_checkout/screens/cart_screen.dart';
import 'package:pikzen/models/product_model.dart';

void main() {
  testWidgets(
    'Cart shows live products, correct totals, stock limit and removal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cart = CartProvider();
      addTearDown(cart.dispose);
      const apple = ProductModel(
        id: 'apple',
        name: 'Royal Gala Red Apples',
        priceMinor: 16000,
        currencyCode: 'LKR',
        unit: '1 kg',
        stockQuantity: 2,
        imageUrl: 'assets/images/Apples Product.png',
      );
      const bakery = ProductModel(
        id: 'bakery',
        name: 'Fresh Bakery Bread',
        category: 'Bakery',
        priceMinor: 25000,
        currencyCode: 'LKR',
        stockQuantity: 3,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: const MaterialApp(home: CartScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your cart is empty'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Proceed to Checkout'), 100);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Proceed to Checkout'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );

      cart.add(apple);
      cart.add(apple);
      cart.add(bakery);
      await tester.pumpAndSettle();
      expect(find.text('2 Items'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Order Summary'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Rs. 570.00'), findsWidgets);
      expect(find.text('Rs. 0.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byTooltip('Increase Royal Gala Red Apples'),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Increase Royal Gala Red Apples'));
      await tester.pump();
      expect(cart.quantity('apple'), 2);
      expect(find.text('Only 2 items available in stock.'), findsOneWidget);

      await tester.tap(find.byTooltip('Decrease Royal Gala Red Apples'));
      await tester.pumpAndSettle();
      expect(cart.quantity('apple'), 1);
      expect(cart.totalMinor, 41000);

      await tester.ensureVisible(
        find.byTooltip('Remove Royal Gala Red Apples'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove Royal Gala Red Apples'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(cart.quantity('apple'), 0);
      await tester.scrollUntilVisible(
        find.text('Review Your Basket'),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('1 Item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
