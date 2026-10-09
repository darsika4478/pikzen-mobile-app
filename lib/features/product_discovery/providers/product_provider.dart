import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/firestore_service.dart';

import 'package:flutter/foundation.dart';

import '../../../models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({Stream<List<ProductModel>>? source, this._store})
    : _source = source {
    if (source != null) _listen(source);
  }
  final Stream<List<ProductModel>>? _source;
  final FirestoreService? _store;
  StreamSubscription<List<ProductModel>>? _subscription;
  StreamSubscription<Set<String>>? _favouriteSubscription;

  /// Favourites persist in Firestore when Firebase (or a test store) exists.
  FirestoreService? get _favouriteStore =>
      _store ?? (Firebase.apps.isNotEmpty ? FirestoreService() : null);
  List<ProductModel> _products = catalog;
  bool isDemo = true;
  bool loading = false;
  String? error;
  bool _hadLiveProducts = false;
  void _listen(Stream<List<ProductModel>> source) {
    loading = true;
    _subscription = source.listen(
      (items) {
        if (items.isNotEmpty) _hadLiveProducts = true;
        isDemo = items.isEmpty && !_hadLiveProducts;
        _products = List.unmodifiable(isDemo ? catalog : items);
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object _) {
        loading = false;
        error = 'Live inventory is unavailable. Please try again.';
        notifyListeners();
      },
    );
  }

  void retry() {
    _subscription?.cancel();
    if (_source != null) {
      _listen(_source);
    } else if (Firebase.apps.isNotEmpty && _owner != null) {
      _listen(FirestoreService().products());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _favouriteSubscription?.cancel();
    super.dispose();
  }

  void _listenFavourites(String? uid) {
    _favouriteSubscription?.cancel();
    _favouriteSubscription = null;
    final store = _favouriteStore;
    if (uid == null || store == null) return;
    _favouriteSubscription = store.favouriteIds(uid).listen((ids) {
      _favourites
        ..clear()
        ..addAll(ids);
      notifyListeners();
    }, onError: (Object _) {});
  }

  // A single fallback, replaced entirely by the shared Firestore catalog.
  static const catalog = <ProductModel>[
    ProductModel(
      id: 'red-apples',
      name: 'Red Apples',
      category: 'Fruits',
      priceMinor: 95000,
      currencyCode: 'LKR',
      unit: 'Royal Gala, 1kg',
      description: 'Crisp Royal Gala apples, selected for everyday snacking.',
      imageUrl: 'assets/images/Apples Product.png',
    ),
    ProductModel(
      id: 'farm-eggs',
      name: 'Farm Fresh Eggs',
      category: 'Dairy & Eggs',
      priceMinor: 48000,
      currencyCode: 'LKR',
      unit: 'Brown, Pack of 10',
      description: 'A pack of ten fresh brown eggs for your kitchen.',
      imageUrl: 'assets/images/Eggs Product.png',
    ),
    ProductModel(
      id: 'samba-rice',
      name: 'Keeri Samba Rice',
      category: 'Pantry Staples',
      priceMinor: 145000,
      currencyCode: 'LKR',
      unit: 'Araliya Super, 5kg',
      description: 'A five-kilogram bag of Keeri Samba rice.',
      imageUrl: 'assets/images/Rice Product.png',
    ),
    ProductModel(
      id: 'whole-milk',
      name: 'Fresh Whole Milk',
      category: 'Dairy & Eggs',
      priceMinor: 52000,
      currencyCode: 'LKR',
      unit: 'Kotmale / Highland, 1L',
      description: 'One litre of chilled whole milk.',
      imageUrl: 'assets/images/Milk Product.png',
      stockQuantity: 5,
    ),
  ];
  static const categoryImages = {
    'Fruits': 'assets/images/fruits.png',
    'Vegetables': 'assets/images/Veggis.png',
    'Dairy & Eggs': 'assets/images/Dairy.png',
    'Bakery': 'assets/images/Bakery.png',
    'Beverages': 'assets/images/Beverages.png',
    'Snacks & Bites': 'assets/images/Snacks&bites.png',
    'Household': 'assets/images/Household.png',
    'Pantry Staples': 'assets/images/Pantry.png',
  };
  static const categoryTags = {
    'Fruits': 'Fresh picks',
    'Vegetables': 'Garden favourites',
    'Dairy & Eggs': 'Everyday essentials',
    'Bakery': 'Baked favourites',
    'Beverages': 'Refreshing choices',
    'Snacks & Bites': 'A little treat',
    'Household': 'Home essentials',
    'Pantry Staples': 'Stock your pantry',
  };
  final Set<String> _favourites = {};
  String? _owner;
  void bindUser(String? uid) {
    if (_owner != uid) {
      _owner = uid;
      _favourites.clear();
      _listenFavourites(uid);
      if (_source == null) {
        _subscription?.cancel();
        _hadLiveProducts = false;
        isDemo = true;
        error = null;
        _products = catalog;
        if (uid != null && Firebase.apps.isNotEmpty) {
          _listen(FirestoreService().products());
        }
      }
      notifyListeners();
    }
  }

  List<ProductModel> get products => _products;
  ProductModel? byId(String id) {
    for (final item in _products) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<ProductModel> matching({
    String query = '',
    String? category,
  }) => _products
      .where(
        (p) =>
            (category == null ||
                p.category == ProductModel.canonicalCategory(category)) &&
            ('${p.name} ${p.description} ${p.unit} ${p.brand} ${p.shopName}')
                .toLowerCase()
                .contains(query.trim().toLowerCase()),
      )
      .toList();
  bool isFavourite(String id) => _favourites.contains(id);
  List<ProductModel> get favourites =>
      _products.where((p) => isFavourite(p.id)).toList();
  void toggleFavourite(String id) {
    if (byId(id) == null) return;
    final saved = !_favourites.remove(id);
    if (saved) _favourites.add(id);
    notifyListeners();
    final uid = _owner;
    final store = _favouriteStore;
    if (uid == null || store == null) return;
    store.setFavourite(uid, id, saved).catchError((Object _) {
      // Roll back the optimistic change if the write is rejected.
      if (_owner != uid) return;
      saved ? _favourites.remove(id) : _favourites.add(id);
      notifyListeners();
    });
  }
}
