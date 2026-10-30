const BLOCK_SIZE = 16;

function xorBlock(a, b) {
  const out = new Uint8Array(BLOCK_SIZE);
  for (let i = 0; i < BLOCK_SIZE; i++) out[i] = a[i] ^ b[i];
  return out;
}

function shiftLeft(block) {
  const out = new Uint8Array(BLOCK_SIZE);
  let carry = 0;
  for (let i = BLOCK_SIZE - 1; i >= 0; i--) {
    const value = block[i];
    out[i] = ((value << 1) & 0xff) | carry;
    carry = (value & 0x80) ? 1 : 0;
  }
  return out;
}

function deriveSubkey(input) {
  const shifted = shiftLeft(input);
  if ((input[0] & 0x80) !== 0) shifted[BLOCK_SIZE - 1] ^= 0x87;
  return shifted;
}

async function aesBlock(keyBytes, block) {
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "AES-CBC" }, false, ["encrypt"]);
  // WebCrypto applies PKCS#7 padding; the first block is the required AES_K(block).
  const encrypted = new Uint8Array(await crypto.subtle.encrypt(
    { name: "AES-CBC", iv: new Uint8Array(BLOCK_SIZE) },
    key,
    block,
  ));
  return encrypted.slice(0, BLOCK_SIZE);
}

export async function aesCmac(keyBytes, message) {
  if (keyBytes.length !== 16) throw new Error("NTAG 424 SDM key must be 16 bytes");
  const l = await aesBlock(keyBytes, new Uint8Array(BLOCK_SIZE));
  const k1 = deriveSubkey(l);
  const k2 = deriveSubkey(k1);
  const blockCount = Math.max(1, Math.ceil(message.length / BLOCK_SIZE));
  const complete = message.length > 0 && message.length % BLOCK_SIZE === 0;
  const last = new Uint8Array(BLOCK_SIZE);
  const lastOffset = (blockCount - 1) * BLOCK_SIZE;
  const remaining = message.slice(lastOffset);
  last.set(remaining);
  if (complete) {
    for (let i = 0; i < BLOCK_SIZE; i++) last[i] ^= k1[i];
  } else {
    last[remaining.length] = 0x80;
    for (let i = 0; i < BLOCK_SIZE; i++) last[i] ^= k2[i];
  }

  let state = new Uint8Array(BLOCK_SIZE);
  for (let blockIndex = 0; blockIndex < blockCount - 1; blockIndex++) {
    const block = message.slice(blockIndex * BLOCK_SIZE, (blockIndex + 1) * BLOCK_SIZE);
    state = await aesBlock(keyBytes, xorBlock(state, block));
  }
  return await aesBlock(keyBytes, xorBlock(state, last));
}

export function hexToBytes(hex) {
  if (!/^(?:[0-9a-fA-F]{2})+$/.test(hex)) throw new Error("Invalid hexadecimal value");
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return bytes;
}

export function bytesToHex(bytes) {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();
}

export function buildSdmMacSessionVector(uidHex, counterHex) {
  const uid = hexToBytes(uidHex);
  const counterUrlOrder = hexToBytes(counterHex);
  if (uid.length !== 7 || counterUrlOrder.length !== 3) throw new Error("Expected 7-byte UID and 3-byte counter");
  const counterCommandOrder = Uint8Array.from(counterUrlOrder).reverse();
  const prefix = new Uint8Array([0x3c, 0xc3, 0x00, 0x01, 0x00, 0x80]);
  const vector = new Uint8Array(prefix.length + uid.length + counterCommandOrder.length);
  vector.set(prefix, 0);
  vector.set(uid, prefix.length);
  vector.set(counterCommandOrder, prefix.length + uid.length);
  return vector;
}

export async function deriveSdmMacKey(sdmFileReadKey, uidHex, counterHex) {
  return await aesCmac(sdmFileReadKey, buildSdmMacSessionVector(uidHex, counterHex));
}

export function truncateSdmMac(fullMac) {
  if (fullMac.length !== 16) throw new Error("AES-CMAC output must be 16 bytes");
  const truncated = new Uint8Array(8);
  for (let i = 0; i < 8; i++) truncated[i] = fullMac[14 - (i * 2)];
  return truncated;
}

export function equalBytesConstantTime(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function verifyPlainUidCounterSdm({ key, uidHex, counterHex, cmacHex }) {
  const sessionKey = await deriveSdmMacKey(key, uidHex, counterHex);
  // Configure SDMMACInputOffset equal to SDMMACOffset: NXP specifies an empty MAC input.
  const expected = truncateSdmMac(await aesCmac(sessionKey, new Uint8Array(0)));
  const supplied = hexToBytes(cmacHex);
  return equalBytesConstantTime(expected, supplied);
}
