import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';

const checkoutMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const checkoutWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String shortDate(DateTime day) =>
    '${checkoutWeekdays[day.weekday - 1].substring(0, 3)}, ${checkoutMonths[day.month - 1].substring(0, 3)} ${day.day}';
String fullDate(DateTime day) =>
    '${checkoutWeekdays[day.weekday - 1]}, ${checkoutMonths[day.month - 1].substring(0, 3)} ${day.day}, ${day.year}';
String pickupTimeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
}

String rupees(int minor) {
  final whole = (minor ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'Rs. $whole.${(minor.abs() % 100).toString().padLeft(2, '0')}';
}

class CheckoutHeader extends StatelessWidget implements PreferredSizeWidget {
  const CheckoutHeader({super.key, this.title = 'Cart'});
  final String title;
  @override
  Size get preferredSize => const Size.fromHeight(48);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(
      title,
      style: const TextStyle(
        fontFamily: 'serif',
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    automaticallyImplyLeading: false,
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Image.asset(AppAssets.logo, width: 27, height: 27),
      ),
    ],
  );
}

class CheckoutSubheader extends StatelessWidget {
  const CheckoutSubheader({
    super.key,
    required this.title,
    required this.onBack,
    required this.onInfo,
  });
  final String title;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, size: 21),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        IconButton(
          onPressed: onInfo,
          tooltip: 'Pickup information',
          icon: const Icon(Icons.info_outline, size: 20),
        ),
      ],
    ),
  );
}

void showPickupInfo(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Pickup information'),
    content: const Text(
      'Choose an available date and time. Free rescheduling is available up to 1 hour before your selected slot.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ],
  ),
);

class CheckoutAction extends StatelessWidget {
  const CheckoutAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 49,
    child: FilledButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: Icon(secondary ? Icons.arrow_back : Icons.arrow_forward, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: secondary
            ? const Color(0xFF9AF29C)
            : const Color(0xFF075F1A),
        foregroundColor: secondary ? AppColors.primary : Colors.white,
        disabledBackgroundColor: AppColors.border,
        shape: const StadiumBorder(),
        elevation: secondary ? 0 : 3,
      ),
    ),
  );
}
