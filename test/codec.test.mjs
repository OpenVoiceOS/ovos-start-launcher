// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import {
  COMPACT_ALPHABET, COMPACT_FIELDS, COMPACT_VERSION,
  decodeRecipeCode, encodeRecipeCode,
} from '../codec.mjs';

const BASE = Object.freeze({
  device: 'computer', experience: 'ready', locale: 'en-us', method: 'virtualenv',
  channel: 'testing', expertise: 'guided', speech: 'auto', memory: 'unknown',
  cpu: 'unknown', piModel: 'unknown', llmMode: 'off', extraSkills: false,
  telemetry: false, skills: true, homeassistant: false,
});
const VECTORS = [
  { name: 'computer-default', code: '2400-00KZ', header: 0x11000002, crc: 0x7f, state: BASE },
  { name: 'pi-local-french', code: '202J-K0HK', header: 0x10052982, crc: 0x33, state: { ...BASE, device: 'pi', locale: 'fr-fr', channel: 'alpha', speech: 'local', memory: '8plus', cpu: 'arm64', piModel: 'pi5' } },
  { name: 'mac-default', code: '2W0G-00K0', header: 0x17010002, crc: 0x60, state: { ...BASE, device: 'mac', channel: 'alpha' } },
  { name: 'windows-public-integrations', code: '3001-08V9', header: 0x18001023, crc: 0x69, state: { ...BASE, device: 'windows', speech: 'public', llmMode: 'online', homeassistant: true } },
  { name: 'container-hub', code: '2T10-00P0', header: 0x16820002, crc: 0xc0, state: { ...BASE, device: 'server', experience: 'hub', method: 'containers' } },
];

/** Convert a wire integer independently using division, not the codec's shifts.
 * @param {number} wire Unsigned 40-bit wire integer.
 * @returns {string} Ungrouped code.
 */
function wireCode(wire) {
  let code = '';
  for (let index = 0; index < 8; index += 1) {
    code = COMPACT_ALPHABET[wire % 32] + code;
    wire = Math.floor(wire / 32);
  }
  return code;
}

/** Independently divide the 40-bit message by the CRC polynomial.
 * @param {number} header Unsigned 32-bit header.
 * @returns {number} CRC-8 remainder.
 */
function referenceChecksum(header) {
  let remainder = BigInt(header) << 8n;
  for (let bit = 39n; bit >= 8n; bit -= 1n) {
    if (remainder & (1n << bit)) remainder ^= 0x107n << (bit - 8n);
  }
  return Number(remainder);
}

/** Generate a valid-checksum wire code for negative semantic tests.
 * @param {number} header Unsigned 32-bit version and payload.
 * @returns {string} Ungrouped code.
 */
function headerCode(header) {
  return wireCode(header * 256 + referenceChecksum(header));
}

test('frozen contract uses exactly 28 disjoint payload bits', async () => {
  const contract = JSON.parse(await readFile(new URL('../contract.json', import.meta.url), 'utf8'));
  assert.equal(contract.version, COMPACT_VERSION);
  assert.equal(contract.alphabet, COMPACT_ALPHABET);
  assert.deepEqual(contract.fields, COMPACT_FIELDS);
  assert.equal(contract.wireBits, 40);
  assert.equal(contract.codeCharacters, 8);
  assert.deepEqual(contract.layout, [
    { name: 'version', width: 4, offset: 36 },
    { name: 'payload', width: 28, offset: 8 },
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
  })));
});

for (const vector of VECTORS) {
  test(`deterministic wire vector: ${vector.name}`, () => {
    assert.equal(referenceChecksum(vector.header), vector.crc);
    assert.equal(wireCode(vector.header * 256 + vector.crc), vector.code.replace('-', ''));
    assert.equal(encodeRecipeCode(vector.state), vector.code);
    assert.deepEqual(decodeRecipeCode(vector.code), vector.state);
    assert.deepEqual(decodeRecipeCode(vector.code.toLowerCase()), vector.state);
    assert.deepEqual(decodeRecipeCode(vector.code.replace('-', '')), vector.state);
    assert.deepEqual(decodeRecipeCode(vector.code.toLowerCase().replace('-', '')), vector.state);
  });
}

for (const field of COMPACT_FIELDS) {
  test(`round-trip every typed ${field.name} value`, () => {
    for (const value of field.values) {
      const state = Object.freeze({ ...BASE, [field.name]: value });
      const code = encodeRecipeCode(state);
      assert.match(code, /^[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}$/);
      assert.deepEqual(decodeRecipeCode(code), state);
    }
  });
}

test('codec leaves cross-field validation to consumers', () => {
  const state = Object.fromEntries(COMPACT_FIELDS.map(field => [field.name, field.values.at(-1)]));
  assert.deepEqual(decodeRecipeCode(encodeRecipeCode(state)), state);
  const incompatible = { ...BASE, device: 'mark2', method: 'containers', speech: 'local' };
  assert.deepEqual(decodeRecipeCode(encodeRecipeCode(incompatible)), incompatible);
});

test('every single-character substitution is rejected by the checksum', () => {
  const code = '240000KZ';
  for (let index = 0; index < code.length; index += 1) {
    for (const character of COMPACT_ALPHABET) {
      if (character === code[index]) continue;
      const mutated = code.slice(0, index) + character + code.slice(index + 1);
      assert.throws(() => decodeRecipeCode(mutated), /checksum/, mutated);
    }
  }
});

test('every single wire-bit mutation is rejected by the checksum', () => {
  const wire = 0x110000027fn;
  for (let bit = 0n; bit < 40n; bit += 1n) {
    assert.throws(() => decodeRecipeCode(wireCode(Number(wire ^ (1n << bit)))), /checksum/);
  }
});

test('valid checksums cannot admit unsupported wire versions', () => {
  for (let version = 0; version < 16; version += 1) {
    if (version === COMPACT_VERSION) continue;
    assert.throws(() => decodeRecipeCode(headerCode(version * 2 ** 28 + 0x01000002)), /Unsupported.*version/);
  }
});

test('every reserved enum index is rejected even with a valid checksum', () => {
  for (const field of COMPACT_FIELDS) {
    for (let index = field.values.length; index < 2 ** field.width; index += 1) {
      const header = 2 ** 28 + index * 2 ** field.offset;
      assert.throws(() => decodeRecipeCode(headerCode(header)), new RegExp(`Reserved.*${field.name}`));
    }
  }
});

test('decoder rejects malformed input without aliases or whitespace normalization', () => {
  for (const input of [
    '', '240000K', '240000KZZ', '240-000KZ', '24000-0KZ', '2400--00KZ',
    '2400_00KZ', ' 240000KZ', '240000KZ ', '\n240000KZ', '240000KZ\n',
    '2400 00KZ', '2400–00KZ', '２40000KZ', null, undefined, 240000,
    ['2400-00KZ'], new String('2400-00KZ'),
  ]) assert.throws(() => decodeRecipeCode(input), /eight Base32/, String(input));
  for (const character of 'OILUoilu!$@') {
    assert.throws(() => decodeRecipeCode(`240000K${character}`), /eight Base32/);
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
  const decoded = decodeRecipeCode('2400-00KZ');
  decoded.device = 'other';
  assert.deepEqual(decodeRecipeCode('2400-00KZ'), BASE);
  assert.equal(encodeRecipeCode(BASE), '2400-00KZ');
  assert.equal(COMPACT_FIELDS[0].values[0], 'pi');
});
