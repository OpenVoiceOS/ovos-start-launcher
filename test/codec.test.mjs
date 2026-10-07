// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import {
  COMPACT_ALPHABET, COMPACT_FIELDS, COMPACT_VERSION, RECIPE_TTL_SECONDS, MAX_RECIPE_TIMESTAMP,
  decodeRecipeCode, decodeRecipeEnvelope, encodeRecipeCode,
} from '../codec.mjs';

const NOW = 1700000000;
const BASE = Object.freeze({
  device: 'computer', experience: 'ready', locale: 'en-us', method: 'virtualenv',
  channel: 'testing', expertise: 'guided', speech: 'auto', memory: 'unknown',
  cpu: 'unknown', piModel: 'unknown', llmMode: 'off', extraSkills: false,
  telemetry: false, skills: true, homeassistant: false,
});
const VECTORS = [
  { name: 'computer-default', code: '4400-00G0-CN9Z-2055', header: 0x21000002, crc: 0xa5, state: BASE },
  { name: 'pi-local-french', code: '402J-K0G0-CN9Z-207V', header: 0x20052982, crc: 0xfb, state: { ...BASE, device: 'pi', locale: 'fr-fr', channel: 'alpha', speech: 'local', memory: '8plus', cpu: 'arm64', piModel: 'pi5' } },
  { name: 'mac-default', code: '4W0G-00G0-CN9Z-2057', header: 0x27010002, crc: 0xa7, state: { ...BASE, device: 'mac', channel: 'alpha' } },
  { name: 'windows-public-integrations', code: '5001-08R0-CN9Z-206W', header: 0x28001023, crc: 0xdc, state: { ...BASE, device: 'windows', speech: 'public', llmMode: 'online', homeassistant: true } },
  { name: 'container-hub', code: '4T10-00G0-CN9Z-202M', header: 0x26820002, crc: 0x54, state: { ...BASE, device: 'server', experience: 'hub', method: 'containers' } },
];

/** Encode with a fixed clock for deterministic field tests.
 * @param {object} state Recipe state. @returns {string} Compact code.
 */
function encode(state) { return encodeRecipeCode(state, { issuedAt: NOW }); }

/** Decode with a fixed clock for deterministic field tests.
 * @param {string} code Compact code. @returns {object} Recipe state.
 */
function decode(code) { return decodeRecipeCode(code, { now: NOW }); }

/** Convert a wire integer independently using division, not the codec's shifts.
 * @param {bigint} wire Unsigned 80-bit wire integer.
 * @returns {string} Ungrouped code.
 */
function wireCode(wire) {
  let code = '';
  for (let index = 0; index < 16; index += 1) {
    code = COMPACT_ALPHABET[Number(wire % 32n)] + code;
    wire /= 32n;
  }
  return code;
}

/** Independently divide the 80-bit message by the CRC polynomial.
 * @param {bigint} body Unsigned 72-bit header and timestamp.
 * @returns {number} CRC-8 remainder.
 */
function referenceChecksum(body) {
  let remainder = body << 8n;
  for (let bit = 79n; bit >= 8n; bit -= 1n) {
    if (remainder & (1n << bit)) remainder ^= 0x107n << (bit - 8n);
  }
  return Number(remainder);
}

/** Generate a valid-checksum wire code for negative semantic tests.
 * @param {number} header Unsigned 32-bit version and payload.
 * @returns {string} Ungrouped code.
 */
function headerCode(header) {
  const body = (BigInt(header) << 40n) | BigInt(NOW);
  return wireCode((body << 8n) | BigInt(referenceChecksum(body)));
}

