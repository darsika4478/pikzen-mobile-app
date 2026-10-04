import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ReplacementSelector extends StatelessWidget {
  const ReplacementSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final String selected;
  final ValueChanged<String> onChanged;
  static const options = [
    'Almond Milk (Rs 7.50)',
    'Soy Milk (Rs 7.20)',
    'Oat Milk (Rs 8.00)',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(
        children: [
          Expanded(
            child: Text(
              'SUGGEST REPLACEMENT',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: .3,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          SizedBox(width: 5),
          Text(
            'For Fresh Milk',
            style: TextStyle(fontSize: 9, color: AppColors.secondaryText),
          ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: AppColors.secondaryText,
        ),
        style: const TextStyle(fontSize: 12, color: AppColors.primaryText),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
      const SizedBox(height: 10),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, size: 13, color: AppColors.warning),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Customer will be notified to accept or decline substitutions.',
              style: TextStyle(
                fontSize: 9,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
