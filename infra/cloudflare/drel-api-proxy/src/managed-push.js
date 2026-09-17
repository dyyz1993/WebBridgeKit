const encoder = new TextEncoder();
const pairingTTLSeconds = 10 * 60;
const maxOutstandingPairings = 256;
const maxEnvelopeBytes = 3200;
const apnsProductionBaseURL = "https://api.push.apple.com";

let cachedSigner;

function json(value, status = 200) {
  return Response.json(value, {
    status,
    headers: { "cache-control": "no-store" }
  });
}

function failure(status, message) {
  return json({ code: status, message }, status);
}

function base64URLEncode(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64URLDecode(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]*$/.test(value)) return null;
  try {
    const padded = `${value}${"=".repeat((4 - (value.length % 4)) % 4)}`
      .replace(/-/g, "+")
      .replace(/_/g, "/");
    const binary = atob(padded);
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}

function parseJSON(bytes) {
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

function boundedString(value, min, max) {
  return typeof value === "string" && value.length >= min && value.length <= max;
}

function publicKeyIsValid(value) {
  return base64URLDecode(value)?.byteLength === 32;
}

function deviceKeyIsValid(value) {
  return boundedString(value, 20, 256) && /^[A-Za-z0-9_-]+$/.test(value);
}

function deviceTokenIsValid(value) {
  // APNs device tokens are hexadecimal and normally 64 bytes. Keep the
  // boundary deliberately tolerant of future length changes, but never let
  // arbitrary text become an outbound APNs path component.
  return boundedString(value, 32, 512) && /^[A-Fa-f0-9]+$/.test(value);
}

function messageEnvelope(value, now = Math.floor(Date.now() / 1000)) {
  if (!boundedString(value, 1, maxEnvelopeBytes)) return null;
  const decoded = base64URLDecode(value);
  const envelope = decoded && parseJSON(decoded);
  if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)) return null;
  if (envelope.schema !== "drel.push-envelope.v1") return null;
  if (!boundedString(envelope.messageID, 1, 128)) return null;
  if (!Number.isSafeInteger(envelope.createdAt) || !Number.isSafeInteger(envelope.expiresAt)) return null;
  if (envelope.expiresAt <= now || envelope.expiresAt <= envelope.createdAt) return null;
  if (envelope.expiresAt - envelope.createdAt > 24 * 60 * 60) return null;
  if (base64URLDecode(envelope.ephemeralPublicKey)?.byteLength !== 32) return null;
  if ((base64URLDecode(envelope.ciphertext)?.byteLength ?? 0) < 28) return null;
  return envelope;
}

