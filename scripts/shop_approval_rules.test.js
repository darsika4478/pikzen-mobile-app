'use strict';
const { test, before } = require('node:test');
const assert = require('node:assert/strict');

// Fixed local emulator + demo project only: this file cannot target production.
const project = 'demo-pikzen-approval';
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8087';
const base = 'http://' + host + '/v1/projects/' + project + '/databases/(default)/documents';
function token(uid) {
  const encode = v => Buffer.from(JSON.stringify(v)).toString('base64url');
  return encode({ alg: 'none', typ: 'JWT' }) + '.' + encode({
    sub: uid, user_id: uid, email: uid + '@example.com',
    aud: project, iss: 'https://securetoken.google.com/' + project,
    iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  }) + '.';
}
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) =>
    [key, value === null ? { nullValue: null } : { stringValue: value }]));
}
async function write(actor, uid, data, { create = false, privileged = false } = {}) {
  const update = { name: base.slice(base.indexOf('projects/')) + '/users/' + uid, fields: fields(data) };
  const entry = { update };
  if (create) {
    entry.currentDocument = { exists: false };
    entry.updateTransforms = [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }];
  } else {
    entry.updateMask = { fieldPaths: Object.keys(data) };
    entry.currentDocument = { exists: true };
  }
  const response = await fetch(base + ':commit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + (privileged ? 'owner' : token(actor)) },
    body: JSON.stringify({ writes: [entry] }),
  });
  return { status: response.status, body: await response.json() };
}
const profile = (uid, role, approvalStatus) => ({
  uid, fullName: 'Example User', email: uid + '@example.com', phone: '',
  role, ...(approvalStatus === undefined ? {} : { approvalStatus }),
});
async function allowed(promise) {
  const result = await promise;
  assert.equal(result.status, 200, JSON.stringify(result.body));
}
async function denied(promise) {
  const result = await promise;
  assert.equal(result.status, 403, JSON.stringify(result.body));
}
before(async () => {
  await allowed(write('admin', 'admin', profile('admin', 'admin'), { create: true, privileged: true }));
});
test('own customer and pending-shop registration succeed', async () => {
  await allowed(write('customer', 'customer', profile('customer', 'customer'), { create: true }));
  await allowed(write('shop', 'shop', profile('shop', 'shop', 'pending'), { create: true }));
});
test('public admin, approved/rejected shop, customer approval field, wrong owner denied', async () => {
  for (const [uid, role, approval] of [
    ['badadmin', 'admin', undefined], ['badapproved', 'shop', 'approved'],
    ['badrejected', 'shop', 'rejected'], ['badmissing', 'shop', undefined],
    ['badcustomer', 'customer', 'approved'],
  ]) await denied(write(uid, uid, profile(uid, role, approval), { create: true }));
  await denied(write('attacker', 'other', profile('other', 'shop', 'pending'), { create: true }));
});
test('customers/shops cannot change role or self-approve; normal own edits survive', async () => {
  await denied(write('shop', 'shop', { approvalStatus: 'approved' }));
  await denied(write('shop', 'shop', { approvalStatus: 'rejected' }));
  await denied(write('shop', 'shop', { role: 'admin' }));
  await denied(write('customer', 'customer', { role: 'shop', approvalStatus: 'pending' }));
  await denied(write('customer', 'shop', { approvalStatus: 'approved' }));
  await allowed(write('shop', 'shop', { fullName: 'Updated Name', phone: '+94771234567' }));
  await denied(write('shop', 'shop', { shopName: 'Orchard Shop' }));
  await denied(write('customer', 'customer', { shopName: 'Not a shop' }));
});
test('admin can approve/reject only pending shops and only the approval field', async () => {
  await denied(write('admin', 'shop', { approvalStatus: 'approved', role: 'admin' }));
  await denied(write('admin', 'shop', { approvalStatus: 'unknown' }));
  await denied(write('admin', 'customer', { approvalStatus: 'approved' }));
  await allowed(write('admin', 'shop', { approvalStatus: 'approved' }));
  await allowed(write('shop', 'shop', { shopName: 'Orchard Shop', storeAddress: 'Main Street' }));
  await denied(write('admin', 'shop', { approvalStatus: 'rejected' }));
  await allowed(write('rejectshop', 'rejectshop', profile('rejectshop', 'shop', 'pending'), { create: true }));
  await allowed(write('admin', 'rejectshop', { approvalStatus: 'rejected' }));
});
test('legacy shop is not implicitly approved; only trusted migration can add its state', async () => {
  await allowed(write('legacy', 'legacy', profile('legacy', 'shop'), { create: true, privileged: true }));
  await denied(write('legacy', 'legacy', { approvalStatus: 'approved' }));
  await denied(write('admin', 'legacy', { approvalStatus: 'approved' }));
});
test('only admins can query pending shops', async () => {
  for (const actor of ['admin', 'shop', 'customer']) {
    const response = await fetch(base + ':runQuery', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token(actor) },
      body: JSON.stringify({ structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: { compositeFilter: { op: 'AND', filters: [
          { fieldFilter: { field: { fieldPath: 'role' }, op: 'EQUAL', value: { stringValue: 'shop' } } },
          { fieldFilter: { field: { fieldPath: 'approvalStatus' }, op: 'EQUAL', value: { stringValue: 'pending' } } },
        ] } },
      } }),
    });
    assert.equal(response.status, actor === 'admin' ? 200 : 403, await response.text());
  }
});


test('shared products require approved ownership and nonnegative stock/price', async () => {
  async function productWrite(actor, data, create = false) {
    const productFields = Object.fromEntries(Object.entries(data).map(([key, value]) =>
      [key, typeof value === 'number' ? { integerValue: String(value) }
        : typeof value === 'boolean' ? { booleanValue: value }
        : { stringValue: value }]));
    const entry = {
      update: { name: base.slice(base.indexOf('projects/')) + '/products/test-product', fields: productFields },
      currentDocument: { exists: !create },
    };
    if (create) {
      entry.updateTransforms = [
        { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
        { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
      ];
    } else {
      entry.updateMask = { fieldPaths: Object.keys(data) };
      entry.updateTransforms = [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }];
    }
    const response = await fetch(base + ':commit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token(actor) },
      body: JSON.stringify({ writes: [entry] }),
    });
    return { status: response.status, body: await response.json() };
  }
  const product = { name: 'Apples', category: 'Fruits', shopId: 'shop', priceMinor: 95000, stockQuantity: 25, isActive: true };
  await denied(productWrite('customer', product, true));
  await denied(productWrite('rejectshop', { ...product, shopId: 'rejectshop' }, true));
  await allowed(productWrite('shop', product, true));
  await denied(productWrite('customer', { stockQuantity: 100 }));
  await denied(productWrite('shop', { shopId: 'customer' }));
  await denied(productWrite('shop', { stockQuantity: -1 }));
  await allowed(productWrite('shop', { stockQuantity: 5, priceMinor: 99000 }));
  await allowed(productWrite('shop', { isActive: false }));
  await denied(productWrite('shop', { isActive: true }));
});

