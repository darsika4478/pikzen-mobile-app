import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/cart_item_model.dart';
import '../../models/order_model.dart';
import 'notification_service.dart';

class OrderActionException implements Exception {
  const OrderActionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One Firestore source for customer and shop order operations.
class OrderService {
  OrderService({
    FirebaseFirestore? database,
    FirebaseAuth? auth,
    NotificationService? notifications,
  }) : _database = database,
       _auth = auth,
       _notifications =
           notifications ?? NotificationService(database: database, auth: auth);

  final FirebaseFirestore? _database;
  final FirebaseAuth? _auth;
  final NotificationService _notifications;

  FirebaseFirestore get database => _database ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  CollectionReference<Map<String, dynamic>> get _orders =>
      database.collection('orders');

  String allocateOrderId() => _orders.doc().id;

  OrderModel newDraft({
    required String customerId,
    required List<CartItemModel> items,
    required DateTime? pickupAt,
    String? shopId,
    String? shopName,
  }) {
    if (items.isEmpty) {
      throw const OrderActionException('Add items before placing an order.');
    }
    final total = items.fold<int>(
      0,
      (totalMinor, item) =>
          totalMinor + item.product.priceMinor * item.quantity,
    );
    return OrderModel(
      id: allocateOrderId(),
      userId: customerId,
      items: items,
      createdAt: DateTime.now(),
      pickupAt: pickupAt,
      status: 'placed',
      shopId: shopId,
      shopName: shopName,
      totalMinor: total,
      currencyCode: items.first.product.currencyCode,
    );
  }

  Stream<List<OrderModel>> forCustomer(String customerId) => _orders
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
            .toList(growable: false),
      );

  Stream<OrderModel?> watchOrder(String orderId) => _orders
      .doc(orderId)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists
            ? OrderModel.fromFirestore(snapshot.id, snapshot.data()!)
            : null,
      );

  Future<OrderModel> createOrderOnce(
    OrderModel draft, {
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    final customerId = auth.currentUser?.uid;
    if (customerId == null || customerId != draft.userId) {
      throw const OrderActionException('Sign in before placing an order.');
    }
    if (draft.items.isEmpty) {
      throw const OrderActionException('This order has no items.');
    }
    if (!const {'card', 'cashOnPickup'}.contains(paymentMethod)) {
      throw const OrderActionException('This payment method is not supported.');
    }
    if (!const {'demo', 'unpaid'}.contains(paymentStatus)) {
      throw const OrderActionException('This payment status is not supported.');
    }
    if ((paymentMethod == 'card' && paymentStatus != 'demo') ||
        (paymentMethod == 'cashOnPickup' && paymentStatus != 'unpaid')) {
      throw const OrderActionException(
        'The payment state does not match the method.',
      );
    }

    final ref = _orders.doc(draft.id);
    await database.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        if (snapshot.data()?['customerId'] != customerId) {
          throw const OrderActionException('This order ID is already in use.');
        }
        return;
      }

      final order = draft.copyWith(
        status: 'placed',
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
      );
      transaction.set(ref, order.toFirestore(serverTimestamps: true));
    });

    final saved = await ref.get();
    if (!saved.exists) {
      throw const OrderActionException('The order could not be saved.');
    }
    return OrderModel.fromFirestore(saved.id, saved.data()!);
  }

  Future<void> cancelOrder(String orderId) async {
    final customerId = auth.currentUser?.uid;
    if (customerId == null) {
      throw const OrderActionException('Sign in before cancelling an order.');
    }
    final ref = _orders.doc(orderId);
    await database.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw const OrderActionException('This order is unavailable.');
      }
      final data = snapshot.data()!;
      if (data['customerId'] != customerId) {
        throw const OrderActionException('This order is unavailable.');
      }
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (!const {
        'placed',
        'pending',
        'accepted',
        'confirmed',
        'preparing',
      }.contains(status)) {
        throw const OrderActionException(
          'This order can no longer be cancelled.',
        );
      }
      transaction.update(ref, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Shop-side API. Shop screens can call this without owning a second order
  /// collection; accepted/ready events are written atomically with the order.
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final shopId = auth.currentUser?.uid;
    if (shopId == null) {
      throw const OrderActionException('Sign in before updating an order.');
    }
    final profile = await database.collection('users').doc(shopId).get();
    if (profile.data()?['role'] != 'shop' ||
        profile.data()?['approvalStatus'] != 'approved') {
      throw const OrderActionException('An approved shop account is required.');
    }

    final nextStatus = status.trim().toLowerCase();
    if (!const {
      'accepted',
      'preparing',
      'ready',
      'collected',
    }.contains(nextStatus)) {
      throw const OrderActionException('This order status is not supported.');
    }

    final orderRef = _orders.doc(orderId);
    await database.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw const OrderActionException('This order is unavailable.');
      }
      final data = orderSnapshot.data()!;
      if (data['shopId'] != shopId) {
        throw const OrderActionException('This order is unavailable.');
      }
      final currentStatus = (data['status'] ?? 'placed').toString();
      if (currentStatus == nextStatus) return;
      if (!_canTransition(currentStatus, nextStatus)) {
        throw const OrderActionException('This status change is not allowed.');
      }

      DocumentReference<Map<String, dynamic>>? notificationRef;
      Map<String, dynamic>? notificationData;
      if (nextStatus == 'accepted' || nextStatus == 'ready') {
        final notificationType = nextStatus == 'ready'
            ? 'ORDER_READY'
            : 'ORDER_ACCEPTED';
        final suffix = nextStatus == 'ready' ? 'ORDER_READY' : 'ORDER_ACCEPTED';
        notificationRef = _notifications.eventReference('${orderId}_$suffix');
        final notificationSnapshot = await transaction.get(notificationRef);
        if (!notificationSnapshot.exists) {
          final displayId = orderId.startsWith('#') ? orderId : '#$orderId';
          notificationData = _notifications.orderEventData(
            id: '${orderId}_$suffix',
            userId: (data['customerId'] ?? '').toString(),
            type: notificationType,
            title: nextStatus == 'ready' ? 'Order Ready!' : 'Order Accepted',
            message: nextStatus == 'ready'
                ? '$displayId is ready for pickup.'
                : '$displayId has been accepted.',
            orderId: orderId,
          );
        }
      }

      final update = <String, Object?>{
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        switch (nextStatus) {
          'accepted' => 'acceptedAt',
          'preparing' => 'preparingAt',
          'ready' => 'readyAt',
          'collected' => 'collectedAt',
          _ => 'updatedAt',
        }: FieldValue.serverTimestamp(),
      };
      if (nextStatus == 'collected') {
        update['completedAt'] = FieldValue.serverTimestamp();
      }
      transaction.update(orderRef, update);
      if (notificationRef != null && notificationData != null) {
        transaction.set(notificationRef, notificationData);
      }
    });
  }

  static bool canCustomerCancel(String? status) => const {
    'placed',
    'pending',
    'accepted',
    'confirmed',
    'preparing',
  }.contains(status?.trim().toLowerCase());

  static bool _canTransition(String current, String next) => switch (current) {
    'placed' || 'pending' => next == 'accepted',
    'accepted' || 'confirmed' => next == 'preparing',
    'preparing' => next == 'ready',
    'ready' => next == 'collected',
    _ => false,
  };
}
