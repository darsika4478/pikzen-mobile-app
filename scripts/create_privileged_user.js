'use strict';

// Local operator utility only. Never import this file into Flutter.
const readline = require('node:readline');
const { Writable } = require('node:stream');

class SetupError extends Error {}

function validateInput(input) {
  const email = (input.email ?? '').trim();
  const fullName = (input.fullName ?? '').trim();
  const role = (input.role ?? '').trim().toLowerCase();
  const password = input.password ?? '';
  if (!/^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$/.test(email)) {
    throw new SetupError('Enter a valid email address.');
  }
  if (!fullName) throw new SetupError('Full name is required.');
  if (!['shop', 'admin'].includes(role)) {
    throw new SetupError('Role must be shop or admin; customer is not allowed.');
  }
  if (typeof password !== 'string' || password.length < 8) {
    throw new SetupError('Password must contain at least 8 characters.');
  }
  if (input.phone != null && typeof input.phone !== 'string') {
    throw new SetupError('Phone must be a string.');
  }
  const approvalStatus = role === 'shop'
    ? (input.approvalStatus?.trim().toLowerCase() || 'pending') : undefined;
  if (role === 'shop' && !['pending', 'approved'].includes(approvalStatus)) {
    throw new SetupError('Script-created shops must explicitly use pending or approved; default is pending.');
  }
  if (role === 'admin' && input.approvalStatus?.trim()) {
    throw new SetupError('Approval status applies only to shop accounts.');
  }
  return {
    email, fullName, role, password, approvalStatus,
    phone: input.phone?.trim() || undefined,
  };
}

// Dependencies are injected for offline tests; no Firebase calls on import.
async function provision(input, { auth, db, serverTimestamp }) {
  const data = validateInput(input);
  let user;
  let authStatus = 'already existed';
  try {
    try {
      user = await auth.getUserByEmail(data.email);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      try {
        user = await auth.createUser({
          email: data.email,
          password: data.password,
          displayName: data.fullName,
        });
        authStatus = 'created';
      } catch (createError) {
        // Another operator may have created this account after the lookup.
        if (createError.code !== 'auth/email-already-exists') throw createError;
        user = await auth.getUserByEmail(data.email);
      }
    }
  } catch (_) {
    throw new SetupError(
      'Authentication lookup/create failed. Check Admin credentials, project, permissions, and password policy.',
    );
  } finally {
    data.password = undefined;
  }

  let profileStatus;
  try {
    const ref = db.collection('users').doc(user.uid);
    profileStatus = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const existing = snapshot.exists ? snapshot.data() : {};
      const fields = {
        uid: user.uid,
        fullName: data.fullName,
        email: user.email || data.email,
        role: data.role,
      };
      if (data.role === 'shop') fields.approvalStatus = data.approvalStatus;
      if (data.phone !== undefined || !snapshot.exists || !('phone' in existing)) {
        fields.phone = data.phone ?? '';
      }
      if (existing.createdAt == null) fields.createdAt = serverTimestamp();
      transaction.set(ref, fields, { merge: true });
      return snapshot.exists ? 'updated' : 'created';
    });
  } catch (_) {
    // Auth and Firestore cannot share an atomic transaction. Never delete users.
    throw new SetupError(
      'Firestore profile setup failed. The Authentication account may already exist. Check Firestore permissions/configuration, then rerun; existing passwords are not changed.',
    );
  }
  return {
    email: user.email || data.email,
    uid: user.uid,
    role: data.role,
    ...(data.role === 'shop' ? { approvalStatus: data.approvalStatus } : {}),
    auth: authStatus,
    profile: profileStatus,
  };
}

