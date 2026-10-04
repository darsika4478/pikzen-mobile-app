import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class PreparationNotice extends StatelessWidget {
  const PreparationNotice({super.key, required this.deadline});
  final String deadline;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.noticeBackground,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: AppColors.noticeBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.warning,
          size: 17,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Please prepare the package before '),
                TextSpan(
                  text: deadline,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text: ' to ensure a seamless handoff to the customer.',
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.6,
              color: AppColors.noticeText,
            ),
          ),
        ),
      ],
    ),
  );
}
