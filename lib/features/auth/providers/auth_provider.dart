import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/auth_service.dart';
import '../../../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? service, bool restore = true})
    : _service = service ?? AuthService() {
    if (restore && Firebase.apps.isNotEmpty) unawaited(_restore());
  }
  final AuthService _service;
  StreamSubscription<Object?>? _session;
  bool _disposed = false;
  bool busy = false;
  bool rememberMe = false;
  String? error;
  UserModel? user;
  String? get firstName {
    final name = user?.name.trim() ?? '';
    return name.isEmpty ? null : name.split(RegExp(r'\s+')).first;
  }

  // Reserved integration point until the Admin workspace is included.
  static const String? adminRoute = null;
  String? get destination => switch (user?.role) {
    'customer' => 'customer-home',
    'shop' => user!.isApprovedShop ? 'shop-dashboard' : null,
    'admin' => adminRoute,
    _ => null,
  };
  String? get shopAccessMessage {
    if (user?.role != 'shop' || user!.isApprovedShop) return null;
    return switch (user!.approvalStatus) {
      null || 'pending' => 'Your shop account is awaiting admin approval.',
      'rejected' => 'Your shop account was not approved.',
      _ => 'Your shop approval status is invalid. Please contact support.',
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _restore() async {
    try {
      rememberMe = await _service.remembered();
      final uid = _service.auth.currentUser?.uid;
      if (uid != null) {
        final profile = await _service.profile();
        if (!busy && _service.auth.currentUser?.uid == uid) user = profile;
      }
      if (_disposed) return;
      _session = _service.auth.authStateChanges().listen((session) {
        if (session == null) {
          user = null;
          _notify();
        }
      });
    } catch (_) {
      /* Keep login available if restoring the profile fails. */
    }
    _notify();
  }

  void setRemember(bool value) {
    rememberMe = value;
    _notify();
  }

  Future<bool> _run(
    Future<UserModel> Function() action, {
    bool registering = false,
  }) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      user = await action();
      if (shopAccessMessage != null) {
        if (registering && user?.approvalStatus == 'pending') return true;
        throw AuthFailure(shopAccessMessage!);
      }
      if (destination == null) {
        throw const AuthFailure(
          'The admin workspace is not available yet. Please contact your team administrator.',
        );
      }
      return true;
    } catch (e) {
      user = null;
      error = AuthService.message(e);
      try {
        await _service.signOut();
      } catch (_) {}
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _service.signIn(email, password, rememberMe));
  Future<bool> google() => _run(() => _service.google(rememberMe));
  Future<bool> register(
    String name,
    String email,
    String phone,
    String password, {
    String role = 'customer',
  }) => _run(
    () => _service.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
    ),
    registering: true,
  );
  Future<bool> reset(String email) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await _service.resetPassword(email);
      return true;
    } catch (e) {
      error = AuthService.message(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    user = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.cancel();
    super.dispose();
  }
}
