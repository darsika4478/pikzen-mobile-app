'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { placeOrderCore, cancelOrderCore, rejectShopOrderCore } = require('../lib/orders');

class MemoryFirestore {
  constructor() {
    this.docs = new Map();
    this.failCommit = false;
  }
  collection(name) {
    return { doc: id => ({ path: `${name}/${id}`, id }) };
  }
  seed(path, value) { this.docs.set(path, { ...value }); }
  read(path) { return this.docs.get(path); }
  async runTransaction(callback) {
    const writes = [];
    const tx = {
      get: async ref => {
        const value = this.docs.get(ref.path);
        return {
          id: ref.id,
          exists: value !== undefined,
          data: () => value,
          get: key => value?.[key],
        };
      },
      create: (ref, value) => writes.push({ type: 'create', path: ref.path, value }),
      update: (ref, value) => writes.push({ type: 'update', path: ref.path, value }),
    };
    const result = await callback(tx);
    if (this.failCommit) throw Error('simulated transaction commit failure');
    const next = new Map(this.docs);
    for (const write of writes) {
      const previous = next.get(write.path);
      if (write.type === 'create' && previous) throw Error('document exists');
      if (write.type === 'update' && !previous) throw Error('document missing');
      next.set(write.path, write.type === 'create' ? { ...write.value } : { ...previous, ...write.value });
    }
    this.docs = next;
    return result;
  }
}

function setup() {
  const db = new MemoryFirestore();
  db.seed('users/customer', { role: 'customer' });
  db.seed('users/other', { role: 'customer' });
  db.seed('users/shop', { role: 'shop', approvalStatus: 'approved', shopName: 'Fresh Shop' });
  db.seed('users/shop2', { role: 'shop', approvalStatus: 'approved' });
  db.seed('users/admin', { role: 'admin' });
  db.seed('products/apple', { name: 'Red Apples', shopId: 'shop', priceMinor: 45000, stockQuantity: 20, currencyCode: 'LKR', isActive: true });
  db.seed('products/milk', { name: 'Milk', shopId: 'shop', priceMinor: 20000, stockQuantity: 5, currencyCode: 'LKR' });
  db.seed('products/bread', { name: 'Bread', shopId: 'shop2', priceMinor: 10000, stockQuantity: 4, currencyCode: 'LKR' });
  return db;
}

let sequence = 0;
function input(items = [{ productId: 'apple', quantity: 3 }]) {
  return {
    orderId: `order-${String(++sequence).padStart(4, '0')}`,
    items,
    pickupAtMillis: Date.now() + 86400000,
    replacementPreference: 'contactMe',
    paymentMethod: 'card',
  };
}

async function rejectsReason(action, reason) {
  await assert.rejects(action, error => error.details?.reason === reason);
}

test('authentication and customer role are required', async () => {
  const db = setup();
  await rejectsReason(() => placeOrderCore(db, undefined, input()), 'unauthenticated');
  await rejectsReason(() => placeOrderCore(db, 'shop', input()), 'not-customer');
  await rejectsReason(() => placeOrderCore(db, 'admin', input()), 'not-customer');
  await rejectsReason(() => placeOrderCore(db, 'missing', input()), 'not-customer');
  assert.equal(db.read('products/apple').stockQuantity, 20);
});

test('successful order uses authenticated UID and live prices, not forged client fields', async () => {
  const db = setup();
  const request = input();
  request.customerId = 'other';
  request.shopId = 'shop2';
  request.totalMinor = 1;
  request.items[0].unitPriceMinor = 1;
  request.items[0].productName = 'Forged';
  request.status = 'collected';
  request.paymentStatus = 'paid';
  const result = await placeOrderCore(db, 'customer', request);
  const order = db.read(`orders/${result.orderId}`);
  assert.equal(order.customerId, 'customer');
  assert.equal(order.shopId, 'shop');
  assert.equal(order.shopName, 'Fresh Shop');
  assert.equal(order.items[0].productName, 'Red Apples');
  assert.equal(order.items[0].unitPriceMinor, 45000);
  assert.equal(order.items[0].lineTotalMinor, 135000);
  assert.equal(order.subtotalMinor, 135000);
  assert.equal(order.totalMinor, 135000);
  assert.equal(order.paymentStatus, 'demo');
  assert.equal(order.status, 'placed');
  assert.equal(order.stockReserved, true);
  assert.equal(db.read('products/apple').stockQuantity, 17);
});

test('two-product order deducts both stocks once; retry returns same order', async () => {
  const db = setup();
  const request = input([{ productId: 'apple', quantity: 3 }, { productId: 'milk', quantity: 2 }]);
  await placeOrderCore(db, 'customer', request);
  await placeOrderCore(db, 'customer', request);
  assert.equal(db.read('products/apple').stockQuantity, 17);
  assert.equal(db.read('products/milk').stockQuantity, 3);
  assert.equal(db.read(`orders/${request.orderId}`).totalMinor, 175000);
  await rejectsReason(() => placeOrderCore(db, 'other', request), 'order-id-in-use');
  db.read(`orders/${request.orderId}`).status = 'cancelled';
  await rejectsReason(() => placeOrderCore(db, 'customer', request), 'order-id-in-use');
});

