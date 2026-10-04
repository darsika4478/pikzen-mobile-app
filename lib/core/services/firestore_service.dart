import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_model.dart';
import '../../models/product_model.dart';

class FirestoreService {
  FirestoreService({this._database});
  final FirebaseFirestore? _database;
  FirebaseFirestore get database => _database ?? FirebaseFirestore.instance;

  Future<UserModel?> user(String uid) async {
    final doc = await database.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromMap(doc.id, doc.data()!) : null;
  }

  Stream<List<ProductModel>> products() => database
      .collection('products')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
            .toList(),
      );

  /// Fetches authoritative prices and stock before entering checkout.
  Future<List<ProductModel>> currentProducts() async {
    final snapshot = await database
        .collection('products')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Stream<List<UserModel>> users() => database
      .collection('users')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.id, doc.data()))
            .toList(),
      );

  /// Public registration cannot supply an admin role or an approval decision.
  static Map<String, dynamic> registrationData({
    required String uid,
    required String name,
    required String email,
    String? phone,
    String role = 'customer',
  }) {
    if (!['customer', 'shop'].contains(role)) {
      throw ArgumentError(
        'Public registration supports customer or shop only.',
      );
    }
    return {
      'uid': uid,
      'fullName': name,
      'email': email,
      'phone': phone,
      'role': role,
      if (role == 'shop') 'approvalStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Google registration always defaults to customer; existing profiles survive.
  Future<void> createCustomer({
    required String uid,
    required String name,
    required String email,
    String? phone,
  }) => createPublicUser(uid: uid, name: name, email: email, phone: phone);

  Future<void> createPublicUser({
    required String uid,
    required String name,
    required String email,
    String? phone,
    String role = 'customer',
  }) async {
    final data = registrationData(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      role: role,
    );
    final ref = database.collection('users').doc(uid);
    await database.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (!existing.exists) transaction.set(ref, data);
    });
  }

  /// Future Admin UI integration. Firestore rules require an authenticated admin.
  Stream<List<UserModel>> pendingShops() => database
      .collection('users')
      .where('role', isEqualTo: 'shop')
      .where('approvalStatus', isEqualTo: 'pending')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.id, doc.data()))
            .toList(),
      );

  Future<void> reviewShop(
    String shopUid, {
    required String approvalStatus,
  }) async {
    if (!['approved', 'rejected'].contains(approvalStatus)) {
      throw ArgumentError('Choose approved or rejected.');
    }
    final ref = database.collection('users').doc(shopUid);
    await database.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists ||
          doc.data()?['role'] != 'shop' ||
          doc.data()?['approvalStatus'] != 'pending') {
        throw StateError('Only pending shop accounts can be reviewed.');
      }
      transaction.update(ref, {'approvalStatus': approvalStatus});
    });
  }
}
