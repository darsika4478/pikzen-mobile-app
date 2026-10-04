import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../product_discovery/providers/product_provider.dart';
import '../widgets/merchant_profile_view.dart';

/// Customer overview backed by the app's existing account, catalog and orders.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profileDocuments,
    this.ordersForCustomer,
  }) : isShopPartner = false;

  /// Static merchant UI; it does not bind to customer account services.
  const ProfileScreen.shopPartner({super.key})
    : isShopPartner = true,
      profileDocuments = null,
      ordersForCustomer = null;

  final bool isShopPartner;

  /// Optional sources let the connected screen be exercised without Firebase.
  final Stream<Map<String, dynamic>?> Function(String uid)? profileDocuments;
  final Stream<List<OrderModel>> Function(String uid)? ordersForCustomer;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _sourceUid;
  Stream<Map<String, dynamic>?>? _profileStream;
  Stream<List<OrderModel>>? _ordersStream;
  bool _loggingOut = false;

  void _bindSources(String uid) {
    if (_sourceUid == uid && _profileStream != null && _ordersStream != null) {
      return;
    }
    _sourceUid = uid;
    _profileStream =
        widget.profileDocuments?.call(uid) ??
        (Firebase.apps.isEmpty
            ? Stream<Map<String, dynamic>?>.value(null)
            : FirestoreService().database
                  .collection('users')
                  .doc(uid)
                  .snapshots()
                  .map((snapshot) => snapshot.data()));
    _ordersStream =
        widget.ordersForCustomer?.call(uid) ??
        (Firebase.apps.isEmpty
            ? Stream<List<OrderModel>>.value(const [])
            : OrderService().forCustomer(uid));
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileDocuments != widget.profileDocuments ||
        oldWidget.ordersForCustomer != widget.ordersForCustomer) {
      _sourceUid = null;
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign in again whenever you are ready.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await context.read<AuthProvider>().signOut();
      if (mounted) context.goNamed('login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isShopPartner) {
      return const MerchantProfileView();
    }
    final auth = context.watch<AuthProvider>();
    final firebaseUser = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    final uid = Firebase.apps.isEmpty ? auth.user?.id : firebaseUser?.uid;
    final favouriteCount = context.watch<ProductProvider>().favourites.length;
    if (uid != null) _bindSources(uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight:
            56 *
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0),
        leading: const Icon(
          Icons.shopping_basket_outlined,
          color: AppColors.primary,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PIKZEN LOCAL',
              style: TextStyle(fontSize: 10, color: AppColors.primary),
            ),
            Text('Profile', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.pushNamed('notifications'),
            icon: const Icon(Icons.notifications_none),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              AppAssets.logo,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: uid == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sign in to view your profile.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.goNamed('login'),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              )
            : StreamBuilder<Map<String, dynamic>?>(
                stream: _profileStream,
                builder: (context, profileSnapshot) {
                  final fallback = auth.user?.id == uid ? auth.user : null;
                  final data = profileSnapshot.data;
                  final profile = data == null
                      ? fallback
                      : UserModel.fromMap(uid, data);
                  final name = _firstText([
                    profile?.name,
                    fallback?.name,
                    firebaseUser?.displayName,
                  ], 'PikZen customer');
                  final email = _firstText([
                    profile?.email,
                    fallback?.email,
                    firebaseUser?.email,
                  ], 'Email unavailable');
                  final phone = _firstText([
                    profile?.phoneNumber,
                    fallback?.phoneNumber,
                    firebaseUser?.phoneNumber,
                  ], 'Phone not added');
                  final photoUrl = _firstText([
                    _stringField(data, 'profileImageUrl'),
                    _stringField(data, 'photoUrl'),
                    firebaseUser?.photoURL,
                  ], '');
                  return StreamBuilder<List<OrderModel>>(
                    stream: _ordersStream,
                    builder: (context, orderSnapshot) {
                      final orders = orderSnapshot.data ?? const <OrderModel>[];
                      final completed = orders
                          .where(
                            (order) => const {
                              'collected',
                              'completed',
                            }.contains(order.status?.toLowerCase()),
                          )
                          .length;
                      final active = _activeOrder(orders);
                      final location = _firstText([
                        active?.shopName,
                      ], 'No pickup location selected');
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (profileSnapshot.connectionState ==
                                    ConnectionState.waiting)
                                  const LinearProgressIndicator(
                                    color: AppColors.primary,
                                    minHeight: 2,
                                  ),
                                if (profileSnapshot.hasError)
                                  const _Notice(
                                    'Profile details are unavailable right now.',
                                  ),
                                if (orderSnapshot.hasError)
                                  const _Notice(
                                    'Order details are unavailable right now.',
                                  ),
                                if (active != null) ...[
                                  _ActiveOrderCard(order: active),
                                  const SizedBox(height: 18),
                                ],
                                _ProfileIdentity(
                                  name: name,
                                  email: email,
                                  phone: phone,
                                  photoUrl: photoUrl,
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SummaryCard(
                                        icon: Icons.receipt_long_outlined,
                                        value: orderSnapshot.hasData
                                            ? '$completed'
                                            : '—',
                                        label: 'Orders Done',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _SummaryCard(
                                        icon: Icons.favorite_border,
                                        value: '$favouriteCount',
                                        label: 'Favourites',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: _SummaryCard(
                                        icon: Icons.local_offer_outlined,
                                        value: '—',
                                        label: 'Deals Saved',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _PickupLocationCard(
                                  location: location,
                                  hasOrderLocation:
                                      active?.shopName?.trim().isNotEmpty ==
                                      true,
                                ),
                                const SizedBox(height: 22),
                                const _SectionHeading('ACCOUNT & ORDERS'),
                                _MenuGroup(
                                  children: [
                                    _MenuItem(
                                      icon: Icons.person_outline,
                                      title: 'Edit Profile',
                                      subtitle: 'Name and phone',
                                      onTap: () =>
                                          context.pushNamed('edit-profile'),
                                    ),
                                    _MenuItem(
                                      icon: Icons.inventory_2_outlined,
                                      title: 'My Orders',
                                      subtitle: orderSnapshot.hasData
                                          ? '${orders.length} orders'
                                          : 'View your orders',
                                      onTap: () =>
                                          context.pushNamed('my-orders'),
                                    ),
                                    _MenuItem(
                                      icon: Icons.favorite_border,
                                      title: 'Favourites',
                                      subtitle:
                                          '$favouriteCount saved local groceries',
                                      onTap: () =>
                                          context.goNamed('favourites'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                const _SectionHeading('APP & SUPPORT'),
                                _MenuGroup(
                                  children: [
                                    _MenuItem(
                                      icon: Icons.settings_outlined,
                                      title: 'Settings',
                                      onTap: () =>
                                          context.pushNamed('settings'),
                                    ),
                                    _MenuItem(
                                      icon: Icons.help_outline,
                                      title: 'Help & Support',
                                      onTap: () => showDialog<void>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text('Help & Support'),
                                          content: const Text(
                                            'Support contact details are not available yet.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _MenuItem(
                                      icon: Icons.info_outline,
                                      title: 'About PikZen',
                                      onTap: () => showAboutDialog(
                                        context: context,
                                        applicationName: 'PikZen Local',
                                        applicationVersion: '1.0.0',
                                        applicationIcon: const Icon(
                                          Icons.shopping_basket_outlined,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _MenuGroup(
                                  children: [
                                    _MenuItem(
                                      icon: Icons.logout,
                                      title: _loggingOut
                                          ? 'Logging out…'
                                          : 'Logout',
                                      danger: true,
                                      onTap: _loggingOut
                                          ? null
                                          : _confirmLogout,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

String _firstText(Iterable<String?> values, String fallback) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}

String? _stringField(Map<String, dynamic>? data, String key) {
  final value = data?[key];
  return value is String ? value : null;
}

OrderModel? _activeOrder(List<OrderModel> orders) {
  final relevant =
      orders
          .where(
            (order) => const {
              'placed',
              'pending',
              'accepted',
              'confirmed',
              'preparing',
              'ready',
            }.contains(order.status?.toLowerCase()),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  for (final order in relevant) {
    if (order.status?.toLowerCase() == 'ready') return order;
  }
  return relevant.isEmpty ? null : relevant.first;
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final ready = order.status?.toLowerCase() == 'ready';
    final location = _firstText([order.shopName], 'Pickup location pending');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1E6128)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ready ? 'READY FOR PICKUP' : 'ACTIVE ORDER',
            style: const TextStyle(
              color: Color(0xFFDFF5DF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Order ${order.id.startsWith('#') ? order.id : '#${order.id}'}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(location, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => context.pushNamed('order-details', extra: order),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: const Text('View Pass'),
          ),
        ],
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
  });
  final String name;
  final String email;
  final String phone;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final fallback = Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 64,
              height: 64,
              color: AppColors.softGreen,
              child: photoUrl.isEmpty
                  ? fallback
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(email, style: Theme.of(context).textTheme.bodySmall),
                Text(phone, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 5),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _PickupLocationCard extends StatelessWidget {
  const _PickupLocationCard({
    required this.location,
    required this.hasOrderLocation,
  });
  final String location;
  final bool hasOrderLocation;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on_outlined, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRIMARY PICKUP LOCATION',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                hasOrderLocation
                    ? 'From your current order • Hours not available'
                    : 'A pickup hub will appear with your order',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Icon(Icons.near_me_outlined, color: AppColors.primary),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(5, 0, 0, 9),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.secondaryText,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 60),
          children[i],
        ],
      ],
    ),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: Icon(icon, color: danger ? AppColors.error : AppColors.primary),
    title: Text(
      title,
      style: TextStyle(
        color: danger ? AppColors.error : AppColors.primaryText,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: danger
        ? null
        : const Icon(Icons.chevron_right, color: AppColors.secondaryText),
    onTap: onTap,
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.error),
    ),
  );
}
