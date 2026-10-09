import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ProductsHeader extends StatelessWidget {
  const ProductsHeader({super.key, required this.onBack, required this.onAdd});
  final VoidCallback onBack;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
              fixedSize: const Size(42, 42),
            ),
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
          ),
        ),
        const Expanded(
          child: Text(
            'Products',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: onAdd,
          tooltip: 'Add Product',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface,
            shape: const CircleBorder(),
            fixedSize: const Size(42, 42),
          ),
          icon: const Icon(Icons.add_rounded, size: 24),
        ),
      ],
    ),
  );
}
