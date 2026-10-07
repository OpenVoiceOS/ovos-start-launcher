// SPDX-License-Identifier: Apache-2.0
// Version 1 is a frozen wire contract. Change the version before changing its layout.

export const COMPACT_VERSION = 1;
export const COMPACT_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/** @typedef {string | boolean} RecipeValue */
/** @typedef {Record<string, RecipeValue>} RecipeState */
/** @typedef {{name: string, width: number, offset: number, values: readonly RecipeValue[]}} CompactField */

/** Ordered from the most significant to least significant payload bits. */
export const COMPACT_FIELDS = Object.freeze([
  Object.freeze({ name: 'device', width: 4, offset: 24, values: Object.freeze(['pi', 'computer', 'mark1', 'mark2', 'devkit', 'jetson', 'server', 'mac', 'windows', 'other']) }),
  Object.freeze({ name: 'experience', width: 2, offset: 22, values: Object.freeze(['ready', 'tinker', 'hub']) }),
  Object.freeze({ name: 'locale', width: 4, offset: 18, values: Object.freeze(['en-us', 'fr-fr', 'de-de', 'es-es', 'it-it', 'nl-nl', 'pt-pt', 'ca-es', 'eu-es', 'gl-es', 'hi-in', 'kab-dz']) }),
  Object.freeze({ name: 'method', width: 1, offset: 17, values: Object.freeze(['virtualenv', 'containers']) }),
  Object.freeze({ name: 'channel', width: 1, offset: 16, values: Object.freeze(['testing', 'alpha']) }),
  Object.freeze({ name: 'expertise', width: 2, offset: 14, values: Object.freeze(['guided', 'tinker', 'expert']) }),
  Object.freeze({ name: 'speech', width: 2, offset: 12, values: Object.freeze(['auto', 'public', 'local']) }),
  Object.freeze({ name: 'memory', width: 2, offset: 10, values: Object.freeze(['unknown', 'under8', '8plus']) }),
  Object.freeze({ name: 'cpu', width: 2, offset: 8, values: Object.freeze(['unknown', 'arm64', 'avx2', 'intel-mac']) }),
  Object.freeze({ name: 'piModel', width: 2, offset: 6, values: Object.freeze(['unknown', 'older', 'pi5']) }),
  Object.freeze({ name: 'llmMode', width: 2, offset: 4, values: Object.freeze(['off', 'local', 'online']) }),
  Object.freeze({ name: 'extraSkills', width: 1, offset: 3, values: Object.freeze([false, true]) }),
  Object.freeze({ name: 'telemetry', width: 1, offset: 2, values: Object.freeze([false, true]) }),
  Object.freeze({ name: 'skills', width: 1, offset: 1, values: Object.freeze([false, true]) }),
  Object.freeze({ name: 'homeassistant', width: 1, offset: 0, values: Object.freeze([false, true]) }),
]);

const FIELD_NAMES = new Set(COMPACT_FIELDS.map(field => field.name));
const CODE_FORMAT = /^(?:[0-9A-HJKMNP-TV-Z]{8}|[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4})$/i;

/**
 * Compute CRC-8/SMBUS over four big-endian header bytes, without reflection.
 * The checksum catches transcription mistakes; it is not authentication.
 * @param {number} header Unsigned 32-bit version and payload header.
 * @returns {number} Eight-bit checksum.
 */
function checksum(header) {
  let crc = 0;
  for (const shift of [24, 16, 8, 0]) {
    crc ^= (header >>> shift) & 0xff;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = ((crc << 1) ^ ((crc & 0x80) ? 0x07 : 0)) & 0xff;
    }
  }
  return crc;
}

/**
 * Encode all and only the frozen recipe fields into an XXXX-XXXX recipe code.
 * Cross-field compatibility must be checked separately by the wizard/launcher.
 * @param {RecipeState} state Complete non-secret recipe choices.
 * @returns {string} Eight uppercase Crockford Base32 characters with a hyphen.
 * @throws {TypeError | RangeError} When fields or typed enum values are invalid.
 */
export function encodeRecipeCode(state) {
  if (!state || typeof state !== 'object' || Array.isArray(state)) {
    throw new TypeError('Recipe must be an object containing every compact field.');
  }
  const keys = Reflect.ownKeys(state);
  if (keys.length !== COMPACT_FIELDS.length || keys.some(key => !FIELD_NAMES.has(key))) {
    throw new TypeError('Recipe must contain exactly the version 1 compact fields.');
  }
  let payload = 0n;
  for (const field of COMPACT_FIELDS) {
    if (!Object.hasOwn(state, field.name)) {
      throw new TypeError(`Missing recipe field: ${field.name}.`);
    }
    const index = field.values.indexOf(state[field.name]);
    if (index < 0) throw new RangeError(`Invalid recipe field: ${field.name}.`);
    payload |= BigInt(index) << BigInt(field.offset);
  }
  const header = (BigInt(COMPACT_VERSION) << 28n) | payload;
  let wire = (header << 8n) | BigInt(checksum(Number(header)));
  let code = '';
  for (let digit = 0; digit < 8; digit += 1) {
    code = COMPACT_ALPHABET[Number(wire & 31n)] + code;
    wire >>= 5n;
  }
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

/**
 * Decode an exact grouped or ungrouped recipe code, accepting ASCII letter case.
 * Ambiguous aliases (O/I/L), whitespace, unknown versions and reserved values fail.
 * Returns raw typed choices; callers must apply their compatibility validation.
 * @param {string} input An eight-character code, optionally grouped XXXX-XXXX.
 * @returns {RecipeState} A new object containing every frozen compact field.
 * @throws {TypeError | RangeError} When format, checksum or the wire contract fails.
 */
export function decodeRecipeCode(input) {
  if (typeof input !== 'string' || !CODE_FORMAT.test(input)) {
    throw new TypeError('Recipe code must be eight Base32 characters, optionally XXXX-XXXX.');
  }
  const code = input.toUpperCase().replace('-', '');
  let wire = 0n;
  for (const character of code) {
    wire = (wire << 5n) | BigInt(COMPACT_ALPHABET.indexOf(character));
  }
  const header = wire >> 8n;
  if (Number(wire & 255n) !== checksum(Number(header))) {
    throw new RangeError('Recipe code checksum does not match.');
  }
  const version = Number(header >> 28n);
  if (version !== COMPACT_VERSION) {
    throw new RangeError(`Unsupported recipe code version: ${version}.`);
  }
  const payload = header & 0x0fffffffn;
  const state = {};
  for (const field of COMPACT_FIELDS) {
    const mask = (1n << BigInt(field.width)) - 1n;
    const index = Number((payload >> BigInt(field.offset)) & mask);
    if (index >= field.values.length) {
      throw new RangeError(`Reserved recipe value for ${field.name}.`);
    }
    state[field.name] = field.values[index];
  }
  return state;
}