test('frozen contract uses exactly 28 disjoint payload bits', async () => {
  const contract = JSON.parse(await readFile(new URL('../contract.json', import.meta.url), 'utf8'));
  const legacy = JSON.parse(await readFile(new URL('../contract-v1.json', import.meta.url), 'utf8'));
  assert.equal(contract.version, COMPACT_VERSION);
  assert.equal(contract.alphabet, COMPACT_ALPHABET);
  assert.deepEqual(contract.fields, COMPACT_FIELDS);
  assert.deepEqual(contract.fields, legacy.fields);
  assert.equal(contract.wireBits, 80);
  assert.equal(contract.codeCharacters, 16);
  assert.equal(contract.expiry.ttlSeconds, RECIPE_TTL_SECONDS);
  assert.deepEqual(contract.layout, [
    { name: 'version', width: 4, offset: 76 },
    { name: 'payload', width: 28, offset: 48 },
    { name: 'issuedAt', width: 40, offset: 8 },
    { name: 'checksum', width: 8, offset: 0 },
  ]);
  assert.equal(contract.checksum.polynomial, 7);
  assert.equal(contract.checksum.initial, 0);
  assert.equal(contract.checksum.xorOutput, 0);
  assert.equal(contract.checksum.reflectInput, false);
  assert.equal(contract.checksum.reflectOutput, false);
  assert.ok(Object.isFrozen(COMPACT_FIELDS));
  let offset = 28;
  for (const field of COMPACT_FIELDS) {
    offset -= field.width;
    assert.equal(field.offset, offset);
    assert.ok(Object.isFrozen(field));
    assert.ok(Object.isFrozen(field.values));
    assert.equal(new Set(field.values).size, field.values.length);
    assert.ok(field.values.length <= 2 ** field.width);
  }
  assert.equal(offset, 0);
  assert.deepEqual(contract.vectors, VECTORS.map(vector => ({
    name: vector.name, code: vector.code,
    headerHex: vector.header.toString(16).padStart(8, '0'),
    checksumHex: vector.crc.toString(16).padStart(2, '0'),
    issuedAt: NOW, expiresAt: NOW + 3600,
  })));
});

for (const vector of VECTORS) {
  test(`deterministic wire vector: ${vector.name}`, () => {
    const body = (BigInt(vector.header) << 40n) | BigInt(NOW);
    assert.equal(referenceChecksum(body), vector.crc);
    assert.equal(wireCode((body << 8n) | BigInt(vector.crc)), vector.code.replaceAll('-', ''));
    assert.equal(encode(vector.state), vector.code);
    assert.deepEqual(decode(vector.code), vector.state);
    assert.deepEqual(decode(vector.code.toLowerCase()), vector.state);
    assert.deepEqual(decode(vector.code.replaceAll('-', '')), vector.state);
    assert.deepEqual(decode(vector.code.toLowerCase().replaceAll('-', '')), vector.state);
  });
}

for (const field of COMPACT_FIELDS) {
  test(`round-trip every typed ${field.name} value`, () => {
    for (const value of field.values) {
      const state = Object.freeze({ ...BASE, [field.name]: value });
      const code = encode(state);
      assert.match(code, /^[0-9A-HJKMNP-TV-Z]{4}(?:-[0-9A-HJKMNP-TV-Z]{4}){3}$/);
      assert.deepEqual(decode(code), state);
    }
  });
}

test('codec leaves cross-field validation to consumers', () => {
  const state = Object.fromEntries(COMPACT_FIELDS.map(field => [field.name, field.values.at(-1)]));
  assert.deepEqual(decode(encode(state)), state);
  const incompatible = { ...BASE, device: 'mark2', method: 'containers', speech: 'local' };
  assert.deepEqual(decode(encode(incompatible)), incompatible);
});

test('every single-character substitution is rejected by the checksum', () => {
  const code = '440000G0CN9Z2055';
  for (let index = 0; index < code.length; index += 1) {
    for (const character of COMPACT_ALPHABET) {
      if (character === code[index]) continue;
      const mutated = code.slice(0, index) + character + code.slice(index + 1);
      assert.throws(() => decode(mutated), /checksum/, mutated);
    }
  }
});

test('every single wire-bit mutation is rejected by the checksum', () => {
  const wire = (0x21000002n << 48n) | (BigInt(NOW) << 8n) | 0xa5n;
  for (let bit = 0n; bit < 80n; bit += 1n) {
    assert.throws(() => decode(wireCode(wire ^ (1n << bit))), /checksum/);
  }
});

test('valid checksums cannot admit unsupported wire versions', () => {
  for (let version = 0; version < 16; version += 1) {
    if (version === COMPACT_VERSION) continue;
    assert.throws(() => decode(headerCode(version * 2 ** 28 + 0x01000002)), /Unsupported.*version/);
  }
});

