import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/checkout_provider.dart';
import 'package:pikzen/features/cart_checkout/widgets/add_to_cart.dart';
import 'package:pikzen/features/payments_tracking/screens/customer_order_details_screen.dart';
import 'package:pikzen/features/shop_management/models/availability_item.dart';
import 'package:pikzen/features/shop_management/models/mock_order_details.dart';
import 'package:pikzen/features/shop_management/screens/update_order_status_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

ProductModel product(String id, String shopId) => ProductModel(
  id: id,
  name: 'Product $id',
  priceMinor: 10000,
  currencyCode: 'LKR',
  shopId: shopId,
  shopName: 'Shop $shopId',
);

class _Orders extends OrderService {
  _Orders([this.order]);
  OrderModel? order;
  final statuses = <String>[];
  final checkIns = <String>[];

  @override
  Stream<OrderModel?> watchOrder(String orderId) => Stream.value(order);

  @override
  Future<void> markCustomerView(String orderId, String field) async {}

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async => statuses.add(status);

  @override
  Future<void> checkIn(String orderId) async => checkIns.add(orderId);
}

OrderModel customerOrder(String status) => OrderModel(
  id: 'order-1',
  userId: 'customer-1',
  items: const [
    CartItemModel(
      product: ProductModel(
        id: 'a',
        name: 'Apple',
        priceMinor: 100,
        currencyCode: 'LKR',
      ),
      quantity: 1,
    ),
  ],
  createdAt: DateTime(2026, 10, 8, 9),
  pickupAt: DateTime(2026, 10, 9, 10),
  status: status,
  shopName: 'Shop A',
  pickupCode: '0427',
);

void main() {
  group('cart keeps one shop and the product limit', () {
    test('blocks another shop, then starts a new cart on request', () {
      final cart = CartProvider();
      expect(cart.add(product('a1', 'A')), isTrue);
      final other = product('b1', 'B');
      expect(cart.blockFor(other), CartBlock.otherShop);
      expect(cart.add(other), isFalse);
      expect(cart.shopName, 'Shop A');
      expect(cart.replaceWith(other), isTrue);
      expect(cart.items.single.product.id, 'b1');
    });

    test('allows more of an existing item but not a fifth product', () {
      final cart = CartProvider();
      for (var i = 0; i < CartProvider.maxProducts; i++) {
        expect(cart.add(product('a$i', 'A')), isTrue);
      }
      expect(cart.blockFor(product('a9', 'A')), CartBlock.tooManyProducts);
      expect(cart.add(product('a0', 'A')), isTrue);
      expect(cart.quantity('a0'), 2);
    });

    testWidgets('add-to-cart explains and replaces a different shop cart', (
      tester,
    ) async {
      final cart = CartProvider()..add(product('a1', 'A'));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => addToCart(context, product('b1', 'B')),
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Start a new cart?'), findsOneWidget);
      expect(find.textContaining('Shop A'), findsOneWidget);
      await tester.tap(find.text('Start New Cart'));
      await tester.pumpAndSettle();
      expect(cart.items.single.product.shopId, 'B');
    });
  });

  test('pickup slots leave the shop preparation time', () {
    final now = DateTime(2026, 10, 8, 10, 10);
    final slots = PickupAvailability.slotsFor(DateTime(2026, 10, 8), now);
    expect(slots.first, DateTime(2026, 10, 8, 11));
    expect(
      slots.every(
        (slot) => !slot.isBefore(now.add(const Duration(minutes: 30))),
      ),
      isTrue,
    );
  });

  test('reserved stock does not make an ordered item unavailable', () {
    const item = MockOrderItem(
      name: 'Apples',
      quantity: 4,
      type: OrderItemType.apple,
      productId: 'apples',
    );
    final soldOut = product('apples', 'A');
    expect(
      AvailabilityItem.fromOrderItem(
        item,
        current: ProductModel(
          id: soldOut.id,
          name: soldOut.name,
          priceMinor: 100,
          currencyCode: 'LKR',
          stockQuantity: 0,
        ),
      ).isAvailable,
      isTrue,
    );
  });

  group('pickup handover', () {
    const ready = MockOrderDetails(
      orderId: '#order-1',
      customerName: 'Demo Customer',
      initials: 'DC',
      dateTime: '',
      preparationDeadline: '',
      total: 'LKR 100.00',
      items: [],
      status: 'READY',
      pickupCode: '0427',
      arrivedAtLabel: '8 Oct 2026, 9:55 AM',
    );

    testWidgets('shop must enter the customer pickup code to collect', (
      tester,
    ) async {
      final orders = _Orders();
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateOrderStatusScreen(order: ready, orderService: orders),
        ),
      );
      expect(find.textContaining('Customer has arrived'), findsOneWidget);
      await tester.tap(find.text('Mark as Collected'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1111');
      await tester.tap(find.text('Confirm Handover'));
      await tester.pumpAndSettle();
      expect(find.text('Code does not match this order.'), findsOneWidget);
      expect(orders.statuses, isEmpty);
      await tester.enterText(find.byType(TextField), '0427');
      await tester.tap(find.text('Confirm Handover'));
      await tester.pumpAndSettle();
      expect(orders.statuses, ['collected']);
    });

    testWidgets('customer sees the code and can check in when accepted', (
      tester,
    ) async {
      final orders = _Orders(customerOrder('ready'));
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOrderDetailsScreen(
            orderId: 'order-1',
            orderService: orders,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 4 2 7'), findsOneWidget);
      await tester.tap(find.text("I've Arrived"));
      await tester.pumpAndSettle();
      expect(orders.checkIns, ['order-1']);
    });

    testWidgets('check-in waits until the shop accepts the order', (
      tester,
    ) async {
      final orders = _Orders(customerOrder('placed'));
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOrderDetailsScreen(
            orderId: 'order-1',
            orderService: orders,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Check in after the shop accepts your order'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}
