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
  String _filter = 'All';
  String _query = '';
  bool _loggingOut = false;
  String label(String role) => switch (role) {
    'shop' => 'Shop Owner',
    'admin' => 'Admin',
    'customer' => 'Customer',
    _ => 'Unknown',
  };
  Future<void> review(UserModel user, String decision) async {
    final approve = decision == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Approve Shop Owner?' : 'Reject Shop Owner?'),
        content: Text(
          approve
              ? 'Are you sure you want to approve this Shop Owner?'
              : 'Are you sure you want to reject this Shop Owner?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final result = await context.read<AdminUsersProvider>().review(
      user,
      decision,
    );
    if (!mounted || !result) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approve
              ? 'Shop Owner approved successfully.'
              : 'Shop Owner rejected.',
        ),
      ),
    );
  }

  void details(UserModel user) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(user.name.isEmpty ? 'User Details' : user.name),
      content: SingleChildScrollView(
        child: Text(
          'Email: ${user.email}\nPhone: ${user.phoneNumber ?? 'Not supplied'}\nRole: ${label(user.role)}\nUID: ${user.id}${user.role == 'shop' ? '\nApproval: ${user.approvalStatus ?? 'Pending (migration required)'}' : ''}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AdminUsersProvider>();
    final visible = data.matching(_filter, _query);
    final tracked = data.users.any((u) => u.accountStatus != null);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        toolbarHeight:
            64 *
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0),
        automaticallyImplyLeading: false,
        leading: const Icon(Icons.layers_outlined, color: AppColors.primary),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'PikZen System Directory • ADMIN',
              style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _loggingOut
                ? null
                : () async {
                    setState(() => _loggingOut = true);
                    try {
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) context.goNamed('login');
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sign out failed. Please retry.'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _loggingOut = false);
                    }
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in {
                        'Total Users': '${data.users.length}',
                        'Active': tracked
                            ? '${data.users.where((u) => u.accountStatus == 'active').length}'
                            : 'Not tracked',
                        'Suspended': tracked
                            ? '${data.users.where((u) => u.accountStatus == 'suspended').length}'
                            : 'Not tracked',
                        'Pending Shops':
                            '${data.matching('Pending Shops', '').length}',
                      }.entries)
                        SizedBox(
                          width: width,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search users by name, email...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in [
                    'All',
                    'Customers',
                    'Shop Owners',
                    'Pending Shops',
                  ])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
                  child: Text('No matching users.'),
                ),
              for (final user in visible)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.softGreen,
                              child: Text(
                                user.name.trim().isEmpty
                                    ? '?'
                                    : user.name
                                          .trim()
                                          .substring(0, 1)
                                          .toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    user.email,
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Text(
                                        label(user.role),
                                        style: const TextStyle(
                                          color: AppColors.info,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (user.role == 'shop')
                                        Text(
                                          switch (user.approvalStatus) {
                                            'approved' => 'Approved',
                                            'rejected' => 'Rejected',
                                            'pending' => 'Pending',
                                            _ => 'Pending • migration required',
                                          },
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                user.approvalStatus ==
                                                    'approved'
                                                ? AppColors.primary
                                                : user.approvalStatus ==
                                                      'rejected'
                                                ? AppColors.error
                                                : AppColors.warning,
                                          ),
                                        ),
                                      if (user.accountStatus != null)
                                        Text(
                                          user.accountStatus!,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => details(user),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: const Text('Details'),
                            ),
                            if (user.role == 'shop' &&
                                user.approvalStatus == 'pending') ...[
                              FilledButton(
                                onPressed: data.busy.contains(user.id)
                                    ? null
                                    : () => review(user, 'approved'),
                                child: const Text('Approve'),
                              ),
                              OutlinedButton(
                                onPressed: data.busy.contains(user.id)
                                    ? null
                                    : () => review(user, 'rejected'),
                                child: const Text('Reject'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Text(
                'Showing ${visible.length} of ${data.users.length} accounts',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
