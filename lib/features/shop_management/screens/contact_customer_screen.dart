import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/message_service.dart';
import '../../../shared/widgets/order_chat_view.dart';
import '../models/mock_order_details.dart';
import '../widgets/customer_chat_header.dart';

class ContactCustomerScreen extends StatefulWidget {
  const ContactCustomerScreen({super.key, required this.order, this.messages});
  final MockOrderDetails order;
  final MessageService? messages;
  @override
  State<ContactCustomerScreen> createState() => _ContactCustomerScreenState();
}

class _ContactCustomerScreenState extends State<ContactCustomerScreen> {
  final _composerKey = GlobalKey();

  String get _orderId => widget.order.orderId.startsWith('#')
      ? widget.order.orderId.substring(1)
      : widget.order.orderId;

  void _preview(String message) {
    final composer =
        _composerKey.currentContext?.findRenderObject() as RenderBox?;
    final bottomMargin = (composer?.size.height ?? 64) + 8;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        ),
      );
  }

  Future<void> _call() async {
    final phone = widget.order.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      _preview('Customer phone is unavailable for this order.');
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) _preview('Unable to start a call to $phone.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              CustomerChatHeader(
                order: widget.order,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed(
                      'shop-order-details',
                      pathParameters: {'orderId': _orderId},
                    );
                  }
                },
                onCall: _call,
              ),
              Expanded(
                child: OrderChatView(
                  orderId: _orderId,
                  service: widget.messages,
                  composerKey: _composerKey,
                  emptyText:
                      'No messages yet. Messages you send here notify the '
                      'customer.',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
