import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/cart_item_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import 'notification_service.dart';

class OrderActionException implements Exception {
  const OrderActionException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum CancellationReason {
  changedMind('Changed my mind'),
  wrongPickupTime('Selected wrong pickup time'),
  foundElsewhere('Found items elsewhere'),
  other('Other reason');

  const CancellationReason(this.label);
  final String label;
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

  String allocateOrderId() {
    if (Firebase.apps.isNotEmpty || _database != null) return _orders.doc().id;
    // Keeps isolated widget tests independent of Firebase initialization.
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      20,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  OrderModel newDraft({
    required String customerId,
    required List<CartItemModel> items,
    required DateTime? pickupAt,
    String? replacementPreference,
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
      replacementPreference: replacementPreference,
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

  Future<void> markCustomerView(String orderId, String field) async {
    if (!const {
      'paymentSuccessViewedAt',
      'confirmationViewedAt',
      'trackingViewedAt',
      'ordersListViewedAt',
      'orderDetailsViewedAt',
    }.contains(field)) {
      throw const OrderActionException('Unsupported view event.');
    }
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw const OrderActionException('Sign in to view this order.');
    }
    final ref = _orders.doc(orderId);
    final snapshot = await ref.get();
    if (!snapshot.exists || snapshot.data()?['customerId'] != uid) {
      throw const OrderActionException('This order is unavailable.');
    }
    await ref.update({field: FieldValue.serverTimestamp()});
  }

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
    if (!const {
      'card',
      'ewallet',
      'onlineBanking',
      'cashOnPickup',
    }.contains(paymentMethod)) {
      throw const OrderActionException('This payment method is not supported.');
    }
    if (!const {'demo', 'unpaid'}.contains(paymentStatus)) {
      throw const OrderActionException('This payment status is not supported.');
    }
    if ((paymentMethod != 'cashOnPickup' && paymentStatus != 'demo') ||
        (paymentMethod == 'cashOnPickup' && paymentStatus != 'unpaid')) {
      throw const OrderActionException(
        'The payment state does not match the method.',
      );
    }
    if (draft.shopId == null || draft.shopId!.isEmpty) {
      throw const OrderActionException('A pickup shop is required.');
    }
    if (draft.pickupAt == null || !draft.pickupAt!.isAfter(DateTime.now())) {
      throw const OrderActionException('Select a future pickup time.');
    }
    if (!const {
      'allowReplacement',
      'contactMe',
      'noReplacement',
    }.contains(draft.replacementPreference)) {
      throw const OrderActionException('Select a replacement preference.');
    }
    if (draft.items.map((item) => item.product.id).toSet().length !=
        draft.items.length) {
      throw const OrderActionException('An item appears twice in this order.');
    }

    final ref = _orders.doc(draft.id);
    OrderModel matchingOrder(DocumentSnapshot<Map<String, dynamic>> snapshot) {
      final existing = OrderModel.fromFirestore(snapshot.id, snapshot.data()!);
      if (existing.userId != customerId ||
          existing.shopId != draft.shopId ||
          existing.paymentMethod != paymentMethod ||
          existing.paymentStatus != paymentStatus ||
          existing.effectiveTotalMinor != draft.effectiveTotalMinor ||
          existing.effectiveCurrencyCode != draft.effectiveCurrencyCode ||
          existing.pickupAt != draft.pickupAt ||
          existing.replacementPreference != draft.replacementPreference ||
          !_sameItems(existing.items, draft.items)) {
        throw const OrderActionException('This order ID is already in use.');
      }
      return existing;
    }

    // The rules allow customers to read their saved orders, but may deny a
    // read of an order ID that has not been created yet.
    try {
      final existing = await ref.get();
      if (existing.exists) return matchingOrder(existing);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    final order = draft.copyWith(
      status: 'placed',
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
    );
    try {
      await database.runTransaction((transaction) async {
        final current = <ProductModel?>[];
        for (final item in draft.items) {
          final snapshot = await transaction.get(
            database.collection('products').doc(item.product.id),
          );
          current.add(
            snapshot.exists
                ? ProductModel.fromMap(snapshot.id, snapshot.data()!)
                : null,
          );
        }
        for (var index = 0; index < draft.items.length; index++) {
          validateCurrentProduct(
            draft.items[index],
            current[index],
            shopId: draft.shopId!,
          );
        }
        var currentTotal = 0;
        for (var index = 0; index < current.length; index++) {
          currentTotal +=
              current[index]!.priceMinor * draft.items[index].quantity;
        }
        if (currentTotal != draft.effectiveTotalMinor) {
          throw const OrderActionException(
            'Order total changed. Review your cart before paying.',
          );
        }
        // Product stock is checked in the same transaction as the order
        // write. Existing rules reserve stock updates for shop owners.
        transaction.set(ref, order.toFirestore(serverTimestamps: true));
      });
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      // A concurrent retry may have created the same order. The rules deny
      // replacing it, so return it only if its contents match this draft.
      final existing = await ref.get();
      if (!existing.exists) rethrow;
      return matchingOrder(existing);
    }

    final saved = await ref.get();
    if (!saved.exists) {
      throw const OrderActionException('The order could not be saved.');
    }
    return OrderModel.fromFirestore(saved.id, saved.data()!);
  }

  static void validateCurrentProduct(
    CartItemModel ordered,
    ProductModel? current, {
    required String shopId,
  }) {
    if (current == null) {
      throw OrderActionException(
        '${ordered.product.name} is no longer available.',
      );
    }
    if (ordered.quantity < 1 || current.stockQuantity < ordered.quantity) {
      throw OrderActionException(
        '${current.name} has only ${current.stockQuantity} available. Review your cart.',
      );
    }
    if (current.shopId != shopId) {
      throw const OrderActionException('Place items from one store at a time.');
    }
    if (current.priceMinor != ordered.product.priceMinor ||
        current.currencyCode != ordered.product.currencyCode) {
      throw OrderActionException(
        '${current.name} changed price. Review your cart.',
      );
    }
  }

  Future<void> cancelOrder(
    String orderId, {
    required CancellationReason reason,
    String? note,
  }) async {
    final customerId = auth.currentUser?.uid;
    if (customerId == null) {
      throw const OrderActionException('Sign in before cancelling an order.');
    }
    final trimmedNote = note?.trim() ?? '';
    if (trimmedNote.length > 500) {
      throw const OrderActionException('The cancellation note is too long.');
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
        'cancellationReason': reason.name,
        'cancellationNote': trimmedNote.isEmpty ? null : trimmedNote,
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

  static bool _sameItems(List<CartItemModel> left, List<CartItemModel> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].product.id != right[i].product.id ||
          left[i].quantity != right[i].quantity ||
          left[i].product.priceMinor != right[i].product.priceMinor ||
          left[i].unit != right[i].unit) {
        return false;
      }
    }
    return true;
  }
}
