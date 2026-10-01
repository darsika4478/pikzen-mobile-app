import 'package:cloud_firestore/cloud_firestore.dart';

/// Display data for a user notification, independent of its delivery mechanism.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.type,
    this.orderId,
    this.productId,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Optional event metadata supplied by the notification source, when known.
  final String? type;
  final String? orderId;
  final String? productId;

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id,
    userId: userId,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    type: type,
    orderId: orderId,
    productId: productId,
  );

  factory NotificationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final createdAt = switch (data['createdAt']) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => null,
    };
    if (createdAt == null) {
      throw const FormatException('Notification is missing createdAt.');
    }
    return NotificationModel(
      id: (data['id'] ?? id).toString(),
      userId: (data['userId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['message'] ?? data['body'] ?? '').toString(),
      createdAt: createdAt,
      isRead: data['isRead'] == true,
      type: data['type'] as String?,
      orderId: data['orderId'] as String?,
      productId: data['productId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore({bool serverTimestamp = false}) => {
    'id': id,
    'userId': userId,
    'type': type,
    'title': title,
    'message': body,
    'orderId': orderId,
    'productId': productId,
    'createdAt': serverTimestamp
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt),
    'isRead': isRead,
  };
}
