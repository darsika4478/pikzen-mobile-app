import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/checkout_provider.dart';
import '../widgets/checkout_ui.dart';

class PickupDateScreen extends StatefulWidget {
  const PickupDateScreen({super.key});
  @override
  State<PickupDateScreen> createState() => _PickupDateScreenState();
}

class _PickupDateScreenState extends State<PickupDateScreen> {
  late DateTime month;
  @override
  void initState() {
    super.initState();
    final saved = context.read<CheckoutProvider>().pickupDate;
    final now = DateTime.now();
    final initial =
        saved != null && !saved.isBefore(DateTime(now.year, now.month, now.day))
        ? saved
        : now;
    month = DateTime(initial.year, initial.month);
  }

  void _select(DateTime day) {
    context.read<CheckoutProvider>().setPickupDate(day);
    setState(() => month = DateTime(day.year, day.month));
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final selected = checkout.pickupDate;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final first = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final quick = <DateTime>[];
    for (var offset = 0; offset < 10 && quick.length < 3; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (PickupAvailability.slotsFor(day, now).isNotEmpty) quick.add(day);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CheckoutHeader(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            CheckoutSubheader(
              title: 'Select Pickup Date',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed('checkout'),
              onInfo: () => showPickupInfo(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${checkoutMonths[month.month - 1]} ${month.year}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'Fresh Season',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.chevron_left),
                              tooltip: 'Previous month',
                              onPressed: month.isAfter(currentMonth)
                                  ? () => setState(
                                      () => month = DateTime(
                                        month.year,
                                        month.month - 1,
                                      ),
                                    )
                                  : null,
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.chevron_right),
                              tooltip: 'Next month',
                              onPressed: () => setState(
                                () => month = DateTime(
                                  month.year,
                                  month.month + 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                              .map(
                                (day) => Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 5),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 4,
                                childAspectRatio: 1.12,
                              ),
                          itemCount: ((leading + count + 6) ~/ 7) * 7,
                          itemBuilder: (context, index) {
                            final number = index - leading + 1;
                            if (number < 1 || number > count) {
                              return const SizedBox.shrink();
                            }
                            final day = DateTime(
                              month.year,
                              month.month,
                              number,
                            );
                            final valid = PickupAvailability.slotsFor(
                              day,
                              now,
                            ).isNotEmpty;
                            final active = day == selected;
                            return InkWell(
                              onTap: valid ? () => _select(day) : null,
                              borderRadius: BorderRadius.circular(30),
                              child: Center(
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active
                                        ? AppColors.accent
                                        : Colors.transparent,
                                  ),
                                  child: Text(
                                    '$number',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: active
                                          ? Colors.white
                                          : valid
                                          ? AppColors.primaryText
                                          : AppColors.border,
                                      fontWeight: active
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quick Selection',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () =>
                            context.read<CheckoutProvider>().resetPickup(),
                        child: const Text(
                          'Reset pickup',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: quick.map((day) {
                        final active = selected == day;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '${day == DateTime(now.year, now.month, now.day) ? '⚡ ' : ''}${shortDate(day)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: active,
                            onSelected: (_) => _select(day),
                            selectedColor: AppColors.accent,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: active
                                  ? Colors.white
                                  : AppColors.primaryText,
                            ),
                            side: BorderSide.none,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 17,
                              backgroundColor: Color(0xFF9AF29C),
                              child: Icon(
                                Icons.event_available,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SELECTED PICKUP DAY',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.secondaryText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    selected == null
                                        ? 'Select a pickup day'
                                        : fullDate(selected),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            '◷  Slots available from 9:00 AM – 8:00 PM',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 3),
              child: CheckoutAction(
                label: 'Next',
                onPressed:
                    selected == null ||
                        PickupAvailability.slotsFor(selected, now).isEmpty
                    ? null
                    : () => context.pushNamed('pickup-time'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 7),
              child: Text(
                '♧  Free rescheduling up to 1 hour before slot',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
