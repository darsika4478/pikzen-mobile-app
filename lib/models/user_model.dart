import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.role = 'customer',
    this.approvalStatus,
    this.createdAt,
    this.accountStatus,
    this.shopName,
    this.photoUrl,
  });
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String role;
  final String? approvalStatus;
  final DateTime? createdAt;
  final String? accountStatus;
  final String? shopName;
  final String? photoUrl;

  /// Accounts without an explicit status are active.
  bool get isSuspended => accountStatus == 'suspended';

  UserModel copyWith({
    String? role,
    String? approvalStatus,
    bool clearApproval = false,
    String? accountStatus,
  }) => UserModel(
    id: id,
    name: name,
    email: email,
    phoneNumber: phoneNumber,
    role: role ?? this.role,
    approvalStatus: clearApproval
        ? null
        : approvalStatus ?? this.approvalStatus,
    createdAt: createdAt,
    accountStatus: accountStatus ?? this.accountStatus,
    shopName: shopName,
    photoUrl: photoUrl,
  );
  bool get isApprovedShop => role == 'shop' && approvalStatus == 'approved';

  factory UserModel.fromMap(String id, Map<String, dynamic> data) => UserModel(
    id: id,
    name: (data['fullName'] ?? data['name'] ?? '') as String,
    email: (data['email'] ?? '') as String,
    phoneNumber: (data['phone'] ?? data['phoneNumber']) as String?,
    // A missing role must never silently grant customer access.
    role: (data['role'] ?? '') as String,
    approvalStatus: data['approvalStatus'] as String?,
    accountStatus: data['accountStatus'] is String
        ? data['accountStatus'] as String
        : null,
    shopName: data['shopName'] is String ? data['shopName'] as String : null,
    photoUrl: data['photoUrl'] is String ? data['photoUrl'] as String : null,
    createdAt: data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : data['createdAt'] is DateTime
        ? data['createdAt'] as DateTime
        : null,
  );
}
