import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import 'firestore_service.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

class AuthService {
  AuthService({this._auth, FirestoreService? profiles})
    : profiles = profiles ?? FirestoreService();
  final FirebaseAuth? _auth;
  final FirestoreService profiles;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  static Future<void>? _googleInitialization;

  Future<bool> remembered() async =>
      (await SharedPreferences.getInstance()).getBool('rememberSignIn') ??
      false;
  Future<void> _persistence(bool remember) async {
    if (kIsWeb) {
      await auth.setPersistence(
        remember ? Persistence.LOCAL : Persistence.SESSION,
      );
    }
    // Native Firebase manages its normal persisted session. Store preference only.
    await (await SharedPreferences.getInstance()).setBool(
      'rememberSignIn',
      remember,
    );
  }

  Future<UserModel> profile() async {
    final user = auth.currentUser;
    if (user == null) throw const AuthFailure('Please sign in again.');
    final result = await profiles.user(user.uid);
    if (result == null) {
      throw const AuthFailure(
        'Your account profile is missing. Please contact support.',
      );
    }
    if (!['customer', 'shop', 'admin'].contains(result.role)) {
      throw const AuthFailure(
        'Your account role is not supported. Please contact support.',
      );
    }
    if (result.name.trim().isEmpty &&
        (user.displayName ?? '').trim().isNotEmpty) {
      return UserModel(
        id: result.id,
        name: user.displayName!,
        email: result.email,
        phoneNumber: result.phoneNumber,
        role: result.role,
        approvalStatus: result.approvalStatus,
        createdAt: result.createdAt,
      );
    }
    return result;
  }

  Future<UserModel> signIn(String email, String password, bool remember) async {
    await _persistence(remember);
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return profile();
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'customer',
  }) async {
    if (!['customer', 'shop'].contains(role)) {
      throw const AuthFailure(
        'Public registration supports customer or shop only.',
      );
    }
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await credential.user!.updateDisplayName(name.trim());
      await profiles.createPublicUser(
        role: role,
        uid: credential.user!.uid,
        name: name.trim(),
        email: credential.user!.email ?? email.trim(),
        phone: phone,
      );
    } catch (_) {
      // Avoid leaving a password account unusable after a failed profile write.
      try {
        await credential.user!.delete();
      } catch (_) {
        await auth.signOut();
      }
      throw const AuthFailure(
        'Account setup could not finish. Please retry or contact support.',
      );
    }
    return profile();
  }

  Future<UserModel> google(bool remember) async {
    await _persistence(remember);
    UserCredential credential;
    if (kIsWeb) {
      credential = await auth.signInWithPopup(GoogleAuthProvider());
    } else {
      _googleInitialization ??= GoogleSignIn.instance.initialize();
      await _googleInitialization;
      final googleUser = await GoogleSignIn.instance.authenticate();
      final token = googleUser.authentication.idToken;
      if (token == null) {
        throw const AuthFailure(
          'Google sign-in could not be completed. Please try again.',
        );
      }
      credential = await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
    }
    final user = credential.user!;
    await profiles.createCustomer(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
    );
    return profile();
  }

  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
  Future<void> signOut() => auth.signOut();

  static String message(Object error) {
    if (error is AuthFailure) return error.message;
    if (error is GoogleSignInException) {
      return 'Google sign-in was cancelled or is unavailable. Please try again.';
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Enter a valid email address',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Email or password is incorrect.',
        'email-already-in-use' =>
          'An account already uses this email. Please sign in.',
        'weak-password' =>
          'Choose a stronger password with at least 8 characters.',
        'user-disabled' => 'This account is disabled. Please contact support.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'operation-not-allowed' =>
          'This sign-in method is not enabled yet. Please contact support.',
        'popup-closed-by-user' ||
        'cancelled-popup-request' => 'Google sign-in was cancelled.',
        _ => 'Unable to sign in right now. Please try again.',
      };
    }
    return 'Unable to complete this request. Check your connection and try again.';
  }
}
