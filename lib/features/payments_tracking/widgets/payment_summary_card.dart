import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/payment_model.dart';

class PaymentSummaryCard extends StatelessWidget {
  const PaymentSummaryCard({
    super.key,
    required this.checkout,
    required this.selectionLabel,
    required this.selection,
    this.amountLabel = 'Amount',
  });

  final PaymentCheckoutData checkout;
  final String selectionLabel;
  final String selection;
  final String amountLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        _row(context, selectionLabel, selection),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),
        _row(context, amountLabel, checkout.amountLabel),
      ],
    ),
  );

  Widget _row(BuildContext context, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(width: 14),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
