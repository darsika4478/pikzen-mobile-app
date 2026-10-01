// The public named injection parameters are intentionally kept stable.
// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/notification_model.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? database, FirebaseAuth? auth})
    : _database = database,
      _auth = auth;

  final FirebaseFirestore? _database;
  final FirebaseAuth? _auth;

  FirebaseFirestore get database => _database ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  CollectionReference<Map<String, dynamic>> get _notifications =>
      database.collection('notifications');

  Stream<List<NotificationModel>> forUser(String userId) => _notifications
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc.id, doc.data()))
            .toList(growable: false),
      );

  Stream<NotificationModel?> watch(String notificationId) => _notifications
      .doc(notificationId)
      .snapshots()
      .map(
        (doc) => doc.exists
            ? NotificationModel.fromFirestore(doc.id, doc.data()!)
            : null,
      );

  Future<void> markRead(String notificationId) async {
    final userId = auth.currentUser?.uid;
    if (userId == null) throw StateError('Authentication is required.');
    final ref = _notifications.doc(notificationId);
    await database.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data()?['userId'] != userId) {
        throw StateError('Notification is unavailable.');
      }
      if (snapshot.data()?['isRead'] != true) {
        transaction.update(ref, {'isRead': true});
      }
    });
  }

  DocumentReference<Map<String, dynamic>> eventReference(String id) =>
      _notifications.doc(id);

  Map<String, dynamic> orderEventData({
    required String id,
    required String userId,
    required String type,
    required String title,
    required String message,
    required String orderId,
  }) => {
    'id': id,
    'userId': userId,
    'type': type,
    'title': title,
    'message': message,
    'orderId': orderId,
    'productId': null,
    'createdAt': FieldValue.serverTimestamp(),
    'isRead': false,
  };
}
