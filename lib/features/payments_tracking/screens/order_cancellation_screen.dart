import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';
import '../../cart_checkout/widgets/checkout_ui.dart';

class OrderCancellationScreen extends StatefulWidget {
  const OrderCancellationScreen({
    super.key,
    required this.orderId,
    this.order,
    this.orderService,
  });

  final String? orderId;
  final OrderModel? order;
  final OrderService? orderService;

  @override
  State<OrderCancellationScreen> createState() =>
      _OrderCancellationScreenState();
}

class _OrderCancellationScreenState extends State<OrderCancellationScreen> {
  final _noteController = TextEditingController();
  late final OrderService _orders = widget.orderService ?? OrderService();
  Stream<OrderModel?>? _stream;
  CancellationReason? _reason;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final id = widget.orderId ?? widget.order?.id;
    if (id != null &&
        (widget.orderService != null || Firebase.apps.isNotEmpty)) {
      _stream = _orders.watchOrder(id);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _keepOrder(String id) {
    if (_submitting) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('order-details', extra: id);
    }
  }

  Future<void> _requestCancellation(OrderModel order) async {
    if (_submitting) return;
    final reason = _reason;
    if (reason == null) {
      _message('Please select a cancellation reason.');
      return;
    }
    if (!OrderService.canCustomerCancel(order.status)) {
      _message('This order can no longer be cancelled.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await _orders.cancelOrder(
        order.id,
        reason: reason,
        note: _noteController.text,
      );
      if (!mounted) return;
      context.goNamed(
        'order-details',
        extra: {'orderId': order.id, 'showCancellationSuccess': true},
      );
    } on OrderActionException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('The order could not be cancelled. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CheckoutHeader(),
      body: SafeArea(
        top: false,
        child: _stream == null
            ? _content(widget.order)
            : StreamBuilder<OrderModel?>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _unavailable(
                      'Order details are unavailable right now.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _content(snapshot.data);
                },
              ),
      ),
    );
  }

  Widget _unavailable(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.goNamed('my-orders'),
            child: const Text('My Orders'),
          ),
        ],
      ),
    ),
  );

  Widget _content(OrderModel? order) {
    if (order == null) return _unavailable('This order could not be found.');
    final canCancel = OrderService.canCustomerCancel(order.status);
    final status = switch (order.status?.toLowerCase()) {
      'placed' || 'pending' => 'Order placed',
      'accepted' || 'confirmed' => 'Accepted',
      'preparing' => 'Preparing',
      'ready' => 'Ready for pickup',
      'collected' || 'completed' => 'Collected',
      'cancelled' => 'Cancelled',
      _ => 'Status unavailable',
    };
    final count = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final id = order.id.startsWith('#') ? order.id : '#${order.id}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ACTIVE PICKUP ORDER',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: .5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '$count items · ${rupees(order.effectiveTotalMinor)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xFFFFDFDC),
                  child: const Icon(
                    Icons.error,
                    color: Color(0xFFBE1717),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              const Text(
                'Cancel Order?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Are you sure you want to cancel this order? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 20),
              const Text(
                'Please select a reason for cancellation:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (final reason in CancellationReason.values) ...[
                _ReasonOption(
                  reason: reason,
                  selected: _reason == reason,
                  onTap: canCancel && !_submitting
                      ? () => setState(() => _reason = reason)
                      : null,
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                enabled: canCancel && !_submitting,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Tell us more (optional)...',
                  filled: true,
                  fillColor: Color(0xFFF2F4F2),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: canCancel && !_submitting
                      ? () => _requestCancellation(order)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFBD1717),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                    _submitting ? 'Cancelling...' : 'Yes, Cancel Order',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : () => _keepOrder(order.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9AF19A),
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.arrow_back, size: 17),
                  label: const Text('Keep Order'),
                ),
              ),
              if (!canCancel) ...[
                const SizedBox(height: 10),
                const Text(
                  'This order can no longer be cancelled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Need help with a refund? Contact PikZen Support anytime.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}

class _ReasonOption extends StatelessWidget {
  const _ReasonOption({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final CancellationReason reason;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFFAF3) : const Color(0xFFF2F4F2),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              switch (reason) {
                CancellationReason.changedMind => Icons.psychology_outlined,
                CancellationReason.wrongPickupTime => Icons.schedule,
                CancellationReason.foundElsewhere => Icons.storefront_outlined,
                CancellationReason.other => Icons.edit_note,
              },
              size: 19,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(reason.label, style: const TextStyle(fontSize: 12)),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.accent : AppColors.secondaryText,
            ),
          ],
        ),
      ),
    ),
  );
}
