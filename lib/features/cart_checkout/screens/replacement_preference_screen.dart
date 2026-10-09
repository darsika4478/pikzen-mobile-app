import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/checkout_provider.dart';
import '../widgets/checkout_ui.dart';

class ReplacementPreferenceScreen extends StatelessWidget {
  const ReplacementPreferenceScreen({
    super.key,
    this.fromPickup = false,
    this.returnToReview = false,
  });
  final bool fromPickup;
  final bool returnToReview;

  void _next(BuildContext context) {
    if (!fromPickup && !returnToReview) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed('checkout');
      }
      return;
    }
    context.goNamed('review-order');
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CheckoutHeader(
        onBack: () =>
            context.canPop() ? context.pop() : context.goNamed('checkout'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                children: [
                  const Text(
                    'If an item is out of stock in your order, let our expert personal shoppers know how to handle it so you never miss a beat.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final option in ReplacementPreference.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PreferenceCard(
                        option: option,
                        selected: checkout.preference == option,
                        onTap: () => context
                            .read<CheckoutProvider>()
                            .setPreference(option),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              child: CheckoutAction(
                label: 'Next',
                onPressed: () => _next(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final ReplacementPreference option;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final title = switch (option) {
      ReplacementPreference.allowReplacement => 'Allow shopper replacements',
      ReplacementPreference.contactMe => 'Contact me',
      ReplacementPreference.noReplacement => 'No replacements',
    };
    final description = switch (option) {
      ReplacementPreference.allowReplacement => "We'll pick the best alternative based on quality, organic status, and your preferences.",
      ReplacementPreference.contactMe => 'Call or message for each item out of stock so you can approve alternatives in real-time.',
      ReplacementPreference.noReplacement => 'Skip the item entirely and issue a prompt refund to your original payment method.',
    };
    final icon = switch (option) {
      ReplacementPreference.allowReplacement => Icons.shopping_basket_outlined,
      ReplacementPreference.contactMe => Icons.chat_outlined,
      ReplacementPreference.noReplacement => Icons.block,
    };
    return Material(
      color: selected ? const Color(0xFFF4F8F4) : const Color(0xFFF4F6F4),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 24,
                color: selected ? AppColors.accent : const Color(0xFF8D9C90),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        height: 1.35,
                      ),
                    ),
                    if (option == ReplacementPreference.allowReplacement) ...[
                      const SizedBox(height: 7),
                      const Text(
                        '✿ Most popular & recommended',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                icon,
                size: 19,
                color: selected ? AppColors.accent : AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
