/// Shared user details, independent of an authentication provider.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
  });

  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
}
