import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../models/mock_order_details.dart';
import '../widgets/order_status_timeline.dart';
import '../widgets/order_status_summary_card.dart';
import '../widgets/order_status_bottom_bar.dart';

class UpdateOrderStatusScreen extends StatefulWidget {
  const UpdateOrderStatusScreen({
    super.key,
    required this.order,
    this.orderService,
  });
  final MockOrderDetails order;
  final OrderService? orderService;
  @override
  State<UpdateOrderStatusScreen> createState() =>
      _UpdateOrderStatusScreenState();
}

class _UpdateOrderStatusScreenState extends State<UpdateOrderStatusScreen> {
  late final OrderService _orders = widget.orderService ?? OrderService();
  bool _busy = false;
  int get _activeStage => switch (widget.order.status) {
    'ACCEPTED' => 1,
    'PREPARING' => 2,
    'READY' => 3,
    'COLLECTED' => 4,
    _ => 0,
  };

  Future<void> _advance() async {
    if (_busy) return;
    final next = switch (widget.order.status) {
      'ACCEPTED' => 'preparing',
      'PREPARING' => 'ready',
      'READY' => 'collected',
      _ => null,
    };
    if (next == null) return;
    if (next == 'collected' &&
        widget.order.pickupCode.isNotEmpty &&
        !await _verifyPickupCode()) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _orders.updateOrderStatus(
        orderId: widget.order.orderId.substring(1),
        status: next,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status could not be updated: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Handover check: the customer reads out the code from their order.
  Future<bool> _verifyPickupCode() async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => _PickupCodeDialog(expected: widget.order.pickupCode),
      ) ==
      true;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(
        'confirm-availability',
        pathParameters: {'orderId': widget.order.orderId.substring(1)},
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              UpdateOrderStatusHeader(
                orderId: widget.order.orderId,
                onBack: _back,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.order.arrivedAtLabel.isNotEmpty &&
                          _activeStage < 4) ...[
                        _ArrivalBanner(time: widget.order.arrivedAtLabel),
                        const SizedBox(height: 16),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: OrderStatusTimeline(
                          activeStage: _activeStage,
                          acceptedAt: widget.order.acceptedAtLabel,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OrderStatusSummaryCard(order: widget.order),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: OrderStatusBottomBar(
      activeStage: _activeStage,
      onAdvance: _busy || _activeStage == 0 || _activeStage == 4
          ? null
          : _advance,
    ),
  );
}

class _PickupCodeDialog extends StatefulWidget {
  const _PickupCodeDialog({required this.expected});
  final String expected;

  @override
  State<_PickupCodeDialog> createState() => _PickupCodeDialogState();
}

class _PickupCodeDialogState extends State<_PickupCodeDialog> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_input.text == widget.expected) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Code does not match this order.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify pickup code'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ask the customer for the 4-digit code shown in their order.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _confirm(),
          decoration: InputDecoration(
            labelText: 'Pickup code',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('Confirm Handover')),
    ],
  );
}

class _ArrivalBanner extends StatelessWidget {
  const _ArrivalBanner({required this.time});
  final String time;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.lightOrange,
      border: Border.all(color: AppColors.orangeBorder),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.directions_walk_rounded, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Customer has arrived ($time). Please bring the order out.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class UpdateOrderStatusHeader extends StatelessWidget {
  const UpdateOrderStatusHeader({
    super.key,
    required this.orderId,
    required this.onBack,
  });
  final String orderId;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: const CircleBorder(),
              minimumSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Order Status',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                orderId,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