async function digest(value) {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function randomToken() {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return base64URLEncode(bytes);
}

function constantTimeEqual(left, right) {
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  let mismatch = leftBytes.length ^ rightBytes.length;
  const size = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < size; index += 1) {
    mismatch |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return mismatch === 0;
}

function managedPushEnabled(env) {
  return env.DREL_MANAGED_PUSH_ENABLED === "1";
}

function requiredSignerConfig(env) {
  return [env.APNS_AUTH_KEY_P8, env.APNS_KEY_ID, env.APNS_TEAM_ID, env.APNS_TOPIC]
    .every((value) => typeof value === "string" && value.length > 0);
}

function pemToDER(pem) {
  if (typeof pem !== "string") throw new Error("missing key");
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  if (!body || !/^[A-Za-z0-9+/]+={0,2}$/.test(body)) throw new Error("invalid key");
  try {
    const binary = atob(body);
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    throw new Error("invalid key");
  }
}

async function signingKey(env) {
  // Include a one-way local fingerprint so a secret rotation that retains a
  // key id cannot accidentally reuse an old in-isolate CryptoKey.
  const cacheIdentity = `${env.APNS_KEY_ID}:${env.APNS_TEAM_ID}:${env.APNS_TOPIC}:${await digest(env.APNS_AUTH_KEY_P8)}`;
  if (cachedSigner?.cacheIdentity === cacheIdentity) return cachedSigner.key;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDER(env.APNS_AUTH_KEY_P8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
  cachedSigner = { cacheIdentity, key, issuedAt: 0, token: "" };
  return key;
}

async function apnsJWT(env) {
  const key = await signingKey(env);
  const now = Math.floor(Date.now() / 1000);
  // Apple's provider tokens are valid for at most one hour. Refresh before
  // that boundary, while keeping the Worker hot path free of a p8 parse.
  if (cachedSigner.token && now - cachedSigner.issuedAt < 50 * 60) return cachedSigner.token;
  const header = base64URLEncode(encoder.encode(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID })));
  const claims = base64URLEncode(encoder.encode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: now })));
  const unsigned = `${header}.${claims}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(unsigned))
  );
  cachedSigner = { ...cachedSigner, issuedAt: now, token: `${unsigned}.${base64URLEncode(signature)}` };
  return cachedSigner.token;
}

export async function signerIsReady(env) {
  if (!managedPushEnabled(env) || !requiredSignerConfig(env)) return false;
  try {
    await signingKey(env);
    return true;
  } catch {
    return false;
  }
}

export function managedDescriptor(request) {
  return {
    schema: "drel.managed-encrypted-push.v1",
    name: "Drel Managed Encrypted Push",
    publicBaseURL: new URL(request.url).origin,
    registrationPath: "/managed-push/register",
    pairingPath: "/managed-push/pairings",
    recipientPath: "/managed-push/recipients/{deviceKey}",
    deliveryPath: "/managed-push/deliveries/{deviceKey}",
    unregisterPath: "/managed-push/unregister",
    healthPath: "/managed-push/health",
    envelopeSchema: "drel.push-envelope.v1"
  };
}

export function opaqueAPNsPayload(envelope) {
  const parsed = messageEnvelope(envelope);
  if (!parsed) throw new Error("invalid envelope");
  return {
    aps: {
      alert: { title: "加密消息", body: "🔒 已加密内容，设备将自动解密" },
      "mutable-content": 1,
      sound: "default"
    },
    // These fixed placeholders deliberately carry no application message
    // content. The Notification Service Extension replaces them locally.
    title: "",
    body: "",
    messageId: parsed.messageID,
    drelEnvelope: envelope
  };
}

export async function deliverOpaqueAPNs(env, deviceToken, envelope, fetchImpl = fetch) {
  const token = await apnsJWT(env);
  const response = await fetchImpl(`${apnsProductionBaseURL}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${token}`,
      "apns-topic": env.APNS_TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    },
    body: JSON.stringify(opaqueAPNsPayload(envelope))
  });
  // Do not pass Apple's body through: it may be operationally useful but is
  // not a safe place to accidentally include a caller-controlled payload.
  if (!response.ok) throw new Error(`APNs rejected delivery (${response.status})`);
}

async function requestJSON(request) {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) return null;
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function exactKeys(value, keys) {
  return value && typeof value === "object" && !Array.isArray(value)
    && Object.keys(value).every((key) => keys.includes(key));
}

/**
 * A single Durable Object keeps one-time ticket consumption and recipient
 * registration atomic. KV is intentionally not used here because eventual
 * consistency would make a pairing-ticket replay possible.
 */
export class ManagedPushRegistry {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    if (!(await signerIsReady(this.env))) {
      return failure(503, "Managed encrypted signer is temporarily unavailable");
    }
    const url = new URL(request.url);
    const path = url.pathname;
    if (path === "/managed-push/pairings" && request.method === "POST") return this.issuePairing(request);
    if (path === "/managed-push/register" && request.method === "POST") return this.register(request);
    if (path === "/managed-push/unregister" && request.method === "POST") return this.unregister(request);
    const recipient = path.match(/^\/managed-push\/recipients\/([A-Za-z0-9_-]+)$/);
    if (recipient && request.method === "GET") return this.recipient(recipient[1]);
    const delivery = path.match(/^\/managed-push\/deliveries\/([A-Za-z0-9_-]+)$/);
    if (delivery && request.method === "POST") return this.deliver(delivery[1], request);
    return failure(404, "Managed encrypted push route not found");
  }

  async issuePairing(request) {
    if (request.headers.get("content-length") && Number(request.headers.get("content-length")) > 0) {
      return failure(400, "Pairing requests must not contain a body");
    }
    const now = Math.floor(Date.now() / 1000);
    const tickets = await this.readTickets(now);
    if (Object.keys(tickets).length >= maxOutstandingPairings) {
      return failure(429, "Too many outstanding pairing tickets; try again shortly");
    }
    const token = randomToken();
    tickets[await digest(token)] = now + pairingTTLSeconds;
    await this.state.storage.put("tickets", tickets);
    const baseURL = new URL(request.url).origin;
    return json({
      schema: "drel.managed-encrypted-push-pairing.v1",
      pairingToken: token,
      expiresAt: new Date((now + pairingTTLSeconds) * 1000).toISOString(),
      configurationURL: `drel://managed-encrypted-push?server=${encodeURIComponent(baseURL)}&token=${token}`
    });
  }

  async register(request) {
    const body = await requestJSON(request);
    const allowed = ["deviceToken", "deviceKey", "encryptionPublicKey", "pairingToken", "platform", "appVersion"];
    if (!exactKeys(body, allowed)
      || !deviceTokenIsValid(body.deviceToken)
      || !deviceKeyIsValid(body.deviceKey)
      || !publicKeyIsValid(body.encryptionPublicKey)
      || !boundedString(body.pairingToken, 20, 256)
      || (body.platform !== undefined && !boundedString(body.platform, 1, 32))
      || (body.appVersion !== undefined && !boundedString(body.appVersion, 1, 128))) {
      return failure(400, "A valid device token, device key, pairing token, and X25519 public key are required");
    }
    const now = Math.floor(Date.now() / 1000);
    const tickets = await this.readTickets(now);
    const ticketDigest = await digest(body.pairingToken);
    if (!tickets[ticketDigest] || tickets[ticketDigest] <= now) {
      return failure(401, "Pairing token is invalid, expired, or already used");
    }
    delete tickets[ticketDigest];
    await this.state.storage.put("tickets", tickets);
    await this.state.storage.put(`recipient:${body.deviceKey}`, {
      deviceToken: body.deviceToken,
      deviceKey: body.deviceKey,
      encryptionPublicKey: body.encryptionPublicKey,
      platform: body.platform ?? "ios",
      appVersion: body.appVersion ?? null,
      registeredAt: now
    });
    return json({
      schema: "drel.managed-encrypted-push-registration.v1",
      deviceKey: body.deviceKey,
      recipientPath: `/managed-push/recipients/${body.deviceKey}`,
      deliveryPath: `/managed-push/deliveries/${body.deviceKey}`,
      message: "Managed encrypted push is ready"
    });
  }

  async recipient(deviceKey) {
    const record = await this.state.storage.get(`recipient:${deviceKey}`);
    if (!record) return failure(404, "No managed encrypted recipient for this device key");
    return json({
      schema: "drel.managed-encrypted-push-recipient.v1",
      deviceKey,
      encryptionPublicKey: record.encryptionPublicKey,
      deliveryPath: `/managed-push/deliveries/${deviceKey}`,
      envelopeSchema: "drel.push-envelope.v1"
    });
  }

  async deliver(deviceKey, request) {
    const body = await requestJSON(request);
    if (!exactKeys(body, ["drelEnvelope"]) || !messageEnvelope(body.drelEnvelope)) {
      return failure(400, "Managed encrypted delivery accepts exactly one valid drelEnvelope field");
    }
    const record = await this.state.storage.get(`recipient:${deviceKey}`);
    if (!record) return failure(404, "No managed encrypted recipient for this device key");
    if (!(await this.allowDelivery(deviceKey))) {
      return failure(429, "Managed encrypted delivery rate limit exceeded");
    }
    try {
      await deliverOpaqueAPNs(this.env, record.deviceToken, body.drelEnvelope);
      return json({ code: 200, message: "Push accepted by APNs", timestamp: Math.floor(Date.now() / 1000) });
    } catch {
      return failure(502, "Managed encrypted signer could not deliver this notification");
    }
  }

  async unregister(request) {
    const body = await requestJSON(request);
    if (!exactKeys(body, ["deviceToken", "deviceKey"])
      || !deviceTokenIsValid(body.deviceToken)
      || !deviceKeyIsValid(body.deviceKey)) {
      return failure(400, "deviceToken and deviceKey are required");
    }
    const key = `recipient:${body.deviceKey}`;
    const record = await this.state.storage.get(key);
    if (!record || !constantTimeEqual(record.deviceToken, body.deviceToken)) {
      return json({ code: 200, removed: false });
    }
    await this.state.storage.delete(key);
    await this.state.storage.delete(`deliveries:${body.deviceKey}`);
    return json({ code: 200, removed: true });
  }

  async readTickets(now) {
    const stored = (await this.state.storage.get("tickets")) ?? {};
    const active = Object.fromEntries(Object.entries(stored).filter(([, expiresAt]) => expiresAt > now));
    if (Object.keys(active).length !== Object.keys(stored).length) await this.state.storage.put("tickets", active);
    return active;
  }

  async allowDelivery(deviceKey) {
    const now = Math.floor(Date.now() / 1000);
    const max = Math.max(1, Math.min(600, Number(this.env.DREL_MANAGED_PUSH_MAX_DELIVERIES_PER_MINUTE ?? 60)));
    const key = `deliveries:${deviceKey}`;
    const timestamps = ((await this.state.storage.get(key)) ?? []).filter((timestamp) => timestamp > now - 60);
    if (timestamps.length >= max) return false;
    timestamps.push(now);
    await this.state.storage.put(key, timestamps);
    return true;
  }
}

export async function handleManagedPush(request, env) {
  const url = new URL(request.url);
  const isManagedPath = url.pathname === "/.well-known/drel-managed-push.json"
    || url.pathname === "/managed-push/health"
    || url.pathname.startsWith("/managed-push/");
  if (!isManagedPath) return null;
  // Do not proxy a disabled managed path to the legacy origin. The feature
  // boundary stays closed even if that origin gains an unrelated matching
  // route later.
  if (!managedPushEnabled(env)) return failure(404, "Managed encrypted push is not enabled");
  if (url.pathname === "/.well-known/drel-managed-push.json" && request.method === "GET") {
    if (!(await signerIsReady(env))) return failure(503, "Managed encrypted signer is temporarily unavailable");
    return json(managedDescriptor(request));
  }
  if (url.pathname === "/managed-push/health" && request.method === "GET") {
    const apnsReady = await signerIsReady(env);
    return json({ status: apnsReady ? "ok" : "unavailable", apnsReady }, apnsReady ? 200 : 503);
  }
  const id = env.MANAGED_PUSH_REGISTRY.idFromName("managed-encrypted-push-v1");
  return env.MANAGED_PUSH_REGISTRY.get(id).fetch(request);
}
