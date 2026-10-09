import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/chat_message.dart';

class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'TODAY 10:15 AM',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
          color: AppColors.secondaryText,
        ),
      ),
    ),
  );
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.initials,
  });
  final ChatMessage message;
  final String initials;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bubble = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * .76),
        child: Column(
          crossAxisAlignment: message.isMerchant
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: message.isMerchant
                    ? AppColors.softGreen
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: message.isMerchant
                      ? AppColors.softGreen
                      : AppColors.border,
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (message.isMerchant && message.isRead) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: message.isMerchant
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isMerchant) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.milkBackground,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(child: bubble),
          ],
        ),
      );
    },
  );
}
