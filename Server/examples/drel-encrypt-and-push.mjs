#!/usr/bin/env node
/**
 * Sends one Drel self-hosted push without disclosing title/body to the relay.
 * Requires Node.js 20+ and its built-in crypto module only.
 *
 * Usage:
 *   node drel-encrypt-and-push.mjs https://push.example.com <deviceKey> \
 *     'Build finished' 'Code 482901' [https://drel.app/]
 */
import {
  createCipheriv,
  createPublicKey,
  diffieHellman,
  generateKeyPairSync,
  hkdfSync,
  randomBytes,
  randomUUID,
} from "node:crypto";

const [serverInput, deviceKey, title, body, url] = process.argv.slice(2);
if (!serverInput || !deviceKey || title === undefined || body === undefined) {
  console.error("Usage: node drel-encrypt-and-push.mjs <https-server> <deviceKey> <title> <body> [url]");
  process.exit(64);
}

const server = new URL(serverInput);
if (server.protocol !== "https:") {
  throw new Error("A production self-hosted Drel server must use HTTPS.");
}
server.pathname = server.pathname.replace(/\/$/, "");

const recipientResponse = await fetch(
  new URL(`/self-hosted/recipients/${encodeURIComponent(deviceKey)}`, server)
);
if (!recipientResponse.ok) {
  throw new Error(`Recipient discovery failed: HTTP ${recipientResponse.status}`);
}
const recipient = await recipientResponse.json();
if (recipient.schema !== "drel.self-hosted-recipient.v1" || !recipient.encryptionPublicKey) {
  throw new Error("The server did not return a Drel encrypted recipient.");
}

const schema = "drel.push-envelope.v1";
const messageId = randomUUID();
const createdAt = Math.floor(Date.now() / 1000);
const expiresAt = createdAt + 3600;
const innerPayload = { title, body, messageId };
if (url) innerPayload.url = url;

// X25519 raw public keys are wrapped in the standard SPKI DER prefix expected
// by Node's crypto API. This public key cannot decrypt messages.
const x25519SPKIPrefix = Buffer.from("302a300506032b656e032100", "hex");
const recipientRaw = Buffer.from(recipient.encryptionPublicKey, "base64url");
if (recipientRaw.length !== 32) throw new Error("Recipient public key is invalid.");
const recipientPublicKey = createPublicKey({
  key: Buffer.concat([x25519SPKIPrefix, recipientRaw]),
  format: "der",
  type: "spki",
});
const ephemeral = generateKeyPairSync("x25519");
const sharedSecret = diffieHellman({ privateKey: ephemeral.privateKey, publicKey: recipientPublicKey });
const info = Buffer.from(`${schema}|${messageId}|${createdAt}|${expiresAt}`, "utf8");
const aesKey = Buffer.from(hkdfSync("sha256", sharedSecret, Buffer.alloc(0), info, 32));
const nonce = randomBytes(12);
const cipher = createCipheriv("aes-256-gcm", aesKey, nonce);
const ciphertext = Buffer.concat([
  // CryptoKit AES.GCM.SealedBox(combined:) expects nonce || ciphertext || tag.
  nonce,
  cipher.update(JSON.stringify(innerPayload), "utf8"),
  cipher.final(),
  cipher.getAuthTag(),
]);
const ephemeralDER = ephemeral.publicKey.export({ format: "der", type: "spki" });
const envelope = {
  schema,
  messageID: messageId,
  createdAt,
  expiresAt,
  ephemeralPublicKey: Buffer.from(ephemeralDER).subarray(-32).toString("base64url"),
  ciphertext: ciphertext.toString("base64url"),
};
const drelEnvelope = Buffer.from(JSON.stringify(envelope), "utf8").toString("base64url");

const pushResponse = await fetch(new URL("/push", server), {
  method: "POST",
  headers: { "content-type": "application/json" },
  // The relay receives no title, body, URL, or other message content.
  body: JSON.stringify({ deviceKey, title: "", body: "", drelEnvelope }),
});
if (!pushResponse.ok) {
  throw new Error(`Push request failed: HTTP ${pushResponse.status} ${await pushResponse.text()}`);
}
console.log(`Encrypted push accepted (messageId ${messageId}).`);
