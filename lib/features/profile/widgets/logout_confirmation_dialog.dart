import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Returns a local choice only; the caller decides how to display feedback.
class LogoutConfirmationDialog extends StatelessWidget {
  const LogoutConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
    child: Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black26,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      constraints: const BoxConstraints(maxWidth: 456),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: 280,
        child: SingleChildScrollView(
          child: SizedBox(
            height: 280,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 23,
                    backgroundColor: AppColors.rejectBackground,
                    child: Icon(
                      Icons.logout_rounded,
                      size: 23,
                      color: Color(0xFFC91C20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Are you sure you want to logout?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC91C20),
                        foregroundColor: AppColors.surface,
                        elevation: 1,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFDFE9FF),
                        foregroundColor: AppColors.primaryText,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