test('every reserved enum index is rejected even with a valid checksum', () => {
  for (const field of COMPACT_FIELDS) {
    for (let index = field.values.length; index < 2 ** field.width; index += 1) {
      const header = COMPACT_VERSION * 2 ** 28 + index * 2 ** field.offset;
      assert.throws(() => decode(headerCode(header)), new RegExp(`Reserved.*${field.name}`));
    }
  }
});

test('decoder rejects malformed input without aliases or whitespace normalization', () => {
  for (const input of [
    '', '440000G0CN9Z205', '440000G0CN9Z20555', '4400-00G0CN9Z2055',
    '4400_00G0_CN9Z_2055', ' 440000G0CN9Z2055', '440000G0CN9Z2055 ',
    '\n440000G0CN9Z2055', '440000G0CN9Z2055\n', '4400–00G0-CN9Z-2055',
    '４40000G0CN9Z2055', null, undefined, 240000,
    ['4400-00G0-CN9Z-2055'], new String('4400-00G0-CN9Z-2055'),
  ]) assert.throws(() => decode(input), /16 Base32/, String(input));
  for (const character of 'OILUoilu!$@') {
    assert.throws(() => decode(`440000G0CN9Z205${character}`), /16 Base32/);
  }
});

test('encoder requires an object with exactly all own contract fields', () => {
  for (const state of [null, undefined, false, '2400-00KZ', [], Object.values(BASE)]) {
    assert.throws(() => encodeRecipeCode(state), /Recipe must/);
  }
  for (const field of COMPACT_FIELDS) {
    const incomplete = { ...BASE };
    delete incomplete[field.name];
    assert.throws(() => encodeRecipeCode(incomplete), /exactly/);
    const inherited = Object.assign(Object.create({ [field.name]: BASE[field.name] }), incomplete);
    assert.throws(() => encodeRecipeCode(inherited), /exactly/);
  }
  assert.throws(() => encodeRecipeCode({ ...BASE, surprise: true }), /exactly/);
  assert.throws(() => encodeRecipeCode({ ...BASE, [Symbol('secret')]: 'token' }), /exactly/);
  const hidden = { ...BASE };
  Object.defineProperty(hidden, 'secret', { value: 'token' });
  assert.throws(() => encodeRecipeCode(hidden), /exactly/);
});

test('encoder rejects wrong types and all unknown enum values', () => {
  for (const field of COMPACT_FIELDS) {
    for (const value of [undefined, null, 0, 1, '', 'invalid', [], {}]) {
      assert.throws(() => encodeRecipeCode({ ...BASE, [field.name]: value }), new RegExp(`Invalid.*${field.name}`));
    }
    const wrongType = typeof field.values[0] === 'boolean' ? 'false' : false;
    assert.throws(() => encodeRecipeCode({ ...BASE, [field.name]: wrongType }), /Invalid/);
    if (typeof field.values[0] === 'string') {
      assert.throws(() => encodeRecipeCode({ ...BASE, [field.name]: field.values[0].toUpperCase() }), /Invalid/);
    }
  }
});

test('decoded state is fresh and does not mutate the frozen contract', () => {
  const decoded = decode('4400-00G0-CN9Z-2055');
  decoded.device = 'other';
  assert.deepEqual(decode('4400-00G0-CN9Z-2055'), BASE);
  assert.equal(encode(BASE), '4400-00G0-CN9Z-2055');
  assert.equal(COMPACT_FIELDS[0].values[0], 'pi');
});

test('valid from issuance through deadline minus one second, then expires exactly', () => {
  const code = encode(BASE);
  for (const now of [NOW, NOW + 1, NOW + 3599]) {
    assert.deepEqual(decodeRecipeCode(code, { now }), BASE);
  }
  for (const now of [NOW + 3600, NOW + 3601, NOW + 86400]) {
    assert.throws(() => decodeRecipeCode(code, { now }), /expired/);
  }
  assert.deepEqual(decodeRecipeEnvelope(code, { now: NOW }), {
    version: 2, issuedAt: NOW, expiresAt: NOW + 3600, state: BASE,
  });
});

