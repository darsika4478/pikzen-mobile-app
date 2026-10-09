import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../models/product_model.dart';

class FirestoreService {
  FirestoreService({this._database, this._auth});
  final FirebaseFirestore? _database;
  final FirebaseAuth? _auth;
  FirebaseFirestore get database => _database ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;

  Future<String> approvedShopUid() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in with an approved shop account.');
    final profile = await database.collection('users').doc(uid).get();
    if (profile.data()?['role'] != 'shop' ||
        profile.data()?['approvalStatus'] != 'approved') {
      throw StateError('An approved shop account is required.');
    }
    return uid;
  }

  Stream<Map<String, dynamic>> approvedShopProfile() async* {
    final uid = await approvedShopUid();
    yield* database.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null ||
          data['role'] != 'shop' ||
          data['approvalStatus'] != 'approved') {
        throw StateError('An approved shop account is required.');
      }
      return {...data, 'uid': uid};
    });
  }

  Future<void> updateShopProfile({
    required String phone,
    required String shopName,
    required String storeAddress,
  }) async {
    final uid = await approvedShopUid();
    if (shopName.trim().isEmpty) {
      throw ArgumentError('Enter a shop name.');
    }
    await database.collection('users').doc(uid).update({
      'phone': phone.trim(),
      'shopName': shopName.trim(),
      'storeAddress': storeAddress.trim(),
    });
  }

  /// Shop alert switches: newOrderAlerts, lowStockAlerts and
  /// customerMessageAlerts. Missing keys mean "on".
  static const shopAlertKeys = [
    'newOrderAlerts',
    'lowStockAlerts',
    'customerMessageAlerts',
  ];

  Future<void> setShopAlert(String key, bool enabled) async {
    if (!shopAlertKeys.contains(key)) {
      throw ArgumentError('Unknown alert setting.');
    }
    final uid = await approvedShopUid();
    await database.collection('users').doc(uid).update({
      'preferences.$key': enabled,
    });
  }

  Stream<List<ProductModel>> shopProducts() async* {
    final uid = await approvedShopUid();
    yield* database
        .collection('products')
        .where('shopId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<ProductModel?> watchShopProduct(String productId) async* {
    final uid = await approvedShopUid();
    yield* database
        .collection('products')
        .doc(productId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists && snapshot.data()?['shopId'] == uid
              ? ProductModel.fromMap(snapshot.id, snapshot.data()!)
              : null,
        );
  }

  Future<ProductModel> saveShopProduct({
    String? productId,
    required String name,
    required String category,
    required int priceMinor,
    required int stockQuantity,
    String description = '',
    String unit = '',
    String? imageUrl,
    int lowStockThreshold = 5,
  }) async {
    final uid = await approvedShopUid();
    final cleanName = name.trim();
    final cleanCategory = ProductModel.canonicalCategory(category);
    if (cleanName.isEmpty ||
        cleanCategory.isEmpty ||
        priceMinor <= 0 ||
        stockQuantity < 0 ||
        lowStockThreshold < 0) {
      throw ArgumentError('Enter a name, category, valid price and stock.');
    }
    final productsRef = database.collection('products');
    final ref = productId == null
        ? productsRef.doc()
        : productsRef.doc(productId);
    final profile = await database.collection('users').doc(uid).get();
    final fields = <String, Object?>{
      'name': cleanName,
      'category': cleanCategory,
      'priceMinor': priceMinor,
      'currencyCode': 'LKR',
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'description': description.trim(),
      'unit': unit.trim(),
      'imageUrl': ?imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (productId == null) {
      await ref.set({
        ...fields,
        'shopId': uid,
        'shopName':
            (profile.data()?['shopName'] ?? profile.data()?['fullName'] ?? '')
                .toString(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await database.runTransaction((transaction) async {
        final current = await transaction.get(ref);
        if (!current.exists || current.data()?['shopId'] != uid) {
          throw StateError('This product is unavailable for your shop.');
        }
        transaction.update(ref, fields);
      });
    }
    final saved = await ref.get();
    return ProductModel.fromMap(saved.id, saved.data()!);
  }

  Future<void> updateShopStock(String productId, int quantity) async {
    await updateShopStocks({productId: quantity});
  }

  Future<void> updateShopStocks(Map<String, int> quantities) async {
    if (quantities.isEmpty) return;
    if (quantities.values.any((quantity) => quantity < 0)) {
      throw ArgumentError('Stock cannot be negative.');
    }
    final uid = await approvedShopUid();
    final refs = quantities.keys
        .map((id) => database.collection('products').doc(id))
        .toList();
    await database.runTransaction((transaction) async {
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) {
        snapshots.add(await transaction.get(ref));
      }
      if (snapshots.any((doc) => !doc.exists || doc.data()?['shopId'] != uid)) {
        throw StateError('A product is unavailable for your shop.');
      }
      for (var index = 0; index < refs.length; index++) {
        transaction.update(refs[index], {
          'stockQuantity': quantities[refs[index].id],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> deactivateShopProduct(String productId) async {
    final uid = await approvedShopUid();
    final ref = database.collection('products').doc(productId);
    await database.runTransaction((transaction) async {
      final current = await transaction.get(ref);
      if (!current.exists || current.data()?['shopId'] != uid) {
        throw StateError('This product is unavailable for your shop.');
      }
      transaction.update(ref, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

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
            .where((product) => product.isActive)
            .toList(),
      );

  CollectionReference<Map<String, dynamic>> _favourites(String uid) =>
      database.collection('users').doc(uid).collection('favourites');

  /// Product IDs the user saved with the heart button.
  Stream<Set<String>> favouriteIds(String uid) =>
      _favourites(uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

  Future<void> setFavourite(String uid, String productId, bool saved) {
    final ref = _favourites(uid).doc(productId);
    return saved
        ? ref.set({
            'productId': productId,
            'createdAt': FieldValue.serverTimestamp(),
          })
        : ref.delete();
  }

  /// Fetches authoritative prices and stock before entering checkout.
  Future<List<ProductModel>> currentProducts() async {
    final snapshot = await database
        .collection('products')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.id, doc.data()))
        .where((product) => product.isActive)
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

  /// Admin: suspend or reactivate a customer or shop account. Suspended
  /// accounts cannot sign in or place orders (enforced by rules too).
  Future<void> setAccountStatus(String uid, String accountStatus) async {
    if (!['active', 'suspended'].contains(accountStatus)) {
      throw ArgumentError('Choose active or suspended.');
    }
    if (uid == auth.currentUser?.uid) {
      throw StateError('You cannot change your own account status.');
    }
    await database.collection('users').doc(uid).update({
      'accountStatus': accountStatus,
    });
  }

  /// Admin: move an account between customer and (approved) shop.
  Future<void> setUserRole(String uid, String role) async {
    if (!['customer', 'shop'].contains(role)) {
      throw ArgumentError('Choose customer or shop.');
    }
    if (uid == auth.currentUser?.uid) {
      throw StateError('You cannot change your own role.');
    }
    await database.collection('users').doc(uid).update({
      'role': role,
      'approvalStatus': role == 'shop' ? 'approved' : FieldValue.delete(),
    });
  }

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
