// The public named injection parameters are intentionally kept stable.
// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/message_model.dart';
import 'notification_service.dart';
import 'order_service.dart';

/// Order chat between a customer and the shop handling the order.
class MessageService {
  MessageService({
    FirebaseFirestore? database,
    FirebaseAuth? auth,
    NotificationService? notifications,
  }) : _database = database,
       _auth = auth,
       _notifications =
           notifications ?? NotificationService(database: database, auth: auth);

  static const maxLength = 1000;

  final FirebaseFirestore? _database;
  final FirebaseAuth? _auth;
  final NotificationService _notifications;

  FirebaseFirestore get database => _database ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;

  String? get currentUserId => auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _messages(String orderId) =>
      database.collection('orders').doc(orderId).collection('messages');

  Stream<List<OrderMessage>> watch(String orderId) =>
      _messages(orderId)
          .orderBy('createdAt')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => OrderMessage.fromFirestore(doc.id, doc.data()))
                .toList(growable: false),
          );

  /// Sends as the shop or the customer, whichever owns the order for the
  /// signed-in account. Shop messages also notify the customer.
  Future<void> send(String orderId, String text) async {
    final uid = currentUserId;
    if (uid == null) {
      throw const OrderActionException('Sign in to send messages.');
    }
    final clean = text.trim();
    if (clean.isEmpty) {
      throw const OrderActionException('Type a message first.');
    }
    if (clean.length > maxLength) {
      throw const OrderActionException(
        'Messages are limited to 1000 characters.',
      );
    }
    final DocumentSnapshot<Map<String, dynamic>> order;
    try {
      order = await database.collection('orders').doc(orderId).get();
    } catch (_) {
      throw const OrderActionException('This order is unavailable.');
    }
    final data = order.data();
    final fromShop = data?['shopId'] == uid;
    if (data == null || (!fromShop && data['customerId'] != uid)) {
      throw const OrderActionException('This order is unavailable.');
    }

    final messageRef = _messages(orderId).doc();
    final batch = database.batch()
      ..set(messageRef, {
        'id': messageRef.id,
        'senderId': uid,
        'senderRole': fromShop ? 'shop' : 'customer',
        'text': clean,
        'createdAt': FieldValue.serverTimestamp(),
      });
    if (fromShop) {
      final shopName = (data['shopName'] ?? '').toString().trim();
      batch.set(
        _notifications.eventReference(messageRef.id),
        _notifications.orderEventData(
          id: messageRef.id,
          userId: (data['customerId'] ?? '').toString(),
          type: 'SHOP_MESSAGE',
          title: shopName.isEmpty ? 'New message' : 'Message from $shopName',
          message: clean,
          orderId: orderId,
        ),
      );
    }
    try {
      await batch.commit();
    } catch (_) {
      throw const OrderActionException(
        'The message could not be sent. Please try again.',
      );
    }
  }
}