test('future timestamps always fail, including choice recovery', () => {
  const code = encode(BASE);
  for (const options of [{}, { allowLegacy: true }, { allowExpired: true }, { allowLegacy: true, allowExpired: true }]) {
    assert.throws(() => decodeRecipeCode(code, { now: NOW - 1, ...options }), /future-dated/);
  }
});

test('explicit recovery can restore expired choices but cannot bypass other validation', () => {
  const code = encode(BASE);
  assert.deepEqual(decodeRecipeCode(code, { now: NOW + 3600, allowExpired: true }), BASE);
  assert.throws(() => decodeRecipeCode(code, { now: NOW + 3600, allowLegacy: true }), /expired/);
  assert.throws(() => decodeRecipeCode(code.slice(0, -1) + '6', { now: NOW + 3600, allowExpired: true }), /checksum/);
  assert.throws(() => decodeRecipeCode(code, { now: NaN, allowExpired: true }), /clock/);
});

test('all frozen v1 vectors require explicit legacy recovery and retain typed choices', async () => {
  const legacy = JSON.parse(await readFile(new URL('../contract-v1.json', import.meta.url), 'utf8'));
  for (let index = 0; index < legacy.vectors.length; index += 1) {
    const { code } = legacy.vectors[index];
    assert.throws(() => decodeRecipeCode(code, { now: NOW }), /legacy.*no expiry/);
    assert.throws(() => decodeRecipeCode(code, { now: NOW, allowExpired: true }), /legacy.*no expiry/);
    assert.deepEqual(decodeRecipeEnvelope(code, { now: NOW, allowLegacy: true }), {
      version: 1, issuedAt: null, expiresAt: null, state: VECTORS[index].state,
    });
  }
  assert.throws(() => decodeRecipeCode('2400-00K0', { now: NOW, allowLegacy: true }), /checksum/);
});

test('the complete forty-bit timestamp is preserved without integer truncation', () => {
  for (const issuedAt of [1, 2 ** 31, 2 ** 32 + 123, MAX_RECIPE_TIMESTAMP]) {
    const code = encodeRecipeCode(BASE, { issuedAt });
    assert.deepEqual(decodeRecipeEnvelope(code, { now: issuedAt }), {
      version: 2, issuedAt, expiresAt: issuedAt + 3600, state: BASE,
    });
  }
});

test('invalid clock and issuance values fail without coercion', () => {
  for (const value of [0, -1, 1.5, NaN, Infinity, -Infinity, null, '1700000000', true, [], {}, MAX_RECIPE_TIMESTAMP + 1]) {
    assert.throws(() => encodeRecipeCode(BASE, { issuedAt: value }), /issuance timestamp/);
    assert.throws(() => decodeRecipeCode(encode(BASE), { now: value }), /clock/);
  }
  for (const flag of ['allowLegacy', 'allowExpired']) {
    for (const value of [1, 'true', null, []]) {
      assert.throws(() => decodeRecipeCode(encode(BASE), { now: NOW, [flag]: value }), /flags must be booleans/);
    }
  }
});

test('default issuance and validation floor the real clock to Unix seconds', t => {
  t.mock.method(Date, 'now', () => NOW * 1000 + 999);
  const code = encodeRecipeCode(BASE);
  assert.equal(code, '4400-00G0-CN9Z-2055');
  assert.deepEqual(decodeRecipeCode(code), BASE);
  assert.equal(decodeRecipeEnvelope(code).issuedAt, NOW);
});

test('an unavailable default clock fails closed', t => {
  t.mock.method(Date, 'now', () => NaN);
  assert.throws(() => encodeRecipeCode(BASE), /clock/);
  assert.throws(() => decodeRecipeCode('4400-00G0-CN9Z-2055'), /clock/);
  Date.now.mock.mockImplementation(() => { throw new Error('Clock unavailable'); });
  assert.throws(() => encodeRecipeCode(BASE), /clock/);
  assert.throws(() => decodeRecipeCode('4400-00G0-CN9Z-2055'), /clock/);
});