async function readInputs(env = process.env) {
  let rl;
  let muted = false;
  const output = new Writable({
    write(chunk, encoding, done) {
      if (!muted) process.stdout.write(chunk, encoding);
      done();
    },
  });
  async function ask(variable, label, secret = false, optional = false) {
    if (env[variable] !== undefined) return env[variable];
    if (!process.stdin.isTTY || !process.stdout.isTTY) {
      if (optional) return '';
      throw new SetupError('Missing input. Run in an interactive terminal or supply PIKZEN_* environment variables.');
    }
    rl ??= readline.createInterface({
      input: process.stdin, output, terminal: true, historySize: 0,
    });
    process.stdout.write(label);
    muted = secret;
    try {
      return await new Promise((resolve, reject) => {
        const cancel = () => { cleanup(); reject(new SetupError('Setup cancelled.')); };
        const cleanup = () => {
          rl.removeListener('SIGINT', cancel);
          rl.removeListener('close', cancel);
        };
        rl.once('SIGINT', cancel);
        rl.once('close', cancel);
        rl.question('', (answer) => { cleanup(); resolve(answer); });
      });
    } finally {
      muted = false;
      if (secret) process.stdout.write('\n');
    }
  }
  try {
    const role = await ask('PIKZEN_ROLE', 'Role (admin; shop for trusted/demo setup): ');
    const approvalStatus = role.trim().toLowerCase() === 'shop'
      ? await ask('PIKZEN_APPROVAL_STATUS', 'Shop approval (pending/approved; blank = pending): ', false, true)
      : env.PIKZEN_APPROVAL_STATUS;
    return {
      approvalStatus,
      email: await ask('PIKZEN_EMAIL', 'Email: '),
      fullName: await ask('PIKZEN_FULL_NAME', 'Full name: '),
      phone: await ask('PIKZEN_PHONE', 'Phone (optional; blank preserves existing): ', false, true),
      role,
      password: await ask('PIKZEN_PASSWORD', 'Password (hidden; ignored for existing accounts): ', true),
    };
  } finally {
    rl?.close();
    // Avoid passing the supplied secret to any subsequently spawned process.
    delete env.PIKZEN_PASSWORD;
  }
}

async function main() {
  let app;
  let input;
  try {
    if (process.argv.length > 2) {
      throw new SetupError('Use interactive prompts or environment variables, not command-line arguments.');
    }
    const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
    if (!projectId) throw new SetupError('Set GOOGLE_CLOUD_PROJECT to your intended Firebase project ID.');
    input = validateInput(await readInputs());
    let sdk;
    let auth;
    let db;
    let FieldValue;
    try {
      sdk = require('firebase-admin/app');
      ({ FieldValue } = require('firebase-admin/firestore'));
      app = sdk.initializeApp({ credential: sdk.applicationDefault(), projectId });
      auth = require('firebase-admin/auth').getAuth(app);
      db = require('firebase-admin/firestore').getFirestore(app);
    } catch (_) {
      throw new SetupError('Firebase Admin initialization failed. Install dependencies and configure Application Default Credentials.');
    }
    const result = await provision(input, {
      auth, db, serverTimestamp: () => FieldValue.serverTimestamp(),
    });
    // Explicit allowlist only: never log SDK objects, inputs, errors, or secrets.
    console.log([
      'Privileged user setup complete',
      'Email: ' + result.email,
      'UID: ' + result.uid,
      'Role: ' + result.role,
      ...(result.approvalStatus ? ['Approval: ' + result.approvalStatus] : []),
      'Auth: ' + result.auth,
      'Firestore profile: ' + result.profile,
    ].join('\n'));
  } catch (error) {
    console.error(error instanceof SetupError
      ? error.message
      : 'Setup failed. Check local configuration and retry.');
    process.exitCode = 1;
  } finally {
    if (input) input.password = undefined;
    delete process.env.PIKZEN_PASSWORD;
    if (app) {
      try { await require('firebase-admin/app').deleteApp(app); }
      catch (_) { /* No raw SDK errors or credentials are logged. */ }
    }
  }
}

if (require.main === module) void main();
module.exports = { validateInput, provision, SetupError };

