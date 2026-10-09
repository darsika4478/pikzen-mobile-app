import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_users_provider.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key, this.service});
  final FirestoreService? service;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AdminUsersProvider(service: service),
    child: const _UsersView(),
  );
}

class _UsersView extends StatefulWidget {
  const _UsersView();
  @override
  State<_UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<_UsersView> {
  static const _pageSize = 5;
  static const _tabs = [
    ('All', 'All'),
    ('Customers', 'Customers'),
    ('Shop Owners', 'Shop Users'),
    ('Pending Shops', 'Pending Shops'),
    ('Admins', 'Admins'),
  ];

  String _filter = 'All';
  String _query = '';
  int _page = 0;
  bool _loggingOut = false;
  final Set<String> _expanded = {};

  static String roleLabel(String role) => switch (role) {
    'shop' => 'Shop User',
    'admin' => 'Admin',
    'customer' => 'Customer',
    _ => 'Unknown',
  };

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: AppColors.rejectRed)
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _review(UserModel user, String decision) async {
    final approve = decision == 'approved';
    final ok = await _confirm(
      title: approve ? 'Approve Shop Owner?' : 'Reject Shop Owner?',
      message: approve
          ? 'Are you sure you want to approve this Shop Owner?'
          : 'Are you sure you want to reject this Shop Owner?',
      action: approve ? 'Approve' : 'Reject',
      destructive: !approve,
    );
    if (!mounted || !ok) return;
    final result = await context.read<AdminUsersProvider>().review(
      user,
      decision,
    );
    if (mounted && result) {
      _snack(
        approve ? 'Shop Owner approved successfully.' : 'Shop Owner rejected.',
      );
    }
  }

  Future<void> _toggleSuspend(UserModel user) async {
    final suspend = !user.isSuspended;
    final ok = await _confirm(
      title: suspend ? 'Suspend ${user.name}?' : 'Reactivate ${user.name}?',
      message: suspend
          ? 'They will be signed out at their next sign-in attempt and cannot '
                'place orders${user.role == 'shop' ? ' or manage their shop' : ''} '
                'until reactivated.'
          : 'They will be able to sign in and use PikZen again.',
      action: suspend ? 'Suspend' : 'Reactivate',
      destructive: suspend,
    );
    if (!mounted || !ok) return;
    final result = await context.read<AdminUsersProvider>().setSuspended(
      user,
      suspend,
    );
    if (mounted && result) {
      _snack(suspend ? '${user.name} suspended.' : '${user.name} reactivated.');
    }
  }

