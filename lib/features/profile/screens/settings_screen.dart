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
import '../../auth/providers/auth_provider.dart';

typedef SettingsIdentity = ({
  String uid,
  String? email,
  bool passwordProvider,
  bool googleOnly,
});

/// Customer settings backed by the signed-in user and users/{uid}.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.profileLoader,
    this.profileWriter,
    this.ordersForCustomer,
    this.identityForTesting,
  });

  /// Optional sources keep the production route connected and widget tests local.
  final Future<Map<String, dynamic>?> Function(String uid)? profileLoader;
  final Future<void> Function(String uid, Map<String, Object?> changes)?
  profileWriter;
  final Stream<List<OrderModel>> Function(String uid)? ordersForCustomer;
  final SettingsIdentity? identityForTesting;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _uid;
  bool _loading = false;
  bool _loaded = false;
  bool _loadError = false;
  bool _profileMissing = false;
  bool _push = false;
  bool _pushSaving = false;
  bool _resettingPassword = false;
  bool _loggingOut = false;
  Stream<List<OrderModel>>? _orders;

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileLoader != widget.profileLoader ||
        oldWidget.ordersForCustomer != widget.ordersForCustomer) {
      _uid = null;
    }
  }

  SettingsIdentity? _identity(BuildContext context) {
    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final providers = user.providerData
          .map((provider) => provider.providerId)
          .toSet();
      return (
        uid: user.uid,
        email: user.email,
        passwordProvider: providers.contains('password'),
        googleOnly:
            providers.contains('google.com') && !providers.contains('password'),
      );
    }
    if (widget.identityForTesting != null) return widget.identityForTesting;
    final profile = context.read<AuthProvider>().user;
    if (profile == null) return null;
    return (
      uid: profile.id,
      email: profile.email,
      passwordProvider: false,
      googleOnly: false,
    );
  }

  void _load(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _loading = true;
    _loaded = false;
    _loadError = false;
    _profileMissing = false;
    _orders =
        widget.ordersForCustomer?.call(uid) ??
        (Firebase.apps.isEmpty
            ? Stream<List<OrderModel>>.value(const [])
            : OrderService().forCustomer(uid));
    final load =
        widget.profileLoader?.call(uid) ??
        (Firebase.apps.isEmpty
            ? Future<Map<String, dynamic>?>.value(null)
            : FirestoreService().database
                  .collection('users')
                  .doc(uid)
                  .get()
                  .then((document) => document.data()));
    load
        .then((data) {
          if (!mounted || _uid != uid) return;
          setState(() {
            _loading = false;
            _loaded = true;
            _profileMissing = data == null || data['role'] != 'customer';
            final preferences = data?['preferences'];
            _push =
                preferences is Map && preferences['pushNotifications'] == true;
          });
        })
        .catchError((Object _) {
          if (!mounted || _uid != uid) return;
          setState(() {
            _loading = false;
            _loadError = true;
          });
        });
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setPush(bool value) async {
    if (!_loaded || _profileMissing || _pushSaving || _push == value) return;
    final uid = _uid;
    if (uid == null || _identity(context)?.uid != uid) return;
    final previous = _push;
    setState(() {
      _push = value;
      _pushSaving = true;
    });
    try {
      if (Firebase.apps.isNotEmpty &&
          FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('The signed-in account changed.');
      }
      final changes = <String, Object?>{'preferences.pushNotifications': value};
      if (widget.profileWriter != null) {
        await widget.profileWriter!(uid, changes);
      } else {
        await FirestoreService().database
            .collection('users')
            .doc(uid)
            .update(changes);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _push = previous);
        _message('Could not save notification preference. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _pushSaving = false);
    }
  }

  Future<void> _showInformation(String title, String description) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  Future<void> _changePassword(SettingsIdentity identity) async {
    if (_resettingPassword) return;
    if (identity.googleOnly) {
      await _showInformation(
        'Change Password',
        'Password management is handled by your Google account.',
      );
      return;
    }
    if (!identity.passwordProvider || (identity.email ?? '').trim().isEmpty) {
      await _showInformation(
        'Change Password',
        'Password reset is unavailable for this account.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password?'),
        content: Text('Send password reset instructions to ${identity.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _identity(context)?.uid != identity.uid) {
      return;
    }
    setState(() => _resettingPassword = true);
    try {
      final success = await context.read<AuthProvider>().reset(identity.email!);
      if (!mounted) return;
      _message(
        success
            ? 'Password reset instructions have been sent to your email.'
            : 'Could not send reset instructions. Please try again.',
      );
    } catch (_) {
      if (mounted) {
        _message('Could not send reset instructions. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resettingPassword = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
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
      if (mounted) _message('Could not log out. Please try again.');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity(context);
    if (identity != null) _load(identity.uid);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.goNamed('profile'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(AppAssets.logo, width: 32, height: 32),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: identity == null
            ? const Center(child: Text('Sign in to view settings.'))
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : _content(identity),
      ),
    );
  }

  Widget _content(SettingsIdentity identity) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Settings',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Customize your grocery pickup flow',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.search, color: AppColors.secondaryText),
              ],
            ),
            if (_loadError || _profileMissing) ...[
              const SizedBox(height: 14),
              _notice(
                _loadError
                    ? 'Profile preferences could not be loaded.'
                    : 'Your customer profile is unavailable.',
              ),
              if (_loadError)
                TextButton(
                  onPressed: () => setState(() => _uid = null),
                  child: const Text('Retry'),
                ),
            ],
            const SizedBox(height: 18),
            StreamBuilder<List<OrderModel>>(
              stream: _orders,
              builder: (context, snapshot) {
                final relevant = [...?snapshot.data]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                OrderModel? active;
                for (final order in relevant) {
                  if (const {
                        'placed',
                        'pending',
                        'accepted',
                        'confirmed',
                        'preparing',
                        'ready',
                      }.contains(order.status?.toLowerCase()) &&
                      (order.shopName?.trim().isNotEmpty ?? false)) {
                    active = order;
                    break;
                  }
                }
                return _pickupCard(active?.shopName?.trim());
              },
            ),
            const SizedBox(height: 24),
            const _SectionLabel('PREFERENCES'),
            _group([
              _switchRow(),
              _row(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'English',
                onTap: () => _showInformation(
                  'Language',
                  'English is currently supported.',
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const _SectionLabel('ACCOUNT & SECURITY'),
            _group([
              _row(
                icon: Icons.shield_outlined,
                title: 'Privacy & Security',
                subtitle: 'Account and data information',
                onTap: () => _showInformation(
                  'Privacy & Security',
                  'Your account uses Firebase Authentication. '
                      'Profile preferences are saved to your account.',
                ),
              ),
              _row(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: _resettingPassword
                    ? 'Sending reset instructions…'
                    : 'Manage your account password',
                onTap: _resettingPassword
                    ? null
                    : () => _changePassword(identity),
              ),
              _row(
                icon: Icons.phonelink_lock_outlined,
                title: 'Two-Factor Authentication',
                subtitle: 'Not configured',
                badge: 'Coming Soon',
                onTap: null,
              ),
            ]),
            const SizedBox(height: 24),
            const _SectionLabel('SUPPORT & LEGAL'),
            _group([
              _row(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'FAQs and support information',
                onTap: () => _showInformation(
                  'Help & Support',
                  'Support contact details are not available yet.',
                ),
              ),
              _row(
                icon: Icons.info_outline,
                title: 'About PikZen',
                subtitle: 'About this grocery pickup app',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'PikZen',
                  applicationIcon: const Icon(
                    Icons.shopping_basket_outlined,
                    color: AppColors.primary,
                  ),
                  children: const [
                    Text('PikZen helps customers plan grocery pickup.'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const _SectionLabel('SESSION ACTION'),
            _group([
              _row(
                icon: Icons.logout,
                title: _loggingOut ? 'Logging out…' : 'Logout',
                subtitle: 'End current session on this device',
                danger: true,
                onTap: _loggingOut ? null : _logout,
              ),
            ]),
          ],
        ),
      ),
    ),
  );

  Widget _notice(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message),
  );

  Widget _pickupCard(String? location) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primary, Color(0xFF1E6128)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0x33FFFFFF),
          child: Icon(Icons.location_on_outlined, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location == null ? 'PICKUP HUB' : 'ACTIVE PICKUP LOCATION',
                style: const TextStyle(
                  color: Color(0xFFDFF5DF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                location ?? 'No pickup hub selected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                location == null
                    ? 'Choose a pickup location when placing an order.'
                    : 'From your current order',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _group(List<Widget> rows) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: 60, endIndent: 16),
          rows[index],
        ],
      ],
    ),
  );

  Widget _switchRow() => SwitchListTile(
    secondary: const _IconBox(Icons.notifications_outlined),
    title: const Text('Push Notifications'),
    subtitle: Text(
      _pushSaving
          ? 'Saving preference…'
          : 'Order alerts preference; push delivery is not available yet',
    ),
    value: _push,
    activeThumbColor: AppColors.primary,
    onChanged: !_loaded || _profileMissing || _loadError || _pushSaving
        ? null
        : _setPush,
  );

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    String? badge,
    bool danger = false,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: _IconBox(icon, danger: danger),
    title: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: danger ? AppColors.error : AppColors.primaryText,
      ),
    ),
    subtitle: Text(subtitle),
    trailing: badge == null
        ? onTap == null
              ? null
              : const Icon(Icons.chevron_right, color: AppColors.secondaryText)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(badge, style: Theme.of(context).textTheme.labelSmall),
          ),
    onTap: onTap,
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.secondaryText,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon, {this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: danger ? const Color(0xFFFDECEC) : AppColors.softGreen,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(
      icon,
      color: danger ? AppColors.error : AppColors.primary,
      size: 20,
    ),
  );
}
