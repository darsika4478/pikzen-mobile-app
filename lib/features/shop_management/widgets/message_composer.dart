import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
              filled: true,
              fillColor: AppColors.mutedSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              suffixIcon: IconButton(
                onPressed: onAttach,
                tooltip: 'Attach file',
                icon: const Icon(
                  Icons.attach_file_rounded,
                  size: 18,
                  color: AppColors.secondaryText,
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSend,
          tooltip: 'Send message',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface,
            shape: const CircleBorder(),
            fixedSize: const Size(42, 42),
          ),
          icon: const Icon(Icons.send_rounded, size: 18),
        ),
      ],
    ),
  );
}
