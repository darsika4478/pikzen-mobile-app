import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';

void main() {
  test(
    'Quantities, stock limits, removal and account isolation share one state',
    () {
      final cart = CartProvider();
      final products = ProductProvider();
      final apple = products.byId('red-apples')!;
      final milk = products.byId('whole-milk')!;
      cart.add(apple);
      cart.add(apple);
      cart.add(milk);
      expect(cart.count, 3);
      expect(cart.totalMinor, apple.priceMinor * 2 + milk.priceMinor);
      cart.decrease(apple.id);
      cart.decrease(apple.id);
      expect(cart.quantity(apple.id), 0);
      for (var i = 0; i < 10; i++) {
        cart.add(milk);
      }
      expect(cart.quantity(milk.id), milk.availableQuantity);
      products.toggleFavourite(apple.id);
      expect(products.favourites.single.id, apple.id);
      products.toggleFavourite(apple.id);
      expect(products.favourites, isEmpty);
      cart.bindUser('another-user');
      expect(cart.count, 0);
      cart.dispose();
      products.dispose();
    },
  );
  test('Query, category and detail lookups retain product identity', () {
    final products = ProductProvider();
    expect(products.matching(query: 'eggs').single.id, 'farm-eggs');
    expect(products.matching(category: 'Dairy').map((p) => p.id), [
      'farm-eggs',
      'whole-milk',
    ]);
    expect(products.matching(category: 'Bakery'), isEmpty);
    expect(products.byId('missing'), isNull);
    products.dispose();
  });
}
