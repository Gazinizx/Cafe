import { aesCmac, buildSdmMacSessionVector, bytesToHex, deriveSdmMacKey, hexToBytes } from "./ntag424.js";

Deno.test("AES-CMAC empty-message NIST vector", async () => {
  const actual = await aesCmac(
    hexToBytes("2B7E151628AED2A6ABF7158809CF4F3C"),
    new Uint8Array(0),
  );
  if (bytesToHex(actual) !== "BB1D6929E95937287FA37D129B756746") {
    throw new Error(`Unexpected CMAC: ${bytesToHex(actual)}`);
  }
});

Deno.test("NTAG 424 DNA SDM session MAC key matches NXP AN12196", async () => {
  const key = hexToBytes("5ACE7E50AB65D5D51FD5BF5A16B8205B");
  const vector = buildSdmMacSessionVector("04C767F2066180", "000001");
  if (bytesToHex(vector) !== "3CC30001008004C767F2066180010000") {
    throw new Error(`Unexpected SV2: ${bytesToHex(vector)}`);
  }
  const actual = await deriveSdmMacKey(key, "04C767F2066180", "000001");
  if (bytesToHex(actual) !== "3A3E8110E05311F7A3FCF0D969BF2B48") {
    throw new Error(`Unexpected SDM session key: ${bytesToHex(actual)}`);
  }
});
