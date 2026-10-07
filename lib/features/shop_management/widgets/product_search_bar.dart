import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ProductSearchBar extends StatelessWidget {
  const ProductSearchBar({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    style: const TextStyle(fontSize: 12),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search products...',
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      prefixIcon: const Icon(
        Icons.search_rounded,
        size: 19,
        color: AppColors.secondaryText,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 40),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    ),
  );
}
