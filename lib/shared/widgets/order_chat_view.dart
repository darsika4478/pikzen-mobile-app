import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/message_service.dart';
import '../../core/services/order_service.dart';
import '../../features/shop_management/widgets/message_composer.dart';
import '../../models/message_model.dart';

/// Live order chat used by both the shop and the customer screens.
class OrderChatView extends StatefulWidget {
  const OrderChatView({
    super.key,
    required this.orderId,
    this.service,
    this.composerKey,
    this.emptyText = 'No messages yet. Say hello!',
  });

  final String orderId;
  final MessageService? service;
  final Key? composerKey;
  final String emptyText;

  @override
  State<OrderChatView> createState() => _OrderChatViewState();
}

class _OrderChatViewState extends State<OrderChatView> {
  late final MessageService _service = widget.service ?? MessageService();
  late final Stream<List<OrderMessage>> _messages = _service.watch(
    widget.orderId,
  );
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _input.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.send(widget.orderId, _input.text);
      _input.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is OrderActionException
                  ? error.message
                  : 'The message could not be sent.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: StreamBuilder<List<OrderMessage>>(
          stream: _messages,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _ChatNotice('Messages are unavailable right now.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final messages = snapshot.data!;
            if (messages.isEmpty) return _ChatNotice(widget.emptyText);
            final me = _service.currentUserId;
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                return _Bubble(message: message, mine: message.senderId == me);
              },
            );
          },
        ),
      ),
      MessageComposer(
        key: widget.composerKey,
        controller: _input,
        onSend: _sending ? null : () => unawaited(_send()),
        onAttach: null,
      ),
    ],
  );
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.secondaryText),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final OrderMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final sent = message.createdAt;
    final time = sent == null
        ? 'Sending…'
        : '${sent.hour % 12 == 0 ? 12 : sent.hour % 12}:'
              '${sent.minute.toString().padLeft(2, '0')} '
              '${sent.hour < 12 ? 'AM' : 'PM'}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.surface,
            border: mine ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  color: mine ? AppColors.surface : AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                time,
                style: TextStyle(
                  fontSize: 9,
                  color: mine ? AppColors.softGreen : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
