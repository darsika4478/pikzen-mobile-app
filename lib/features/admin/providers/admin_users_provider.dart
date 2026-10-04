import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/firestore_service.dart';
import '../../../models/user_model.dart';

class AdminUsersProvider extends ChangeNotifier {
  AdminUsersProvider({FirestoreService? service})
    : _service = service ?? FirestoreService() {
    if (service != null || Firebase.apps.isNotEmpty) {
      _subscription = _service.users().listen(
        (data) {
          users = data;
          loading = false;
          error = null;
          notifyListeners();
        },
        onError: (Object _) {
          loading = false;
          error = 'Unable to load users. Check your access and connection.';
          notifyListeners();
        },
      );
    } else {
      loading = false;
    }
  }
  final FirestoreService _service;
  StreamSubscription<List<UserModel>>? _subscription;
  List<UserModel> users = [];
  bool loading = true;
  bool _disposed = false;
  String? error;
  final Set<String> busy = {};
  List<UserModel> matching(String filter, String query) => users.where((user) {
    final matches = switch (filter) {
      'Customers' => user.role == 'customer',
      'Shop Owners' => user.role == 'shop',
      'Pending Shops' =>
        user.role == 'shop' && user.approvalStatus == 'pending',
      _ => true,
    };
    return matches &&
        '${user.name} ${user.email}'.toLowerCase().contains(
          query.trim().toLowerCase(),
        );
  }).toList();
  Future<bool> review(UserModel user, String decision) async {
    if (busy.contains(user.id) ||
        user.role != 'shop' ||
        user.approvalStatus != 'pending') {
      return false;
    }
    busy.add(user.id);
    error = null;
    notifyListeners();
    try {
      await _service.reviewShop(user.id, approvalStatus: decision);
      // Apply the successful transaction immediately; the stream reconciles later.
      users = users
          .map(
            (current) => current.id != user.id
                ? current
                : UserModel(
                    id: current.id,
                    name: current.name,
                    email: current.email,
                    phoneNumber: current.phoneNumber,
                    role: current.role,
                    createdAt: current.createdAt,
                    approvalStatus: decision,
                    accountStatus: current.accountStatus,
                  ),
          )
          .toList();
      return true;
    } catch (_) {
      error = 'Unable to update this shop. It may already have been reviewed. Please retry.';
      return false;
    } finally {
      busy.remove(user.id);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
