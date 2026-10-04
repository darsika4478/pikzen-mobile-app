import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/product_model.dart';

void main() {
  const apple = ProductModel(
    id: 'apple',
    name: 'Apple',
    priceMinor: 1000,
    currencyCode: 'LKR',
    stockQuantity: 3,
    shopId: 'shop-1',
  );

  group('Current product validation', () {
    const line = CartItemModel(product: apple, quantity: 2);

    test('accepts current price, shop and available stock', () {
      expect(
        () =>
            OrderService.validateCurrentProduct(line, apple, shopId: 'shop-1'),
        returnsNormally,
      );
    });

    test('rejects a product removed from the shared catalog', () {
      expect(
        () => OrderService.validateCurrentProduct(line, null, shopId: 'shop-1'),
        throwsA(isA<OrderActionException>()),
      );
    });

    test('rejects insufficient stock and never accepts negative stock', () {
      const lowStock = ProductModel(
        id: 'apple',
        name: 'Apple',
        priceMinor: 1000,
        currencyCode: 'LKR',
        stockQuantity: 1,
        shopId: 'shop-1',
      );
      expect(
        () => OrderService.validateCurrentProduct(
          line,
          lowStock,
          shopId: 'shop-1',
        ),
        throwsA(isA<OrderActionException>()),
      );
    });

    test('rejects a changed price or shop', () {
      const repriced = ProductModel(
        id: 'apple',
        name: 'Apple',
        priceMinor: 1200,
        currencyCode: 'LKR',
        stockQuantity: 3,
        shopId: 'shop-1',
      );
      expect(
        () => OrderService.validateCurrentProduct(
          line,
          repriced,
          shopId: 'shop-1',
        ),
        throwsA(isA<OrderActionException>()),
      );
      expect(
        () =>
            OrderService.validateCurrentProduct(line, apple, shopId: 'shop-2'),
        throwsA(isA<OrderActionException>()),
      );
    });
  });

  test('shared cart adopts current price and clamps changed stock', () {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    cart.add(apple);
    cart.add(apple);
    expect(cart.totalMinor, 2000);

    const latest = ProductModel(
      id: 'apple',
      name: 'Apple',
      priceMinor: 1500,
      currencyCode: 'LKR',
      stockQuantity: 1,
      shopId: 'shop-1',
    );
    cart.syncProducts([latest]);
    expect(cart.quantity('apple'), 1);
    expect(cart.totalMinor, 1500);
    expect(cart.add(apple), isFalse);

    cart.decrease('apple');
    expect(cart.items, isEmpty);
  });
}
