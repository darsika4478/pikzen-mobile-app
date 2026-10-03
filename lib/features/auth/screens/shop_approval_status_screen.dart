import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_ui.dart';

/// Displays the existing approval decision for the signed-in shop account.
class ShopApprovalStatusScreen extends StatefulWidget {
  const ShopApprovalStatusScreen({
    super.key,
    required this.rejected,
    this.profileDocuments,
  });

  final bool rejected;
  final Stream<Map<String, dynamic>?> Function(String uid)? profileDocuments;

  @override
  State<ShopApprovalStatusScreen> createState() =>
      _ShopApprovalStatusScreenState();
}

class _ShopApprovalStatusScreenState extends State<ShopApprovalStatusScreen> {
  String? _sourceUid;
  Stream<Map<String, dynamic>?>? _profileStream;
  bool _transitionScheduled = false;
  bool _checking = false;
  bool _signingOut = false;

  @override
  void didUpdateWidget(covariant ShopApprovalStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileDocuments != widget.profileDocuments) {
      _sourceUid = null;
    }
  }

  void _bind(String uid, AuthProvider auth) {
    if (_sourceUid == uid && _profileStream != null) return;
    _sourceUid = uid;
    _profileStream =
        widget.profileDocuments?.call(uid) ??
        (Firebase.apps.isEmpty
            ? Stream<Map<String, dynamic>?>.value({
                'role': auth.user?.role,
                'approvalStatus': auth.user?.approvalStatus,
              })
            : FirestoreService().database
                  .collection('users')
                  .doc(uid)
                  .snapshots()
                  .map((document) => document.data()));
  }

  void _followDecision(String uid, String? observedStatus) {
    if (_transitionScheduled) return;
    _transitionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transitionScheduled = false;
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.user?.id != uid || auth.user?.role != 'shop') return;
      auth.syncShopApprovalStatus(uid, observedStatus);
      final destination = auth.destination;
      final current = widget.rejected ? 'shop-rejected' : 'shop-pending';
      if (destination != null && destination != current) {
        context.goNamed(destination);
      }
    });
  }

  Future<void> _checkStatus() async {
    if (_checking || _signingOut) return;
    setState(() => _checking = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.refreshProfile();
      if (!mounted) return;
      final destination = auth.destination;
      final current = widget.rejected ? 'shop-rejected' : 'shop-pending';
      if (destination != null && destination != current) {
        context.goNamed(destination);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your approval status has not changed.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check approval status. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _backToLogin() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await context.read<AuthProvider>().signOut();
      if (mounted) context.goNamed('login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = Firebase.apps.isEmpty
        ? auth.user?.id
        : FirebaseAuth.instance.currentUser?.uid;
    final validShop =
        uid != null && auth.user?.id == uid && auth.user?.role == 'shop';
    if (validShop) _bind(uid, auth);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: validShop
                  ? StreamBuilder<Map<String, dynamic>?>(
                      stream: _profileStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final data = snapshot.data;
                        if (snapshot.hasError ||
                            data == null ||
                            data['role'] != 'shop') {
                          return _statusCard(
                            title: 'Shop status unavailable',
                            message: 'Your shop account status could not be verified.',
                            icon: Icons.error_outline,
                            color: AppColors.warning,
                            allowCheck: true,
                          );
                        }
                        final rawStatus = data['approvalStatus'];
                        final status = rawStatus ?? 'pending';
                        if (!{
                          'pending',
                          'approved',
                          'rejected',
                        }.contains(status)) {
                          return _statusCard(
                            title: 'Shop status unavailable',
                            message: 'Please contact support about your shop account.',
                            icon: Icons.error_outline,
                            color: AppColors.warning,
                            allowCheck: true,
                          );
                        }
                        final expected = widget.rejected
                            ? 'rejected'
                            : 'pending';
                        if (status != expected) {
                          _followDecision(uid, rawStatus as String?);
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return widget.rejected
                            ? _statusCard(
                                title: 'Shop Account Not Approved',
                                message: 'Your Shop Owner registration was not approved.',
                                detail: 'Please contact PikZen support if you need more information or want to clarify your registration details.',
                                badge: 'NOT APPROVED',
                                icon: Icons.warning_amber_rounded,
                                color: AppColors.error,
                                allowCheck: true,
                              )
                            : _statusCard(
                                title: 'Registration Submitted',
                                message: 'Your shop account is awaiting admin approval.',
                                detail: 'We have received your Shop Owner registration. You can access the Shop Dashboard after your account is approved.',
                                badge: 'PENDING APPROVAL',
                                icon: Icons.hourglass_top_rounded,
                                color: AppColors.warning,
                                allowCheck: true,
                              );
                      },
                    )
                  : _statusCard(
                      title: 'Shop status unavailable',
                      message: 'Sign in with your Shop Owner account to view its status.',
                      icon: Icons.person_off_outlined,
                      color: AppColors.warning,
                      allowCheck: false,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required bool allowCheck,
    String? detail,
    String? badge,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AuthLogo(size: 52),
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 36,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 34),
        ),
        const SizedBox(height: 18),
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (detail != null) ...[
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _signingOut ? null : _backToLogin,
            child: Text(_signingOut ? 'Signing out…' : 'Back to Login'),
          ),
        ),
        if (allowCheck) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _checking || _signingOut ? null : _checkStatus,
            child: Text(_checking ? 'Checking…' : 'Check Approval Status'),
          ),
        ],
      ],
    ),
  );
}
