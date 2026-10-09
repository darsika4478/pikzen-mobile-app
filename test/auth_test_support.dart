import 'package:pikzen/core/services/auth_service.dart';
import 'package:pikzen/models/user_model.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({this.role = 'customer', this.approvalStatus});
  final String? approvalStatus;
  final String role;
  int signInCalls = 0;
  int registrations = 0;
  int googleCalls = 0;
  String? resetEmail;
  bool? rememberedValue;
  UserModel get account => UserModel(
    id: 'test-user',
    name: 'Darsika N',
    email: 'darsika@example.com',
    role: role,
    approvalStatus: approvalStatus,
  );
  @override
  Future<UserModel> signIn(String email, String password, bool remember) async {
    signInCalls++;
    rememberedValue = remember;
    return account;
  }

  @override
  Future<UserModel> google(bool remember) async {
    googleCalls++;
    return account;
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'customer',
  }) async {
    registrations++;
    return UserModel(
      id: 'new-user',
      name: name,
      email: email,
      phoneNumber: phone,
      role: role,
      approvalStatus: role == 'shop' ? 'pending' : null,
    );
  }

  @override
  Future<void> resetPassword(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> signOut() async {}
}
