import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/message_service.dart';
import '../../../shared/widgets/order_chat_view.dart';

/// Customer view of the order chat with the shop.
class OrderMessagesScreen extends StatelessWidget {
  const OrderMessagesScreen({
    super.key,
    required this.orderId,
    this.shopName,
    this.messages,
  });

  final String? orderId;
  final String? shopName;
  final MessageService? messages;

  @override
  Widget build(BuildContext context) {
    final id = orderId;
    final name = shopName?.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.goNamed('my-orders'),
        ),
        title: Text(name == null || name.isEmpty ? 'Message Shop' : name),
      ),
      body: SafeArea(
        top: false,
        child: id == null || id.isEmpty
            ? const Center(child: Text('This order is unavailable.'))
            : OrderChatView(
                orderId: id,
                service: messages,
                emptyText:
                    'Ask the shop about your order, substitutions or pickup.',
              ),
      ),
    );
  }
}
