import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/checkout_provider.dart';
import '../widgets/checkout_ui.dart';

class PickupTimeScreen extends StatelessWidget {
  const PickupTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final date = checkout.pickupDate;
    final now = DateTime.now();
    final slots = date == null
        ? <DateTime>[]
        : PickupAvailability.slotsFor(date, now);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CheckoutHeader(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            CheckoutSubheader(
              title: 'Select Pickup Time',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed('pickup-date'),
              onInfo: () => showPickupInfo(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 10),
                children: [
                  Center(
                    child: Text(
                      date == null
                          ? 'Select a pickup date first'
                          : '${checkoutWeekdays[date.weekday - 1].substring(0, 3)}, ${date.day} ${checkoutMonths[date.month - 1].substring(0, 3)} ${date.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (date == null)
                    Center(
                      child: TextButton(
                        onPressed: () => context.goNamed('pickup-date'),
                        child: const Text('Select pickup date'),
                      ),
                    ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 49,
                        ),
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      final active = checkout.pickupTime == slot;
                      return OutlinedButton(
                        onPressed: () => context
                            .read<CheckoutProvider>()
                            .setPickupTime(slot),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: active
                              ? AppColors.accent
                              : Colors.white,
                          foregroundColor: active
                              ? Colors.white
                              : AppColors.primaryText,
                          side: BorderSide(
                            color: active ? AppColors.accent : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: Text(
                          pickupTimeLabel(slot),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                  if (date != null && slots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 18),
                      child: Text(
                        'No pickup times remain for this day. Choose another date.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              child: CheckoutAction(
                label: 'Next',
                onPressed:
                    checkout.pickupTime == null ||
                        !slots.contains(checkout.pickupTime)
                    ? null
                    : () => context.pushNamed(
                        'replacement-preference',
                        queryParameters: const {'fromPickup': 'true'},
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