  Future<void> _changeRole(UserModel user) async {
    var role = user.role;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Change role for ${user.name}'),
          content: RadioGroup<String>(
            groupValue: role,
            onChanged: (value) => setDialogState(() => role = value!),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(
                  value: 'customer',
                  title: Text('Customer'),
                  subtitle: Text('Orders groceries for pickup'),
                ),
                RadioListTile(
                  value: 'shop',
                  title: Text('Shop User'),
                  subtitle: Text('Approved to sell; opens the shop dashboard'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, role),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || chosen == null || chosen == user.role) return;
    final result = await context.read<AdminUsersProvider>().changeRole(
      user,
      chosen,
    );
    if (mounted && result) {
      _snack('${user.name} is now a ${roleLabel(chosen)}.');
    }
  }

  void _details(UserModel user) {
    final rows = <(String, String)>[
      ('Email', user.email.isEmpty ? 'Not supplied' : user.email),
      (
        'Phone',
        (user.phoneNumber ?? '').isEmpty ? 'Not supplied' : user.phoneNumber!,
      ),
      ('Role', roleLabel(user.role)),
      ('Status', user.isSuspended ? 'Suspended' : 'Active'),
      if (user.role == 'shop')
        (
          'Approval',
          switch (user.approvalStatus) {
            'approved' => 'Approved',
            'rejected' => 'Rejected',
            'pending' => 'Pending review',
            _ => 'Pending (migration required)',
          },
        ),
      if ((user.shopName ?? '').isNotEmpty) ('Shop', user.shopName!),
      if (user.createdAt != null)
        (
          'Joined',
          MaterialLocalizations.of(context).formatMediumDate(user.createdAt!),
        ),
      ('User ID', user.id),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(user, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.name.isEmpty ? 'User Details' : user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _filters(AdminUsersProvider data) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => ChangeNotifierProvider.value(
      value: data,
      child: Consumer<AdminUsersProvider>(
        builder: (context, data, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (value, label) in const [
                      (AdminStatusFilter.all, 'All'),
                      (AdminStatusFilter.active, 'Active'),
                      (AdminStatusFilter.suspended, 'Suspended'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: data.statusFilter == value,
                        onSelected: (_) {
                          data.setStatusFilter(value);
                          setState(() => _page = 0);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Sort by',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (value, label) in const [
                      (AdminSort.name, 'Name A–Z'),
                      (AdminSort.newest, 'Newest first'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: data.sort == value,
                        onSelected: (_) => data.setSort(value),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await context.read<AuthProvider>().signOut();
      if (mounted) context.goNamed('login');
    } catch (_) {
      if (mounted) _snack('Sign out failed. Please retry.');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AdminUsersProvider>();
    final visible = data.matching(_filter, _query);
    final pages = (visible.length / _pageSize).ceil().clamp(1, 1 << 20);
    final page = _page.clamp(0, pages - 1);
    final shown = visible.skip(page * _pageSize).take(_pageSize).toList();
    final total = data.users.length;
    String percent(int value) =>
        total == 0 ? '0%' : '${(value * 100 / total).round()}%';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            // Pages hold at most five cards, so build everything eagerly.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(loggingOut: _loggingOut, onLogout: _logout),
                  const SizedBox(height: 18),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total Users',
                            value: '$total',
                            caption: 'All',
                            icon: Icons.groups_outlined,
                            tone: _Tone.neutral,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Active',
                            value: '${data.activeCount}',
                            caption: percent(data.activeCount),
                            icon: Icons.verified_rounded,
                            tone: _Tone.good,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Suspended',
                            value: '${data.suspendedCount}',
                            caption: percent(data.suspendedCount),
                            icon: Icons.block_rounded,
                            tone: _Tone.bad,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() {
                            _query = value;
                            _page = 0;
                          }),
                          decoration: InputDecoration(
                            hintText: 'Search users by name, email...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Badge(
                        isLabelVisible:
                            data.statusFilter != AdminStatusFilter.all,
                        smallSize: 9,
                        backgroundColor: AppColors.accent,
                        child: IconButton.outlined(
                          tooltip: 'Filter & sort',
                          onPressed: () => _filters(data),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                            fixedSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.filter_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Eager horizontal row: few tabs, and every chip stays
                  // tappable at any text size.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (key, label) in _tabs) ...[
                          if (key != _tabs.first.$1) const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('$label (${data.count(key)})'),
                            selected: _filter == key,
                            showCheckmark: false,
                            selectedColor: AppColors.darkGreen,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: _filter == key
                                  ? AppColors.darkGreen
                                  : AppColors.border,
                            ),
                            labelStyle: TextStyle(
                              color: _filter == key
                                  ? Colors.white
                                  : AppColors.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: const StadiumBorder(),
                            onSelected: (_) => setState(() {
                              _filter = key;
                              _page = 0;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (data.loading) const LinearProgressIndicator(),
                  if (data.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        data.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  if (!data.loading && visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No matching users.')),
                    ),
                  for (final user in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UserCard(
                        user: user,
                        busy: data.busy.contains(user.id),
                        expanded: _expanded.contains(user.id),
                        onToggle: () => setState(
                          () => _expanded.contains(user.id)
                              ? _expanded.remove(user.id)
                              : _expanded.add(user.id),
                        ),
                        onDetails: () => _details(user),
                        onRole: () => _changeRole(user),
                        onSuspend: () => _toggleSuspend(user),
                        onApprove: () => _review(user, 'approved'),
                        onReject: () => _review(user, 'rejected'),
                      ),
                    ),
                  if (visible.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Showing ${shown.length} of ${visible.length} accounts',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        _PagerButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Previous page',
                          onPressed: page == 0
                              ? null
                              : () => setState(() => _page = page - 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${page + 1}${pages > 1 ? ' / $pages' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _PagerButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Next page',
                          onPressed: page >= pages - 1
                              ? null
                              : () => setState(() => _page = page + 1),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _SessionBar(
        syncing: data.loading,
        onSync: () {
          data.refresh();
          _snack('Directory synced.');
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.loggingOut, required this.onLogout});
  final bool loggingOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.softGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.layers_outlined, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'User Management',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                _Badge(
                  text: 'ADMIN',
                  color: AppColors.primary,
                  background: AppColors.softGreen,
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              'PikZen System Directory',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
      IconButton.outlined(
        tooltip: 'Logout',
        onPressed: loggingOut ? null : onLogout,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
      ),
    ],
  );
}

enum _Tone { neutral, good, bad }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tone,
  });
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (background, border, accent) = switch (tone) {
      _Tone.neutral => (Colors.white, AppColors.border, AppColors.primaryText),
      _Tone.good => (
        AppColors.softGreen,
        AppColors.primary.withValues(alpha: .25),
        AppColors.darkGreen,
      ),
      _Tone.bad => (
        AppColors.rejectBackground,
        AppColors.rejectBorder,
        AppColors.rejectRed,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tone == _Tone.neutral
                        ? AppColors.secondaryText
                        : accent,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                TextSpan(
                  text: '  $caption',
                  style: TextStyle(
                    fontSize: 11,
                    color: accent.withValues(alpha: .8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.background,
  });
  final String text;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.user, {this.radius = 22});
  final UserModel user;
  final double radius;

  static const _palette = [
    (Color(0xFFE8F5E9), Color(0xFF2E7D32)),
    (Color(0xFFE0F7F4), Color(0xFF00796B)),
    (Color(0xFFFFF4DC), Color(0xFFB7791F)),
    (Color(0xFFFDECEC), Color(0xFFC62828)),
    (Color(0xFFE8F0FE), Color(0xFF1A56DB)),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final (background, foreground) = user.isSuspended
        ? _palette[3]
        : _palette[user.id.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: radius * .62,
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busy,
    required this.expanded,
    required this.onToggle,
    required this.onDetails,
    required this.onRole,
    required this.onSuspend,
    required this.onApprove,
    required this.onReject,
  });
  final UserModel user;
  final bool busy;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDetails;
  final VoidCallback onRole;
  final VoidCallback onSuspend;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pendingShop = user.role == 'shop' && user.approvalStatus == 'pending';
    final (roleColor, roleBackground) = switch (user.role) {
      'admin' => (const Color(0xFF7E3AF2), const Color(0xFFF3EDFF)),
      'shop' => (AppColors.info, const Color(0xFFE8F0FE)),
      _ => (AppColors.secondaryText, AppColors.mutedSurface),
    };
    final detail = switch (user.role) {
      'shop' when (user.shopName ?? '').trim().isNotEmpty => user.shopName!,
      'shop' => pendingShop ? 'Awaiting approval' : 'Shop partner',
      _ => (user.phoneNumber ?? '').isNotEmpty ? user.phoneNumber! : null,
    };
    final (statusText, statusColor, statusBackground) = user.isSuspended
        ? ('Suspended', AppColors.rejectRed, AppColors.rejectBackground)
        : pendingShop
        ? ('Pending', AppColors.warning, AppColors.lightOrange)
        : user.role == 'shop' && user.approvalStatus == 'rejected'
        ? ('Rejected', AppColors.rejectRed, AppColors.rejectBackground)
        : ('Active', AppColors.primary, AppColors.softGreen);
    final canManage = user.role != 'admin';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: user.isSuspended ? const Color(0xFFFFFBFB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.isSuspended
              ? AppColors.rejectBorder
              : expanded
              ? AppColors.primary.withValues(alpha: .45)
              : AppColors.border,
          width: expanded ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          user.name.isEmpty ? 'Unnamed user' : user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        _Badge(
                          text: _UsersViewState.roleLabel(user.role),
                          color: roleColor,
                          background: roleBackground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [user.email, ?detail].join(' • '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: .3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More actions for ${user.name}',
                onPressed: onToggle,
                icon: Icon(
                  expanded ? Icons.close_rounded : Icons.more_vert_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
          if (pendingShop) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onApprove,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rejectRed,
                        side: const BorderSide(color: AppColors.rejectBorder),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (expanded) ...[
            const Divider(height: 22),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.visibility_outlined,
                      label: 'Details',
                      onPressed: onDetails,
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Role',
                        color: AppColors.primary,
                        background: AppColors.softGreen,
                        onPressed: busy ? null : onRole,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: user.isSuspended
                          ? _ActionButton(
                              icon: Icons.lock_open_rounded,
                              label: 'Activate',
                              color: AppColors.primary,
                              background: AppColors.softGreen,
                              onPressed: busy ? null : onSuspend,
                            )
                          : _ActionButton(
                              icon: Icons.block_rounded,
                              label: 'Suspend',
                              color: AppColors.rejectRed,
                              background: AppColors.rejectBackground,
                              onPressed: busy ? null : onSuspend,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primaryText,
    this.background = Colors.white,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      backgroundColor: background,
      side: BorderSide(color: color.withValues(alpha: .25)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    icon: Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
    ),
    icon: Icon(icon, size: 18),
  );
}

class _SessionBar extends StatelessWidget {
  const _SessionBar({required this.syncing, required this.onSync});
  final bool syncing;
  final VoidCallback onSync;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 9, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Session: Admin Active',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            onPressed: syncing ? null : onSync,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Sync'),
          ),
        ],
      ),
    ),
  );
}
