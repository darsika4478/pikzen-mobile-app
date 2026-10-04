import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';
import '../widgets/checkout_ui.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final checkout = context.watch<CheckoutProvider>();
    final date = checkout.pickupDate;
    final time = checkout.pickupTime;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CheckoutHeader(title: 'Checkout'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _panel(),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => context.pushNamed('pickup-date'),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      date == null
                                          ? 'Select pickup date and time'
                                          : '${shortDate(date)}${time == null ? '' : ', ${pickupTimeLabel(time)} - ${pickupTimeLabel(time.add(const Duration(minutes: PickupAvailability.slotMinutes)))}'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      time == null
                                          ? 'Choose an available pickup slot'
                                          : 'Pickup slot selected',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 19),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: _panel(),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () =>
                              context.pushNamed('replacement-preference'),
                          child: const Row(
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: AppColors.softGreen,
                                child: Icon(
                                  Icons.autorenew,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Replacement Preference',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'If an item is out of stock',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final option in ReplacementPreference.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(9),
                                onTap: () => context
                                    .read<CheckoutProvider>()
                                    .setPreference(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 11,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        checkout.preference == option
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 17,
                                        color: checkout.preference == option
                                            ? AppColors.primary
                                            : AppColors.secondaryText,
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _optionTitle(option),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              _optionSubtitle(option),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (checkout.preference == option)
                                        const Icon(
                                          Icons.check_circle_outline,
                                          color: AppColors.primary,
                                          size: 19,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(19),
                    decoration: _panel(),
                    child: Column(
                      children: [
                        _sumRow(
                          'Subtotal (${cart.count} items)',
                          rupees(cart.totalMinor),
                        ),
                        const SizedBox(height: 9),
                        _sumRow('Pickup Fee', 'FREE', green: true),
                        const SizedBox(height: 9),
                        _sumRow('Service Fee', rupees(0)),
                        const Divider(height: 22),
                        _sumRow('Total', rupees(cart.totalMinor), bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              child: CheckoutAction(
                label: 'Continue',
                onPressed: cart.items.isEmpty
                    ? null
                    : () => context.pushNamed('pickup-date'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _optionTitle(ReplacementPreference value) => switch (value) {
  ReplacementPreference.allowReplacement => 'Allow shopper replacements',
  ReplacementPreference.contactMe => 'Contact me',
  ReplacementPreference.noReplacement => 'No replacements',
};
String _optionSubtitle(ReplacementPreference value) => switch (value) {
  ReplacementPreference.allowReplacement => "We'll pick the best alternative",
  ReplacementPreference.contactMe => 'Call or message for each item',
  ReplacementPreference.noReplacement => 'Refund if item is unavailable',
};
BoxDecoration _panel() => BoxDecoration(
  color: const Color(0xFFF3F6F3),
  borderRadius: BorderRadius.circular(14),
);
Widget _sumRow(
  String title,
  String value, {
  bool green = false,
  bool bold = false,
}) => Row(
  children: [
    Expanded(
      child: Text(
        title,
        style: TextStyle(
          fontSize: bold ? 15 : 12,
          fontWeight: bold ? FontWeight.bold : null,
        ),
      ),
    ),
    Text(
      value,
      style: TextStyle(
        fontSize: bold ? 15 : 12,
        fontWeight: bold ? FontWeight.bold : null,
        color: green ? AppColors.primary : AppColors.primaryText,
      ),
    ),
  ],
);
