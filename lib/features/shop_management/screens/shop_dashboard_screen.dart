import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/today_summary_card.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/operational_checklist.dart';
import '../widgets/dashboard_bottom_nav.dart';

/// Static shop partner dashboard with local preview interactions.
class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});
  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  int _selectedIndex = 0;

  void _preview(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardHeader(
                    onNotifications: () =>
                        _preview('No new notifications in this preview.'),
                    onShop: () => _preview('GreenMart is online and open.'),
                  ),
                  const SizedBox(height: 22),
                  TodaySummaryCard(
                    onViewAll: () => context.pushNamed('incoming-orders'),
                  ),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DashboardActionCard(
                            icon: Icons.warning_amber_rounded,
                            title: 'Low Stock',
                            subtitle: '3 items require attention',
                            buttonLabel: 'Reorder Now',
                            isWarning: true,
                            onPressed: () =>
                                _preview('3 low-stock items in this preview.'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DashboardActionCard(
                            icon: Icons.bar_chart_rounded,
                            title: 'Reports',
                            subtitle: 'Sales & performance',
                            buttonLabel: 'View Stats',
                            onPressed: () =>
                                _preview('Sales & performance preview.'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const OperationalChecklist(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          if (index == 3) {
            context.pushNamed('shop-profile');
            return;
          }
          if (index == 2) {
            context.pushNamed('product-management');
            return;
          }
          if (index == 1) {
            context.pushNamed('incoming-orders');
            return;
          }
          setState(() => _selectedIndex = index);
          if (index != 0) {
            _preview(
              '${DashboardBottomNav.labels[index]} selected — UI preview only.',
            );
          }
        },
      ),
    );
  }
}
