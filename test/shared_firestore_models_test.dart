import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/notification_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 1, 8);

  test(
    'order Firestore snapshot preserves purchased prices and optional data',
    () {
      final order = OrderModel(
        id: 'order-1',
        userId: 'customer-1',
        items: const [
          CartItemModel(
            product: ProductModel(
              id: 'milk-1',
              name: 'Milk',
              priceMinor: 45000,
              currencyCode: 'LKR',
              imageUrl: 'https://example.test/milk.png',
            ),
            quantity: 2,
            unit: 'bottle',
          ),
        ],
        createdAt: createdAt,
        status: 'placed',
        shopId: 'shop-1',
        totalMinor: 90000,
        currencyCode: 'LKR',
        paymentMethod: 'cashOnPickup',
        paymentStatus: 'unpaid',
      );

      final encoded = order.toFirestore();
      final decoded = OrderModel.fromFirestore('order-1', encoded);

      expect(decoded.effectiveTotalMinor, 90000);
      expect(decoded.items.single.product.priceMinor, 45000);
      expect(decoded.items.single.product.name, 'Milk');
      expect(decoded.items.single.quantity, 2);
      expect(decoded.items.single.unit, 'bottle');
      expect(decoded.pickupAt, isNull);
      expect(decoded.readyAt, isNull);
    },
  );

  test('legacy orders can omit optional lifecycle fields', () {
    final decoded = OrderModel.fromFirestore('legacy-1', {
      'customerId': 'customer-1',
      'createdAt': Timestamp.fromDate(createdAt),
      'items': [],
    });

    expect(decoded.id, 'legacy-1');
    expect(decoded.status, isNull);
    expect(decoded.updatedAt, isNull);
    expect(decoded.cancelledAt, isNull);
  });

  test('notification snapshot keeps order metadata and read state', () {
    final notification = NotificationModel(
      id: 'order-1_ORDER_READY',
      userId: 'customer-1',
      type: 'ORDER_READY',
      title: 'Order Ready!',
      body: 'Your order is ready.',
      orderId: 'order-1',
      createdAt: createdAt,
    );

    final decoded = NotificationModel.fromFirestore(
      notification.id,
      notification.toFirestore(),
    );

    expect(decoded.userId, 'customer-1');
    expect(decoded.type, 'ORDER_READY');
    expect(decoded.orderId, 'order-1');
    expect(decoded.isRead, isFalse);
  });
}
