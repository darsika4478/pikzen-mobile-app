'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { validateInput, provision, SetupError } = require('./create_privileged_user');

const input = (role = 'shop') => ({
  email: 'operator@example.com', fullName: 'Example Operator',
  phone: '+94770000000', role, password: randomBytes(18).toString('hex'),
});
function fake({ existingUser = false, profile, race = false, failWrite = false,
  lookupCode, createCode } = {}) {
  const user = { uid: 'test-uid', email: 'operator@example.com' };
  const saved = { ...(profile ?? {}) };
  const calls = { lookups: 0, creates: [], writes: 0, collection: null, doc: null };
  const deps = {
    auth: {
      async getUserByEmail() {
        calls.lookups++;
        if (lookupCode) throw { code: lookupCode };
        if (!existingUser && !(race && calls.lookups > 1)) throw { code: 'auth/user-not-found' };
        return user;
      },
      async createUser(fields) {
        calls.creates.push(fields);
        if (createCode) throw { code: createCode };
        if (race) throw { code: 'auth/email-already-exists' };
        return user;
      },
      async deleteUser() { assert.fail('Must never delete an account'); },
      async updateUser() { assert.fail('Must never change an existing password'); },
    },
    db: {
      collection(name) {
        calls.collection = name;
        return { doc(uid) { calls.doc = uid; return { uid }; } };
      },
      async runTransaction(fn) {
        if (failWrite) throw new Error('sensitive SDK diagnostic must not escape');
        return fn({
          async get() { return { exists: profile !== undefined, data: () => profile }; },
          set(ref, fields, options) {
            assert.equal(ref.uid, user.uid);
            assert.deepEqual(options, { merge: true });
            calls.writes++;
            Object.assign(saved, fields);
          },
        });
      },
    },
    serverTimestamp: () => 'SERVER_TIMESTAMP',
  };
  return { deps, calls, saved };
}

test('only shop/admin roles accepted and normalized; all required fields validated', () => {
  for (const role of ['shop', 'admin', ' ADMIN ']) {
    assert.equal(validateInput(input(role)).role, role.trim().toLowerCase());
  }
  for (const role of ['customer', '', 'owner', 'superadmin']) {
    assert.throws(() => validateInput(input(role)), SetupError);
  }
  for (const changes of [
    { email: '' }, { email: 'bad@' }, { email: 'bad@example' },
    { password: '' }, { password: 'short' }, { fullName: ' ' }, { phone: 123 },
  ]) assert.throws(() => validateInput({ ...input(), ...changes }), SetupError);
});

test('new account uses Auth UID; profile is exact schema without password', async () => {
  const f = fake();
  const value = input();
  const result = await provision(value, f.deps);
  assert.equal(f.calls.creates.length, 1);
  assert.equal(f.calls.creates[0].password, value.password);
  assert.equal(f.calls.collection, 'users');
  assert.equal(f.calls.doc, 'test-uid');
  assert.deepEqual(Object.keys(f.saved).sort(),
    ['uid', 'fullName', 'email', 'phone', 'role', 'createdAt', 'approvalStatus'].sort());
  assert.equal(f.saved.createdAt, 'SERVER_TIMESTAMP');
  assert.equal(f.saved.role, 'shop');
  assert.equal(result.auth, 'created');
  assert.equal(result.profile, 'created');
  assert.equal(JSON.stringify(result).includes(value.password), false);
});

test('existing account retains password and profile creation date/unrelated fields', async () => {
  const f = fake({ existingUser: true, profile: {
    createdAt: 'ORIGINAL', unrelated: { keep: true }, phone: '0771234567', role: 'customer',
  } });
  const result = await provision({ ...input('admin'), phone: '' }, f.deps);
  assert.equal(f.calls.creates.length, 0);
  assert.equal(f.saved.createdAt, 'ORIGINAL');
  assert.deepEqual(f.saved.unrelated, { keep: true });
  assert.equal(f.saved.phone, '0771234567');
  assert.equal(f.saved.role, 'admin');
  assert.equal(result.auth, 'already existed');
  assert.equal(result.profile, 'updated');
});

test('existing Auth without profile gets profile and empty string phone', async () => {
  const f = fake({ existingUser: true });
  const result = await provision({ ...input(), phone: undefined }, f.deps);
  assert.equal(result.profile, 'created');
  assert.equal(f.saved.phone, '');
  assert.equal(f.calls.creates.length, 0);
});

test('existing profile missing timestamp receives one; supplied phone updates', async () => {
  const f = fake({ existingUser: true, profile: { other: 1, phone: 'old' } });
  await provision(input(), f.deps);
  assert.equal(f.saved.createdAt, 'SERVER_TIMESTAMP');
  assert.equal(f.saved.phone, '+94770000000');
  assert.equal(f.saved.other, 1);
});

test('concurrent account creation reuses existing UID', async () => {
  const f = fake({ race: true });
  const result = await provision(input(), f.deps);
  assert.equal(f.calls.lookups, 2);
  assert.equal(result.auth, 'already existed');
  assert.equal(f.calls.doc, 'test-uid');
});

test('invalid inputs never call Firebase; auth failures never write profiles', async () => {
  const f = fake();
  await assert.rejects(provision(input('customer'), f.deps), SetupError);
  assert.equal(f.calls.lookups, 0);
  for (const options of [
    { lookupCode: 'auth/insufficient-permission' },
    { createCode: 'auth/password-does-not-meet-requirements' },
  ]) {
    const failed = fake(options);
    await assert.rejects(provision(input(), failed.deps), /Authentication lookup\/create failed/);
    assert.equal(failed.calls.writes, 0);
  }
});

test('profile failure is sanitized and preserves Auth for safe retry', async () => {
  const f = fake({ failWrite: true });
  await assert.rejects(provision(input(), f.deps), (error) => {
    assert.match(error.message, /rerun/);
    assert.doesNotMatch(error.message, /sensitive SDK diagnostic/);
    return true;
  });
  assert.equal(f.calls.creates.length, 1);
});

test('CLI validation fails safely without SDK calls or password output', () => {
  const value = input('customer');
  const result = spawnSync(process.execPath, [require.resolve('./create_privileged_user')], {
    encoding: 'utf8',
    env: {
      ...process.env, GOOGLE_CLOUD_PROJECT: 'offline-test-project',
      PIKZEN_EMAIL: value.email, PIKZEN_FULL_NAME: value.fullName,
      PIKZEN_PHONE: '', PIKZEN_ROLE: value.role, PIKZEN_PASSWORD: value.password,
    },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Role must be shop or admin/);
  assert.equal((result.stdout + result.stderr).includes(value.password), false);
});


test('shops default pending; approval requires an explicit trusted operator choice', async () => {
  const pending = fake();
  await provision(input('shop'), pending.deps);
  assert.equal(pending.saved.approvalStatus, 'pending');
  const approved = fake();
  await provision({ ...input('shop'), approvalStatus: 'approved' }, approved.deps);
  assert.equal(approved.saved.approvalStatus, 'approved');
  assert.throws(() => validateInput({ ...input('shop'), approvalStatus: 'unknown' }), SetupError);
  assert.throws(() => validateInput({ ...input('admin'), approvalStatus: 'approved' }), SetupError);
  const admin = fake();
  await provision(input('admin'), admin.deps);
  assert.equal('approvalStatus' in admin.saved, false);
});