test('invalid products, quantities, stock, mixed shops and payment cannot mutate stock', async () => {
  const cases = [
    [input([{ productId: 'missing', quantity: 1 }]), 'product-not-found'],
    [input([{ productId: 'apple', quantity: 0 }]), 'invalid-quantity'],
    [input([{ productId: 'apple', quantity: -1 }]), 'invalid-quantity'],
    [input([{ productId: 'apple', quantity: 21 }]), 'insufficient-stock'],
    [input([{ productId: 'apple', quantity: 1 }, { productId: 'bread', quantity: 1 }]), 'mixed-shop-cart'],
  ];
  const inactive = setup();
  inactive.read('products/apple').isActive = false;
  await rejectsReason(() => placeOrderCore(inactive, 'customer', input()), 'product-inactive');
  for (const [request, reason] of cases) {
    const db = setup();
    await rejectsReason(() => placeOrderCore(db, 'customer', request), reason);
    assert.equal(db.read(`orders/${request.orderId}`), undefined);
    assert.equal(db.read('products/apple').stockQuantity, 20);
  }
  const badPayment = input();
  badPayment.paymentMethod = 'paid';
  await rejectsReason(() => placeOrderCore(setup(), 'customer', badPayment), 'invalid-payment-state');

  const unapproved = setup();
  unapproved.read('users/shop').approvalStatus = 'pending';
  await rejectsReason(() => placeOrderCore(unapproved, 'customer', input()), 'shop-unavailable');

  const corruptPrice = setup();
  corruptPrice.read('products/apple').priceMinor = -1;
  await rejectsReason(() => placeOrderCore(corruptPrice, 'customer', input()), 'invalid-product');
});

test('failed transaction leaves both products and order unchanged', async () => {
  const db = setup();
  db.failCommit = true;
  const request = input([{ productId: 'apple', quantity: 3 }, { productId: 'milk', quantity: 2 }]);
  await assert.rejects(() => placeOrderCore(db, 'customer', request));
  assert.equal(db.read(`orders/${request.orderId}`), undefined);
  assert.equal(db.read('products/apple').stockQuantity, 20);
  assert.equal(db.read('products/milk').stockQuantity, 5);
});

test('cash orders remain unpaid and invalid pickup data creates no order', async () => {
  const db = setup();
  const cash = input();
  cash.paymentMethod = 'cashOnPickup';
  await placeOrderCore(db, 'customer', cash);
  assert.equal(db.read(`orders/${cash.orderId}`).paymentStatus, 'unpaid');
  const invalid = input();
  invalid.pickupAtMillis = Date.now() - 1000;
  await rejectsReason(() => placeOrderCore(db, 'customer', invalid), 'invalid-pickup-data');
  assert.equal(db.read(`orders/${invalid.orderId}`), undefined);
});

test('customer cancellation restores reserved stock once and retains the order', async () => {
  const db = setup();
  const request = input();
  await placeOrderCore(db, 'customer', request);
  await rejectsReason(() => cancelOrderCore(db, 'other', { orderId: request.orderId, reason: 'changedMind' }), 'not-owner');
  assert.equal(db.read('products/apple').stockQuantity, 17);
  const result = await cancelOrderCore(db, 'customer', { orderId: request.orderId, reason: 'changedMind', note: 'No longer needed' });
  assert.equal(result.alreadyCancelled, false);
  assert.equal(db.read('products/apple').stockQuantity, 20);
  assert.equal(db.read(`orders/${request.orderId}`).status, 'cancelled');
  assert.equal(db.read(`orders/${request.orderId}`).stockRestored, true);
  assert.equal(db.read(`orders/${request.orderId}`).cancellationReason, 'changedMind');
  const repeated = await cancelOrderCore(db, 'customer', { orderId: request.orderId, reason: 'changedMind' });
  assert.equal(repeated.alreadyCancelled, true);
  assert.equal(db.read('products/apple').stockQuantity, 20);
});

test('failed cancellation transaction changes neither order nor stock', async () => {
  const db = setup();
  const request = input();
  await placeOrderCore(db, 'customer', request);
  db.failCommit = true;
  await assert.rejects(() => cancelOrderCore(db, 'customer', {
    orderId: request.orderId, reason: 'other',
  }));
  assert.equal(db.read('products/apple').stockQuantity, 17);
  assert.equal(db.read(`orders/${request.orderId}`).status, 'placed');
});

test('ready and collected orders cannot be cancelled; legacy unreserved orders do not add stock', async () => {
  for (const status of ['ready', 'collected']) {
    const db = setup();
    const request = input();
    await placeOrderCore(db, 'customer', request);
    db.read(`orders/${request.orderId}`).status = status;
    await rejectsReason(() => cancelOrderCore(db, 'customer', { orderId: request.orderId, reason: 'other' }), 'not-cancellable');
    assert.equal(db.read('products/apple').stockQuantity, 17);
  }
  const db = setup();
  db.seed('orders/legacy-order', { customerId: 'customer', shopId: 'shop', status: 'placed', items: [{ productId: 'apple', quantity: 3 }] });
  await cancelOrderCore(db, 'customer', { orderId: 'legacy-order', reason: 'other' });
  assert.equal(db.read('products/apple').stockQuantity, 20);
  assert.equal(db.read('orders/legacy-order').stockRestored, undefined);
});

test('shop rejection shares restoration and repeats safely', async () => {
  const db = setup();
  const request = input();
  await placeOrderCore(db, 'customer', request);
  assert.equal(db.read('products/apple').stockQuantity, 17);
  await rejectsReason(() => rejectShopOrderCore(db, 'shop2', { orderId: request.orderId }), 'not-owner');
  const result = await rejectShopOrderCore(db, 'shop', { orderId: request.orderId });
  assert.equal(result.alreadyCancelled, false);
  assert.equal(db.read('products/apple').stockQuantity, 20);
  assert.equal(db.read(`orders/${request.orderId}`).cancellationReason, 'shopRejected');
  await rejectShopOrderCore(db, 'shop', { orderId: request.orderId });
  assert.equal(db.read('products/apple').stockQuantity, 20);
});
