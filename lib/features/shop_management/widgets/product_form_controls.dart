import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

InputDecoration productFieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.primary),
  ),
);

class ProductFormHeader extends StatelessWidget {
  const ProductFormHeader({
    super.key,
    required this.editing,
    required this.onBack,
    required this.onDelete,
  });
  final bool editing;
  final VoidCallback onBack;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
        ),
        Expanded(
          child: Text(
            editing ? 'Edit Product' : 'Add Product',
            textAlign: editing ? TextAlign.center : TextAlign.right,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        if (editing)
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete product',
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 22,
              color: AppColors.rejectRed,
            ),
          )
        else
          const SizedBox(width: 8),
      ],
    ),
  );
}

class ProductFormField extends StatelessWidget {
  const ProductFormField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

class StockQuantitySelector extends StatelessWidget {
  const StockQuantitySelector({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    this.outlinedControls = false,
  });
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool outlinedControls;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text('$quantity', style: const TextStyle(fontSize: 12)),
        ),
        IconButton(
          onPressed: quantity == 0 ? null : onDecrease,
          tooltip: 'Decrease stock',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.mutedSurface,
            tapTargetSize: outlinedControls
                ? MaterialTapTargetSize.shrinkWrap
                : null,
            side: outlinedControls
                ? const BorderSide(color: AppColors.border)
                : null,
            foregroundColor: AppColors.secondaryText,
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          icon: const Icon(Icons.remove_rounded, size: 17),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onIncrease,
          tooltip: 'Increase stock',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.softGreen,
            tapTargetSize: outlinedControls
                ? MaterialTapTargetSize.shrinkWrap
                : null,
            side: outlinedControls
                ? const BorderSide(color: AppColors.border)
                : null,
            foregroundColor: AppColors.primary,
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 17),
        ),
      ],
    ),
  );
}
