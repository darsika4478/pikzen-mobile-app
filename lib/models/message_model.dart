import 'package:cloud_firestore/cloud_firestore.dart';

/// One chat message in orders/{orderId}/messages between customer and shop.
class OrderMessage {
  const OrderMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;

  /// 'shop' or 'customer'.
  final String senderRole;
  final String text;

  /// Null only while a local write is waiting for the server timestamp.
  final DateTime? createdAt;

  bool get fromShop => senderRole == 'shop';

  factory OrderMessage.fromFirestore(String id, Map<String, dynamic> data) =>
      OrderMessage(
        id: id,
        senderId: (data['senderId'] ?? '').toString(),
        senderRole: (data['senderRole'] ?? 'customer').toString(),
        text: (data['text'] ?? '').toString(),
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
      );
}
