const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '../..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

test('every exported callable enforces App Check', () => {
  const source = read('functions/src/index.js');
  const callableExports = [...source.matchAll(/exports\.([A-Za-z0-9_]+)\s*=\s*(appCheckedCallable|callable|onCall)\s*\(/g)];
  assert.ok(callableExports.length > 0);
  for (const [, name, wrapper] of callableExports) {
    assert.notEqual(wrapper, 'callable', `${name} must use App Check`);
    if (wrapper === 'onCall') {
      const declaration = source.slice(callableExports.find(match => match[1] === name).index);
      assert.match(declaration.slice(0, 220), /enforceAppCheck:\s*true/,
        `${name} raw onCall must enforce App Check`);
    }
  }
  assert.match(source, /region:\s*REGION,\s*enforceAppCheck:\s*true/);
  assert.doesNotMatch(source, /function callable\(/);
});

test('release App Check providers stay attested and startup requires a token', () => {
  const mobile = [
    'hominode-admin/admin_app/lib/main.dart',
    'resident_app/lib/main.dart',
    'security_app/lib/main.dart',
  ].map(read);
  for (const source of mobile) {
    assert.match(source, /AndroidProvider\.playIntegrity/);
    assert.match(source, /AppleProvider\.appAttest/);
    assert.match(source, /getToken\(\)/);
    assert.doesNotMatch(source, /getToken\(true\)/);
    assert.match(source, /(?:appCheckToken|token) == null \|\| (?:appCheckToken|token)\.isEmpty/);
    assert.doesNotMatch(source, /APP CHECK TOKEN AVAILABLE/);
  }
  assert.doesNotMatch(
    read('resident_app/lib/src/services/firebase_auth_service.dart'),
    /appVerificationDisabledForTesting/,
  );
});

test('Admin, Resident and Security authentication remain bound to phone identity', () => {
  const admin = read('hominode-admin/admin_app/lib/services/auth_service.dart');
  assert.match(admin, /await user\.getIdTokenResult\(\)/);
  assert.match(admin, /signInProvider: tokenResult\.signInProvider/);
  assert.doesNotMatch(admin, /user\.providerData/);
  assert.match(admin, /profile\.uid != user\.uid/);
  assert.match(admin, /doc\.data\(\)!\['uid'\] != user\.uid/);
  assert.match(admin, /profile\.phoneNumber != user\.phoneNumber/);
  assert.match(admin, /profile\.isActive/);

  const resident = read('resident_app/lib/src/services/firebase_auth_service.dart');
  assert.match(resident, /await user\.getIdTokenResult\(\)/);
  assert.match(resident, /signInProvider: tokenResult\.signInProvider/);
  assert.doesNotMatch(resident, /user\.providerData/);
  assert.match(resident, /profile\.userId != uid/);
  assert.match(resident, /profile\.phoneNumber\.trim\(\) != phone\.trim\(\)/);
  assert.match(resident, /registrationRequired/);

  const security = read('security_app/lib/services/auth_service.dart');
  assert.match(security, /await user\.getIdTokenResult\(\)/);
  assert.match(security, /signInProvider: tokenResult\.signInProvider/);
  assert.doesNotMatch(security, /user\.providerData/);
  assert.match(security, /matchesVerifiedPhone\(/);
  assert.match(security, /await _safeSignOut\(\);/);
});

test('client callable boundary requires verified Phone Auth except the classified public resolver', async () => {
  const source = read('functions/src/index.js');
  const auth = read('functions/src/phone_auth.js');
  assert.match(auth, /auth\?\.uid/);
  assert.match(auth, /token\?\.phone_number/);
  assert.match(auth, /sign_in_provider === "phone"/);
  assert.match(source, /function requirePhoneAuth\(auth\)/);
  assert.match(source, /requirePhoneAuth\(request\.auth\)/);
  assert.match(source, /requirePhoneAuth: !allowUnauthenticated/);
  assert.match(source, /if \(requirePhone\) requirePhoneAuth\(request\.auth\)/);
  assert.match(source, /hasCanonicalPhoneProfile\(db, request\.auth\)/);
  assert.match(source, /requireCanonicalPhoneProfile: !allowUnauthenticated && !allowProfilelessPhoneAuth/);
  assert.match(source, /exports\.resolveResidentCommunity = appCheckedCallable\([\s\S]*?\{ allowUnauthenticated: true \}/);
  assert.equal((source.match(/allowUnauthenticated: true/g) || []).length, 1);
  assert.match(source, /exports\.registerResident = appCheckedCallable\([\s\S]*?\{ allowProfilelessPhoneAuth: true \}/);

  const {hasVerifiedPhoneAuth, hasCanonicalPhoneProfile} = require('../src/phone_auth');
  const token = provider => ({
    uid: 'actor-1',
    token: {phone_number: '+639171234567', firebase: {sign_in_provider: provider}},
  });
  assert.equal(hasVerifiedPhoneAuth(token('phone')), true);
  for (const provider of ['password', 'custom', 'anonymous']) {
    assert.equal(hasVerifiedPhoneAuth(token(provider)), false);
  }
  assert.equal(hasVerifiedPhoneAuth({...token('phone'), token: {firebase: {sign_in_provider: 'phone'}}}), false);
  assert.equal(hasVerifiedPhoneAuth({...token('phone'), uid: ''}), false);

  const fakeDb = entries => ({
    collection: name => ({
      doc: uid => ({
        get: async () => ({exists: Boolean(entries[name]), data: () => entries[name]}),
      }),
    }),
  });
  const claims = token('phone');
  assert.equal(await hasCanonicalPhoneProfile(fakeDb({
    users: {uid: 'actor-1', role: 'resident', phoneNumber: '+639171234567'},
  }), claims), true);
  assert.equal(await hasCanonicalPhoneProfile(fakeDb({
    users: {uid: 'actor-1', role: 'resident', phoneNumber: '+639170000000'},
  }), claims), false);
  assert.equal(await hasCanonicalPhoneProfile(fakeDb({
    users: {uid: 'actor-1', role: 'resident'},
  }), claims), false);
  assert.equal(await hasCanonicalPhoneProfile(fakeDb({}), claims), false);

  for (const name of [
    'searchCommunityLocations',
    'resolveCommunityLocationPlace',
    'reverseGeocodeCommunityLocation',
  ]) {
    const declaration = source.slice(source.indexOf(`exports.${name} =`));
    assert.match(declaration.slice(0, 700), /requirePhoneAuth\(request\.auth\)/);
    assert.match(declaration.slice(0, 900), /hasCanonicalPhoneProfile\(db, request\.auth\)/);
  }
});

test('Firestore and Storage bind phone claims to canonical profiles', () => {
  const firestore = read('firestore.rules');
  assert.match(firestore, /function phoneMatchesProfile\(profile\)/);
  assert.match(firestore, /request\.auth\.token\.phone_number == profile\.phoneNumber/);
  for (const helper of ['validAdmin', 'validSuperAdmin', 'approvedResident', 'validSecurity']) {
    const match = firestore.match(new RegExp(`function ${helper}\\([^)]*\\) \\{([\\s\\S]*?)\\n\\s*\\}`));
    assert.ok(match, `missing ${helper}`);
    assert.match(match[1], /phoneMatchesProfile\(/, `${helper} must bind phone to profile`);
  }
  const storage = read('storage.rules');
  assert.match(storage, /function phoneMatchesProfile\(profile\)/);
  assert.match(storage, /request\.auth\.token\.firebase\.sign_in_provider == 'phone'/);
  assert.match(storage, /request\.auth\.token\.phone_number == profile\.phoneNumber/);
  assert.match(storage, /residentMayAccessReceipt[\s\S]*?phoneMatchesProfile\(firestore\.get\(profilePath\)\.data\)/);
  assert.match(storage, /adminMayReadReceipt[\s\S]*?phoneMatchesProfile\(firestore\.get\(adminPath\)\.data\)/);
  assert.match(storage, /adminMayAccessCommunity[\s\S]*?phoneMatchesProfile\(firestore\.get\(adminPath\)\.data\)/);
  assert.match(storage, /residentMayAccessCommunity[\s\S]*?phoneMatchesProfile\(firestore\.get\(profilePath\)\.data\)/);
});

test('mobile startup does not force-refresh App Check and Resident auth logs omit secrets', () => {
  for (const file of [
    'hominode-admin/admin_app/lib/main.dart',
    'resident_app/lib/main.dart',
    'security_app/lib/main.dart',
  ]) {
    const source = read(file);
    assert.match(source, /FirebaseAppCheck\.instance\.getToken\(\)/);
    assert.doesNotMatch(source, /getToken\(true\)/);
  }
  const residentSources = [
    'resident_app/lib/main.dart',
    'resident_app/lib/src/services/tenant_resolution_service.dart',
    'resident_app/lib/src/services/firebase_auth_service.dart',
    'resident_app/lib/src/models/tenant_profile.dart',
  ].map(read).join('\n');
  assert.doesNotMatch(residentSources, /STARTUP AUTH UID|STARTUP AUTH PHONE/);
  assert.doesNotMatch(residentSources, /debugPrint\([\s\S]{0,180}(?:user\.uid|phoneNumber|currentUser\?\.uid|error\.message)/);
  assert.doesNotMatch(residentSources, /debugPrint\([^\n]*\$e\)/);
  assert.doesNotMatch(residentSources, /debugPrintStack\(/);
});

test('Firestore and Storage authority helpers require Phone Auth', () => {
  const firestore = read('firestore.rules');
  for (const helper of ['validAdmin', 'validSuperAdmin', 'approvedResident', 'validSecurity']) {
    const match = firestore.match(new RegExp(`function ${helper}\\([^)]*\\) \\{([\\s\\S]*?)\\n\\s*\\}`));
    assert.ok(match, `missing ${helper}`);
    assert.match(match[1], /phoneMatchesProfile\(/, `${helper} must match token phone to the profile`);
  }
  assert.match(firestore, /approvedResidentProfile\(profile\)\s*\{\s*\/\/ Profile eligibility only; every caller is wrapped by approvedResident\(\),/);
  const storage = read('storage.rules');
  assert.doesNotMatch(storage, /function phoneAuthenticated\(\)/);
});

test('role-sensitive geocoding callables validate trusted App Check app context', () => {
  const source = read('functions/src/index.js');
  assert.match(source, /function requireAdminAppContext\(app\)/);
  assert.match(source, /APP_CONTEXTS\[app\?\.appId\]/);
  for (const name of [
    'searchCommunityLocations',
    'resolveCommunityLocationPlace',
    'reverseGeocodeCommunityLocation',
  ]) {
    const declaration = source.slice(source.indexOf(`exports.${name} =`));
    assert.match(declaration.slice(0, 260), /enforceAppCheck:\s*true/);
    assert.match(declaration.slice(0, 500), /requireAdminAppContext\(request\.app\)/);
    assert.match(declaration.slice(0, 1000), /app:\s*request\.app/);
  }
});


test('active mobile auth entry points and callable boundaries omit raw error details', () => {
  const files = [
    'hominode-admin/admin_app/lib/services/auth_service.dart',
    'hominode-admin/admin_app/lib/admin_login_screen.dart',
    'hominode-admin/admin_app/lib/main.dart',
    'resident_app/lib/src/screens/simple_login_screen.dart',
    'security_app/lib/main.dart',
  ];
  for (const file of files) {
    const source = read(file);
    assert.doesNotMatch(source, /debugPrint\([^\n]*\$(?:e|error)(?:['"),; ]|$)/, file);
    assert.doesNotMatch(source, /debugPrint\([^\n]*\$\{(?:e|error)\.message\}/, file);
    assert.doesNotMatch(source, /debugPrint\([^\n]*\$\{result\.message\}/, file);
  }
  assert.doesNotMatch(read('functions/src/index.js'), /console\.error\([^\n]*, error\)/);
});
