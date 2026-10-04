import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_order_details.dart';
import '../models/chat_message.dart';
import '../widgets/customer_chat_header.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/message_composer.dart';

class ContactCustomerScreen extends StatefulWidget {
  const ContactCustomerScreen({super.key, required this.order});
  final MockOrderDetails order;
  @override
  State<ContactCustomerScreen> createState() => _ContactCustomerScreenState();
}

class _ContactCustomerScreenState extends State<ContactCustomerScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _composerKey = GlobalKey();
  final _messages = List<ChatMessage>.of(initialCustomerConversation);

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

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    setState(
      () => _messages.add(
        ChatMessage(
          text: text,
          time:
              '$hour:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}',
          isMerchant: true,
        ),
      ),
    );
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
                      pathParameters: {
                        'orderId': widget.order.orderId.substring(1),
                      },
                    );
                  }
                },
                onCall: () => _preview('Call ${widget.order.customerName}'),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) => index == 0
                      ? const ChatDateSeparator()
                      : ChatMessageBubble(
                          message: _messages[index - 1],
                          initials: widget.order.initials,
                        ),
                ),
              ),
              MessageComposer(
                key: _composerKey,
                controller: _input,
                onSend: _send,
                onAttach: () => _preview('Attach file'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
