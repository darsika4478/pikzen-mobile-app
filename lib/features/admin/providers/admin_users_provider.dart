import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/firestore_service.dart';
import '../../../models/user_model.dart';

/// Account-status filter applied on top of the role tab.
enum AdminStatusFilter { all, active, suspended }

/// Directory sort order.
enum AdminSort { name, newest }

class AdminUsersProvider extends ChangeNotifier {
  AdminUsersProvider({FirestoreService? service})
    : _service = service ?? FirestoreService(),
      _live = service != null || Firebase.apps.isNotEmpty {
    if (_live) {
      _listen();
    } else {
      loading = false;
    }
  }
  final FirestoreService _service;
  final bool _live;
  StreamSubscription<List<UserModel>>? _subscription;
  List<UserModel> users = [];
  bool loading = true;
  bool _disposed = false;
  String? error;
  final Set<String> busy = {};
  AdminStatusFilter statusFilter = AdminStatusFilter.all;
  AdminSort sort = AdminSort.name;
  DateTime? lastSynced;

  void _listen() {
    _subscription?.cancel();
    _subscription = _service.users().listen(
      (data) {
        users = data;
        loading = false;
        error = null;
        lastSynced = DateTime.now();
        _notify();
      },
      onError: (Object _) {
        loading = false;
        error = 'Unable to load users. Check your access and connection.';
        _notify();
      },
    );
  }

  /// Reconnects to the directory (the "Sync" action).
  void refresh() {
    if (!_live) return;
    loading = true;
    error = null;
    _notify();
    _listen();
  }

  void setStatusFilter(AdminStatusFilter value) {
    statusFilter = value;
    _notify();
  }

  void setSort(AdminSort value) {
    sort = value;
    _notify();
  }

  int count(String filter) => matching(filter, '', applyStatus: false).length;
  int get activeCount => users.where((u) => !u.isSuspended).length;
  int get suspendedCount => users.where((u) => u.isSuspended).length;

  List<UserModel> matching(
    String filter,
    String query, {
    bool applyStatus = true,
  }) {
    final needle = query.trim().toLowerCase();
    final result = users.where((user) {
      final matchesTab = switch (filter) {
        'Customers' => user.role == 'customer',
        'Shop Owners' => user.role == 'shop',
        'Pending Shops' =>
          user.role == 'shop' && user.approvalStatus == 'pending',
        'Admins' => user.role == 'admin',
        _ => true,
      };
      final matchesStatus =
          !applyStatus ||
          switch (statusFilter) {
            AdminStatusFilter.all => true,
            AdminStatusFilter.active => !user.isSuspended,
            AdminStatusFilter.suspended => user.isSuspended,
          };
      return matchesTab &&
          matchesStatus &&
          '${user.name} ${user.email} ${user.shopName ?? ''} ${user.phoneNumber ?? ''}'
              .toLowerCase()
              .contains(needle);
    }).toList();
    switch (sort) {
      case AdminSort.name:
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case AdminSort.newest:
        result.sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        );
    }
    return result;
  }

  void _replace(UserModel updated) {
    users = users.map((u) => u.id == updated.id ? updated : u).toList();
  }

  Future<bool> _run(
    UserModel user,
    Future<void> Function() action,
    UserModel optimistic,
    String failure,
  ) async {
    if (busy.contains(user.id)) return false;
    busy.add(user.id);
    error = null;
    _notify();
    try {
      await action();
      // Apply the successful write immediately; the stream reconciles later.
      _replace(optimistic);
      return true;
    } catch (_) {
      error = failure;
      return false;
    } finally {
      busy.remove(user.id);
      _notify();
    }
  }

  Future<bool> review(UserModel user, String decision) async {
    if (user.role != 'shop' || user.approvalStatus != 'pending') return false;
    return _run(
      user,
      () => _service.reviewShop(user.id, approvalStatus: decision),
      user.copyWith(approvalStatus: decision),
      'Unable to update this shop. It may already have been reviewed. Please retry.',
    );
  }

  Future<bool> setSuspended(UserModel user, bool suspended) {
    if (user.role == 'admin') return Future.value(false);
    final status = suspended ? 'suspended' : 'active';
    return _run(
      user,
      () => _service.setAccountStatus(user.id, status),
      user.copyWith(accountStatus: status),
      'Unable to ${suspended ? 'suspend' : 'reactivate'} ${user.name}. Please retry.',
    );
  }

  Future<bool> changeRole(UserModel user, String role) {
    if (user.role == 'admin' || user.role == role) return Future.value(false);
    return _run(
      user,
      () => _service.setUserRole(user.id, role),
      role == 'shop'
          ? user.copyWith(role: 'shop', approvalStatus: 'approved')
          : user.copyWith(role: 'customer', clearApproval: true),
      'Unable to change the role for ${user.name}. Please retry.',
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
