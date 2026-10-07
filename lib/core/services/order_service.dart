import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/cart_item_model.dart';
import '../../models/order_model.dart';
import '../../models/payment_model.dart';
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
  CollectionReference<Map<String, dynamic>> get _payments =>
      database.collection('payments');

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

  Future<String> approvedShopUid() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw const OrderActionException(
        'Sign in with an approved shop account.',
      );
    }
    final profile = await database.collection('users').doc(uid).get();
    if (profile.data()?['role'] != 'shop' ||
        profile.data()?['approvalStatus'] != 'approved') {
      throw const OrderActionException('An approved shop account is required.');
    }
    return uid;
  }

  Stream<List<OrderModel>> forShop() async* {
    final uid = await approvedShopUid();
    yield* _orders.where('shopId', isEqualTo: uid).snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Stream<OrderModel?> watchShopOrder(String orderId) async* {
    final uid = await approvedShopUid();
    yield* watchOrder(orderId)
        .map((order) => order?.shopId == uid ? order : null);
  }

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

  /// Simulated payment receipt for an order, or null for legacy orders.
  Stream<PaymentModel?> watchPayment(String orderId) => _payments
      .doc(orderId)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists
            ? PaymentModel.fromFirestore(snapshot.id, snapshot.data()!)
            : null,
      );

  Future<OrderModel> createOrderOnce(
    OrderModel draft, {
    required String paymentMethod,
    required String paymentStatus,
    DemoPaymentDetails paymentDetails = const DemoPaymentDetails(),
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

    if (draft.items.length > 4) {
      throw const OrderActionException(
        'Place up to 4 different products in one order.',
      );
    }
    if (draft.items.any((item) => item.quantity < 1 || item.quantity > 1000)) {
      throw const OrderActionException(
        'Review the item quantities in your cart.',
      );
    }
    final cardLast4 = paymentDetails.cardLast4;
    if (cardLast4 != null &&
        (paymentMethod != 'card' || !RegExp(r'^\d{4}$').hasMatch(cardLast4))) {
      throw const OrderActionException('The payment details are invalid.');
    }
    final provider = paymentDetails.provider?.trim();
    if (provider != null && provider.length > 60) {
      throw const OrderActionException('The payment details are invalid.');
    }
    final orderRef = _orders.doc(draft.id);
    try {
      await database.runTransaction((transaction) async {
        final customer = await transaction.get(
          database.collection('users').doc(customerId),
        );
        if (!customer.exists || customer.data()?['role'] != 'customer') {
          throw const OrderActionException('A customer account is required.');
        }
        final productRefs = [
          for (final item in draft.items)
            database.collection('products').doc(item.product.id),
        ];
        final productDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final ref in productRefs) {
          productDocs.add(await transaction.get(ref));
        }
        final currentItems = <CartItemModel>[];
        final stocks = <int>[];
        String? currency;
        var totalMinor = 0;
        for (var index = 0; index < draft.items.length; index++) {
          final doc = productDocs[index];
          final data = doc.data();
          if (!doc.exists ||
              data == null ||
              data['priceMinor'] is! int ||
              data['priceMinor'] <= 0 ||
              data['stockQuantity'] is! int ||
              data['stockQuantity'] < 0) {
            throw const OrderActionException(
              'A product is no longer available. Review your cart.',
            );
          }
          final current = ProductModel.fromMap(doc.id, data);
          final item = validateCurrentProduct(
            draft.items[index],
            current,
            shopId: draft.shopId!,
          );
          if (currency != null && currency != current.currencyCode) {
            throw const OrderActionException(
              'Products use incompatible currencies.',
            );
          }
          currency = current.currencyCode;
          currentItems.add(item);
          stocks.add(current.stockQuantity - item.quantity);
          totalMinor += current.priceMinor * item.quantity;
          if (totalMinor < 1) {
            throw const OrderActionException('The order amount is invalid.');
          }
        }

        // A customer cannot read the shop's private user profile. Firestore
        // rules validate its approval when the order is created.
        final liveShopName = currentItems.first.product.shopName.trim();
        final shopName = liveShopName.isNotEmpty
            ? liveShopName
            : (draft.shopName ?? '').trim();
        final savedOrder = OrderModel(
          id: draft.id,
          userId: customerId,
          items: currentItems,
          createdAt: DateTime.now(),
          pickupAt: draft.pickupAt,
          replacementPreference: draft.replacementPreference,
          status: 'placed',
          shopId: draft.shopId,
          shopName: shopName,
          totalMinor: totalMinor,
          currencyCode: currency!,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
        );
        final data = savedOrder.toFirestore(serverTimestamps: true);
        // Rules require these to match the customer's own profile exactly.
        final profile = customer.data()!;
        data['customerName'] = profile['fullName'] is String
            ? profile['fullName']
            : '';
        if (profile['phone'] is String?) {
          data['customerPhone'] = profile['phone'];
        }
        data['subtotalMinor'] = totalMinor;
        data['stockReserved'] = true;
        data['stockRestored'] = false;
        data['stockQuantities'] = {
          for (final item in currentItems) item.product.id: item.quantity,
        };
        data['items'] = [
          for (final item in currentItems)
            {
              'productId': item.product.id,
              'productName': item.product.name,
              'quantity': item.quantity,
              'unitPriceMinor': item.product.priceMinor,
              'lineTotalMinor': item.product.priceMinor * item.quantity,
              'currencyCode': item.product.currencyCode,
              'imageUrl': item.product.imageUrl,
              'unit': item.unit,
            },
        ];
        transaction.set(orderRef, data);
        transaction.set(_payments.doc(draft.id), {
          'id': draft.id,
          'orderId': draft.id,
          'customerId': customerId,
          'shopId': draft.shopId,
          'method': paymentMethod,
          'provider': provider == null || provider.isEmpty ? null : provider,
          'cardLast4': cardLast4,
          'amountMinor': totalMinor,
          'currencyCode': currency,
          'status': paymentMethod == 'cashOnPickup' ? 'pending' : 'demo_paid',
          'reference': PaymentModel.referenceFor(draft.id),
          'isDemo': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        for (var index = 0; index < productRefs.length; index++) {
          transaction.update(productRefs[index], {
            'stockQuantity': stocks[index],
            'stockChangeOrderId': draft.id,
            'stockChangeKind': 'reserved',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      final saved = await orderRef.get();
      if (!saved.exists) {
        throw const OrderActionException(
          'Unable to place your order. Please try again.',
        );
      }
      return OrderModel.fromFirestore(saved.id, saved.data()!);
    } on OrderActionException {
      rethrow;
    } catch (_) {
      // The order ID is stable across retries. If a previous attempt committed
      // but its acknowledgement was lost, the existing order is readable by
      // its customer and must not reserve stock twice.
      try {
        final existing = await orderRef.get(
          const GetOptions(source: Source.server),
        );
        if (existing.exists) {
          if (!_sameSubmission(
            existing.data()!,
            draft,
            paymentMethod,
            paymentStatus,
          )) {
            throw const OrderActionException(
              'This checkout has already been used. Start again.',
            );
          }
          return OrderModel.fromFirestore(existing.id, existing.data()!);
        }
      } on OrderActionException {
        rethrow;
      } catch (_) {
        // Reading a nonexistent order is denied by the current rules.
      }
      throw const OrderActionException(
        'Unable to place your order. Please try again.',
      );
    }
  }

  static bool _sameSubmission(
    Map<String, dynamic> saved,
    OrderModel draft,
    String paymentMethod,
    String paymentStatus,
  ) {
    final items = saved['items'];
    final pickup = saved['pickupAt'];
    return saved['customerId'] == draft.userId &&
        saved['shopId'] == draft.shopId &&
        saved['stockReserved'] == true &&
        saved['status'] != 'cancelled' &&
        saved['paymentMethod'] == paymentMethod &&
        saved['paymentStatus'] == paymentStatus &&
        saved['replacementPreference'] == draft.replacementPreference &&
        pickup is Timestamp &&
        pickup.millisecondsSinceEpoch ==
            draft.pickupAt?.millisecondsSinceEpoch &&
        items is List &&
        items.length == draft.items.length &&
        List.generate(items.length, (index) => index).every((index) {
          final item = items[index];
          return item is Map &&
              item['productId'] == draft.items[index].product.id &&
              item['quantity'] == draft.items[index].quantity;
        });
  }

  static CartItemModel validateCurrentProduct(
    CartItemModel ordered,
    ProductModel? current, {
    required String shopId,
  }) {
    if (current == null || !current.isActive) {
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
    if (current.priceMinor <= 0) {
      throw const OrderActionException('A product has an invalid price.');
    }
    return CartItemModel(
      product: current,
      quantity: ordered.quantity,
      unit: ordered.unit,
    );
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
    await _releaseOrder(
      orderId,
      actorId: customerId,
      shopActor: false,
      reason: reason.name,
      note: trimmedNote,
    );
  }

  /// Shop-side API. Shop screens can call this without owning a second order
  /// collection; accepted/ready events are written atomically with the order.
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final shopId = await approvedShopUid();

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

      if (nextStatus == 'accepted' && data['stockReserved'] != true) {
        final rawItems = data['items'];
        if (rawItems is! List || rawItems.isEmpty) {
          throw const OrderActionException('This order has no valid items.');
        }
        for (final raw in rawItems) {
          if (raw is! Map ||
              raw['productId'] is! String ||
              raw['quantity'] is! int ||
              raw['quantity'] <= 0) {
            throw const OrderActionException('This order has invalid items.');
          }
          final productRef = database
              .collection('products')
              .doc(raw['productId'] as String);
          final productSnapshot = await transaction.get(productRef);
          if (!productSnapshot.exists) {
            throw const OrderActionException(
              'An ordered product is unavailable.',
            );
          }
          final product = ProductModel.fromMap(
            productSnapshot.id,
            productSnapshot.data()!,
          );
          if (!product.isActive ||
              product.shopId != shopId ||
              product.stockQuantity < (raw['quantity'] as int)) {
            throw OrderActionException(
              '${product.name} is unavailable in the requested quantity.',
            );
          }
        }
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

      // Cash on pickup is settled when the customer collects the order.
      final settleCash =
          nextStatus == 'collected' &&
          data['paymentMethod'] == 'cashOnPickup' &&
          data['paymentStatus'] != 'paid';
      final paymentRef = _payments.doc(orderId);
      final settlePayment =
          settleCash &&
          (await transaction.get(paymentRef)).data()?['status'] == 'pending';

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
      if (settleCash) update['paymentStatus'] = 'paid';
      transaction.update(orderRef, update);
      if (settlePayment) {
        transaction.update(paymentRef, {
          'status': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
        });
      }
      if (notificationRef != null && notificationData != null) {
        transaction.set(notificationRef, notificationData);
      }
    });
  }

  Future<void> rejectShopOrder(String orderId) async {
    final shopId = await approvedShopUid();
    await _releaseOrder(
      orderId,
      actorId: shopId,
      shopActor: true,
      reason: 'shopRejected',
    );
  }

  Future<void> _releaseOrder(
    String orderId, {
    required String actorId,
    required bool shopActor,
    required String reason,
    String? note,
  }) async {
    final orderRef = _orders.doc(orderId);
    try {
      await database.runTransaction((transaction) async {
        final actor = await transaction.get(
          database.collection('users').doc(actorId),
        );
        if (!actor.exists ||
            actor.data()?['role'] != (shopActor ? 'shop' : 'customer') ||
            (shopActor && actor.data()?['approvalStatus'] != 'approved')) {
          throw const OrderActionException(
            'This account cannot cancel the order.',
          );
        }
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) {
          throw const OrderActionException('This order is unavailable.');
        }
        final order = snapshot.data()!;
        if (order[shopActor ? 'shopId' : 'customerId'] != actorId) {
          throw const OrderActionException('This order is unavailable.');
        }
        if (order['status'] == 'cancelled') return;
        if (shopActor
            ? order['status'] != 'placed'
            : !canCustomerCancel(order['status'] as String?)) {
          throw const OrderActionException(
            'This order can no longer be cancelled.',
          );
        }
        if (order['stockRestored'] == true) {
          throw const OrderActionException('Stock was already restored.');
        }

        final reserved = order['stockReserved'] == true;
        final refs = <DocumentReference<Map<String, dynamic>>>[];
        final newStocks = <int>[];
        if (reserved) {
          final rawItems = order['items'];
          if (rawItems is! List || rawItems.isEmpty || rawItems.length > 4) {
            throw const OrderActionException(
              'This order cannot be cancelled automatically.',
            );
          }
          final quantities = <String, int>{};
          for (final raw in rawItems) {
            if (raw is! Map ||
                raw['productId'] is! String ||
                (raw['productId'] as String).isEmpty ||
                raw['quantity'] is! int ||
                (raw['quantity'] as int) < 1 ||
                quantities.containsKey(raw['productId'])) {
              throw const OrderActionException(
                'This order cannot be cancelled automatically.',
              );
            }
            quantities[raw['productId'] as String] = raw['quantity'] as int;
          }
          for (final productId in quantities.keys) {
            refs.add(database.collection('products').doc(productId));
          }
          for (final ref in refs) {
            final product = await transaction.get(ref);
            final stock = product.data()?['stockQuantity'];
            if (!product.exists ||
                product.data()?['shopId'] != order['shopId'] ||
                stock is! int ||
                stock < 0) {
              throw const OrderActionException(
                'Stock could not be restored safely.',
              );
            }
            newStocks.add(stock + quantities[ref.id]!);
          }
        }

        // Tell the customer once when the shop rejects their order.
        DocumentReference<Map<String, dynamic>>? notificationRef;
        if (shopActor) {
          final ref = _notifications.eventReference(
            '${orderId}_ORDER_REJECTED',
          );
          if (!(await transaction.get(ref)).exists) notificationRef = ref;
        }

        transaction.update(orderRef, {
          'status': 'cancelled',
          'cancellationReason': reason,
          'cancellationNote': note?.isEmpty == true ? null : note,
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (reserved) 'stockRestored': true,
        });
        for (var index = 0; index < refs.length; index++) {
          transaction.update(refs[index], {
            'stockQuantity': newStocks[index],
            'stockChangeOrderId': orderId,
            'stockChangeKind': 'restored',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        if (notificationRef != null) {
          final displayId = orderId.startsWith('#') ? orderId : '#$orderId';
          transaction.set(
            notificationRef,
            _notifications.orderEventData(
              id: notificationRef.id,
              userId: (order['customerId'] ?? '').toString(),
              type: 'ORDER_REJECTED',
              title: 'Order Rejected',
              message:
                  '$displayId was rejected by the shop. Any reserved stock '
                  'has been released.',
              orderId: orderId,
            ),
          );
        }
      });
    } on OrderActionException {
      rethrow;
    } catch (_) {
      throw const OrderActionException(
        'Unable to cancel this order. Please try again.',
      );
    }
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
