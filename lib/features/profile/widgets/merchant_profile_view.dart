import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../shop_management/widgets/dashboard_bottom_nav.dart';
import 'logout_confirmation_dialog.dart';

/// Presentation for ProfileScreen's local shop partner mode.
class MerchantProfileView extends StatelessWidget {
  const MerchantProfileView({super.key});

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) => const LogoutConfirmationDialog(),
    );
    if (confirmed == true && context.mounted) {
      _message(context, 'Logout selected');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    _headerButton(Icons.chevron_left_rounded, 'Back', () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.goNamed('shop-dashboard');
                      }
                    }),
                    const Expanded(
                      child: Text(
                        'Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _headerButton(
                      Icons.settings_outlined,
                      'Profile settings',
                      () => _message(context, 'Settings'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 22).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MerchantIdentitySection(
                              onEdit: () =>
                                  context.pushNamed('shop-edit-profile'),
                            ),
                            const SizedBox(height: 24),
                            ProfileMenuCard(
                              children: [
                                MerchantProfileMenuRow(
                                  icon: Icons.shopping_bag_outlined,
                                  label: 'My Orders',
                                  color: AppColors.primary,
                                  tint: AppColors.softGreen,
                                  trailing: const _ProfilePill('12 New'),
                                  onTap: () =>
                                      context.pushNamed('incoming-orders'),
                                ),
                                MerchantProfileMenuRow(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'My Products',
                                  color: AppColors.primary,
                                  tint: AppColors.softGreen,
                                  trailing: const Text(
                                    '28 Items',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  onTap: () =>
                                      context.pushNamed('product-management'),
                                ),
                                MerchantProfileMenuRow(
                                  icon: Icons.lock_outline_rounded,
                                  label: 'Change Password',
                                  onTap: () =>
                                      _message(context, 'Change Password'),
                                ),
                                MerchantProfileMenuRow(
                                  icon: Icons.notifications_none_rounded,
                                  label: 'Notifications',
                                  color: AppColors.warning,
                                  tint: AppColors.lightOrange,
                                  trailing: const Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: AppColors.warning,
                                  ),
                                  onTap: () =>
                                      _message(context, 'Notifications'),
                                ),
                                MerchantProfileMenuRow(
                                  icon: Icons.tune_rounded,
                                  label: 'Settings',
                                  onTap: () => _message(context, 'Settings'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            const Spacer(),
                            SizedBox(
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: () => _logout(context),
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppColors.rejectBackground,
                                  foregroundColor: AppColors.rejectRed,
                                  side: const BorderSide(
                                    color: AppColors.rejectBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: DashboardBottomNav(
      selectedIndex: 3,
      onSelected: (index) {
        switch (index) {
          case 0:
            context.goNamed('shop-dashboard');
          case 1:
            context.pushNamed('incoming-orders');
          case 2:
            context.pushNamed('product-management');
          case 3:
            break;
        }
      },
    ),
  );

  Widget _headerButton(IconData icon, String tooltip, VoidCallback onTap) =>
      Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.secondaryText,
            side: const BorderSide(color: AppColors.border),
            shape: const CircleBorder(),
            fixedSize: const Size(40, 40),
            minimumSize: const Size(40, 40),
          ),
          icon: Icon(icon, size: 21),
        ),
      );
}

class MerchantIdentitySection extends StatelessWidget {
  const MerchantIdentitySection({super.key, required this.onEdit});
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 82,
        height: 82,
        child: Stack(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.primary, width: 1.7),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: IconButton(
                  tooltip: 'Edit merchant profile',
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'GreenMart',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      const _ProfilePill('Verified Merchant • ID: #GM8821', dot: true),
    ],
  );
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill(this.label, {this.dot = false});
  final String label;
  final bool dot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          const Icon(Icons.circle, size: 5, color: AppColors.primary),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 12,
                endIndent: 12,
                color: AppColors.border,
              ),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class MerchantProfileMenuRow extends StatelessWidget {
  const MerchantProfileMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.color = AppColors.secondaryText,
    this.tint = AppColors.mutedSurface,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color color, tint;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 7)],
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.secondaryText,
          ),
        ],
      ),
    ),
  );
}
