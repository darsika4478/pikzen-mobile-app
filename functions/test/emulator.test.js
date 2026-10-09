'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { placeOrderCore, cancelOrderCore } = require('../lib/orders');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test.skip('Firestore emulator integration requires FIRESTORE_EMULATOR_HOST', () => {});
} else {
  if (!getApps().length) initializeApp({ projectId: 'demo-pikzen-orders' });
  const db = getFirestore();

  async function fixture(stock = 5) {
    const suffix = randomUUID();
    const customer = `customer-${suffix}`;
    const shop = `shop-${suffix}`;
    const product = `product-${suffix}`;
    await Promise.all([
      db.doc(`users/${customer}`).set({ role: 'customer' }),
      db.doc(`users/${shop}`).set({ role: 'shop', approvalStatus: 'approved' }),
      db.doc(`products/${product}`).set({
        name: 'Red Apples', shopId: shop, priceMinor: 45000,
        currencyCode: 'LKR', stockQuantity: stock, isActive: true,
      }),
    ]);
    const orderId = `order-${randomUUID()}`;
    const request = {
      orderId, items: [{ productId: product, quantity: 3 }],
      pickupAtMillis: Date.now() + 86400000,
      replacementPreference: 'contactMe', paymentMethod: 'card',
    };
    return { customer, shop, product, request };
  }

  test('real Firestore transaction deducts once and restores once', async () => {
    const { customer, product, request } = await fixture();
    await placeOrderCore(db, customer, request);
    await placeOrderCore(db, customer, request);
    assert.equal((await db.doc(`products/${product}`).get()).get('stockQuantity'), 2);
    const order = await db.doc(`orders/${request.orderId}`).get();
    assert.equal(order.get('customerId'), customer);
    assert.equal(order.get('items')[0].unitPriceMinor, 45000);
    assert.equal(order.get('totalMinor'), 135000);
    await cancelOrderCore(db, customer, { orderId: request.orderId, reason: 'changedMind' });
    await cancelOrderCore(db, customer, { orderId: request.orderId, reason: 'changedMind' });
    assert.equal((await db.doc(`products/${product}`).get()).get('stockQuantity'), 5);
    assert.equal((await db.doc(`orders/${request.orderId}`).get()).get('stockRestored'), true);
  });

  test('concurrent requests cannot oversell stock', async () => {
    const { customer, product, request } = await fixture();
    const other = { ...request, orderId: `order-${randomUUID()}` };
    const results = await Promise.allSettled([
      placeOrderCore(db, customer, request), placeOrderCore(db, customer, other),
    ]);
    assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
    assert.equal(results.filter(result => result.status === 'rejected').length, 1);
    assert.equal((await db.doc(`products/${product}`).get()).get('stockQuantity'), 2);
  });
}
