import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart_checkout/providers/checkout_provider.dart';
import '../models/shop_insights.dart';
import '../widgets/dashboard_surface.dart';

/// Settings for an approved shop: store details, alert switches, password,
/// support and logout.
class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key, this.service});
  final FirestoreService? service;

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  late final FirestoreService _service = widget.service ?? FirestoreService();
  late final Stream<Map<String, dynamic>> _profile = _service
      .approvedShopProfile();
  final Map<String, bool> _pending = {};
  bool _loggingOut = false;

  static const _alerts = {
    'newOrderAlerts': ('New orders', 'When a customer places an order'),
    'customerMessageAlerts': (
      'Customer messages',
      'When a customer is waiting for a reply',
    ),
    'lowStockAlerts': ('Stock warnings', 'When a product runs low or out'),
  };

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggle(String key, bool value) async {
    setState(() => _pending[key] = value);
    try {
      await _service.setShopAlert(key, value);
    } catch (_) {
      if (mounted) _snack('Setting could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _pending.remove(key));
    }
  }

  Future<void> _info(String title, String body) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You can sign in again whenever you are ready.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await context.read<AuthProvider>().signOut();
      if (mounted) context.goNamed('login');
    } catch (_) {
      if (mounted) _snack('Could not log out. Please try again.');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opening = formatShopTime(
      DateTime(2000, 1, 1, PickupAvailability.openingHour),
    );
    final closing = formatShopTime(
      DateTime(2000, 1, 1, PickupAvailability.closingHour),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed('shop-profile'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: StreamBuilder<Map<String, dynamic>>(
              stream: _profile,
              builder: (context, snapshot) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const _Label('STORE'),
                  _Group([
                    _Row(
                      icon: Icons.storefront_outlined,
                      title: 'Store Profile',
                      subtitle: 'Name, phone and address',
                      onTap: () => context.pushNamed('shop-edit-profile'),
                    ),
                    _Row(
                      icon: Icons.schedule_rounded,
                      title: 'Pickup Hours',
                      subtitle: '$opening – $closing daily',
                      onTap: () => _info(
                        'Pickup Hours',
                        'Customers can book pickup slots every 30 minutes '
                            'from $opening to $closing, at least 30 minutes '
                            'after they order, so you have time to prepare.',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const _Label('NOTIFICATIONS'),
                  _Group([
                    for (final entry in _alerts.entries)
                      SwitchListTile(
                        title: Text(
                          entry.value.$1,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(entry.value.$2),
                        value:
                            _pending[entry.key] ??
                            shopAlertEnabled(snapshot.data, entry.key),
                        onChanged:
                            snapshot.hasData && !_pending.containsKey(entry.key)
                            ? (value) => _toggle(entry.key, value)
                            : null,
                      ),
                  ]),
                  const SizedBox(height: 20),
                  const _Label('ACCOUNT & SECURITY'),
                  _Group([
                    _Row(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      subtitle: 'Update your sign-in password',
                      onTap: () => context.pushNamed('change-password'),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const _Label('SUPPORT'),
                  _Group([
                    _Row(
                      icon: Icons.support_agent_rounded,
                      title: 'Help & Support',
                      subtitle: 'Partner desk contact',
                      onTap: () => _info(
                        'Help & Support',
                        'Call the PikZen partner desk on +94 11 234 5678, '
                            '9:00 AM – 6:00 PM, Monday to Saturday.',
                      ),
                    ),
                    _Row(
                      icon: Icons.info_outline_rounded,
                      title: 'About PikZen',
                      subtitle: 'Local groceries, easy pickup',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'PikZen Shop Partner',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rejectRed,
                      side: const BorderSide(color: AppColors.rejectBorder),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(_loggingOut ? 'Logging out…' : 'Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: .6,
        fontWeight: FontWeight.w700,
        color: AppColors.secondaryText,
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group(this.children);
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DashboardSurface(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          children[i],
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.secondaryText,
    ),
  );
}
