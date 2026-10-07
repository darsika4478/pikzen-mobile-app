import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/core/services/firestore_service.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';
import 'package:pikzen/models/product_model.dart';

class _Store extends FirestoreService {
  final ids = StreamController<Set<String>>.broadcast();
  final writes = <String>[];
  bool fail = false;

  @override
  Stream<Set<String>> favouriteIds(String uid) => ids.stream;

  @override
  Future<void> setFavourite(String uid, String productId, bool saved) async {
    if (fail) throw StateError('denied');
    writes.add('$uid:$productId:$saved');
  }
}

void main() {
  const products = [
    ProductModel(
      id: 'apple',
      name: 'Apple',
      priceMinor: 100,
      currencyCode: 'LKR',
    ),
    ProductModel(
      id: 'milk',
      name: 'Milk',
      priceMinor: 200,
      currencyCode: 'LKR',
    ),
  ];

  test('favourites load from and save to the signed-in user store', () async {
    final store = _Store();
    final provider = ProductProvider(
      source: Stream.value(products),
      store: store,
    );
    addTearDown(provider.dispose);
    addTearDown(store.ids.close);
    await pumpEventQueue();

    provider.bindUser('customer-1');
    store.ids.add({'milk'});
    await pumpEventQueue();
    expect(provider.isFavourite('milk'), isTrue);

    provider.toggleFavourite('apple');
    await pumpEventQueue();
    expect(provider.isFavourite('apple'), isTrue);
    expect(store.writes, ['customer-1:apple:true']);

    provider.toggleFavourite('milk');
    await pumpEventQueue();
    expect(store.writes.last, 'customer-1:milk:false');
  });

  test('a rejected favourite write is rolled back', () async {
    final store = _Store()..fail = true;
    final provider = ProductProvider(
      source: Stream.value(products),
      store: store,
    );
    addTearDown(provider.dispose);
    addTearDown(store.ids.close);
    await pumpEventQueue();
    provider.bindUser('customer-1');

    provider.toggleFavourite('apple');
    expect(provider.isFavourite('apple'), isTrue);
    await pumpEventQueue();
    expect(provider.isFavourite('apple'), isFalse);
  });
}
