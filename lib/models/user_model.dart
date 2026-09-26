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
  });
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String role;
  final String? approvalStatus;
  final DateTime? createdAt;
  bool get isApprovedShop => role == 'shop' && approvalStatus == 'approved';

  factory UserModel.fromMap(String id, Map<String, dynamic> data) => UserModel(
    id: id,
    name: (data['fullName'] ?? data['name'] ?? '') as String,
    email: (data['email'] ?? '') as String,
    phoneNumber: (data['phone'] ?? data['phoneNumber']) as String?,
    // A missing role must never silently grant customer access.
    role: (data['role'] ?? '') as String,
    approvalStatus: data['approvalStatus'] as String?,
    createdAt: data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : data['createdAt'] is DateTime
        ? data['createdAt'] as DateTime
        : null,
  );
}
