import assert from "node:assert/strict";
import { generateKeyPairSync, webcrypto } from "node:crypto";
import test from "node:test";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const {
  ManagedPushRegistry,
  deliverOpaqueAPNs,
  handleManagedPush,
  opaqueAPNsPayload,
  signerIsReady
} = await import("../src/managed-push.js");

class MemoryStorage {
  #values = new Map();

  async get(key) { return this.#values.get(key); }
  async put(key, value) { this.#values.set(key, structuredClone(value)); }
  async delete(key) { this.#values.delete(key); }
}

function testEnvironment(overrides = {}) {
  const { privateKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  return {
    DREL_MANAGED_PUSH_ENABLED: "1",
    APNS_AUTH_KEY_P8: privateKey.export({ type: "pkcs8", format: "pem" }),
    APNS_KEY_ID: "TESTKEY123",
    APNS_TEAM_ID: "TEAM123456",
    APNS_TOPIC: "com.webbridgekit.superapp",
    ...overrides
  };
}

function request(path, method = "GET", json) {
  return new Request(`https://api.drel.app${path}`, {
    method,
    headers: json === undefined ? undefined : { "content-type": "application/json" },
    body: json === undefined ? undefined : JSON.stringify(json)
  });
}

function base64url(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function validEnvelope() {
  const now = Math.floor(Date.now() / 1000);
  return base64url({
    schema: "drel.push-envelope.v1",
    messageID: "worker-contract-message",
    createdAt: now,
    expiresAt: now + 300,
    ephemeralPublicKey: Buffer.alloc(32, 7).toString("base64url"),
    ciphertext: Buffer.alloc(28, 9).toString("base64url")
  });
}

test("managed signer stores only ticket digest, returns only recipient public key, and sends opaque APNs", async () => {
  const originalFetch = globalThis.fetch;
  const observedAPNs = [];
  globalThis.fetch = async (url, options) => {
    observedAPNs.push({ url, options });
    return new Response(null, { status: 200 });
  };
  try {
    const state = { storage: new MemoryStorage() };
    const registry = new ManagedPushRegistry(state, testEnvironment());
    assert.equal(await signerIsReady(registry.env), true);

    const pairingResponse = await registry.fetch(request("/managed-push/pairings", "POST"));
    assert.equal(pairingResponse.status, 200);
    const pairing = await pairingResponse.json();
    assert.match(pairing.pairingToken, /^[A-Za-z0-9_-]{32}$/);
    const persistedTickets = await state.storage.get("tickets");
    assert.equal(JSON.stringify(persistedTickets).includes(pairing.pairingToken), false);

    const publicKey = Buffer.alloc(32, 4).toString("base64url");
    const deviceKey = Buffer.alloc(24, 5).toString("base64url");
    const deviceToken = "a".repeat(64);
    const registrationResponse = await registry.fetch(request("/managed-push/register", "POST", {
      deviceToken,
      deviceKey,
      encryptionPublicKey: publicKey,
      pairingToken: pairing.pairingToken,
      platform: "ios",
      appVersion: "2.0"
    }));
    assert.equal(registrationResponse.status, 200);

    const recipientResponse = await registry.fetch(request(`/managed-push/recipients/${deviceKey}`));
    const recipientText = await recipientResponse.text();
    assert.match(recipientText, new RegExp(publicKey));
    assert.equal(recipientText.includes(deviceToken), false);

    const rejected = await registry.fetch(request(`/managed-push/deliveries/${deviceKey}`, "POST", {
      drelEnvelope: validEnvelope(),
      title: "this plaintext must be rejected"
    }));
    assert.equal(rejected.status, 400);
    assert.equal(observedAPNs.length, 0);

    const delivery = await registry.fetch(request(`/managed-push/deliveries/${deviceKey}`, "POST", {
      drelEnvelope: validEnvelope()
    }));
    assert.equal(delivery.status, 200);
    assert.equal(observedAPNs.length, 1);
    assert.equal(observedAPNs[0].url, `https://api.push.apple.com/3/device/${deviceToken}`);
    assert.equal(observedAPNs[0].options.headers["apns-topic"], "com.webbridgekit.superapp");
    const apnsBody = JSON.parse(observedAPNs[0].options.body);
    assert.equal(apnsBody.title, "");
    assert.equal(apnsBody.body, "");
    assert.equal(apnsBody.aps.alert.title, "加密消息");
    assert.equal(apnsBody.aps.alert.body, "🔒 已加密内容，设备将自动解密");
    assert.equal(apnsBody.aps["mutable-content"], 1);
    assert.equal(observedAPNs[0].options.body.includes("this plaintext must be rejected"), false);

    const removal = await registry.fetch(request("/managed-push/unregister", "POST", { deviceToken, deviceKey }));
    assert.deepEqual(await removal.json(), { code: 200, removed: true });
    assert.equal((await registry.fetch(request(`/managed-push/recipients/${deviceKey}`))).status, 404);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("APNs delivery refuses plaintext wrappers and never uses a caller-selected host", async () => {
  const env = testEnvironment();
  const envelope = validEnvelope();
  assert.equal(opaqueAPNsPayload(envelope).messageId, "worker-contract-message");
  const calls = [];
  await deliverOpaqueAPNs(env, "b".repeat(64), envelope, async (url, options) => {
    calls.push({ url, options });
    return new Response(null, { status: 200 });
  });
  assert.equal(calls[0].url, `https://api.push.apple.com/3/device/${"b".repeat(64)}`);
  assert.match(calls[0].options.headers.authorization, /^bearer ey/);
});

test("disabled managed paths do not fall through to the legacy upstream", async () => {
  const response = await handleManagedPush(
    request("/managed-push/deliveries/opaque-device-capability", "POST", { drelEnvelope: validEnvelope() }),
    { DREL_MANAGED_PUSH_ENABLED: "0" }
  );
  assert.equal(response.status, 404);
});
