package main

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestValidEnvelopeAcceptsOnlyShortLivedStrictEnvelope(t *testing.T) {
	key := base64.RawURLEncoding.EncodeToString(make([]byte, 32))
	now := time.Now().Unix()
	encoded, err := json.Marshal(envelope{
		Schema: envelopeSchema, MessageID: "m1", CreatedAt: now - 1, ExpiresAt: now + 60,
		EphemeralPublicKey: key, Ciphertext: "opaque",
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := validEnvelope(base64.RawURLEncoding.EncodeToString(encoded)); !ok {
		t.Fatal("expected a valid strict envelope")
	}
	forged, _ := json.Marshal(envelope{
		Schema: envelopeSchema, MessageID: "m1", CreatedAt: now - 700, ExpiresAt: now + 1,
		EphemeralPublicKey: key, Ciphertext: "opaque",
	})
	if _, ok := validEnvelope(base64.RawURLEncoding.EncodeToString(forged)); ok {
		t.Fatal("accepted an envelope beyond the ten-minute maximum lifetime")
	}
}

func TestPairingsAreBoundedAndSingleUse(t *testing.T) {
	s, err := newStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	token, _, err := s.issue("127.0.0.1")
	if err != nil {
		t.Fatal(err)
	}
	if !s.consume(token) {
		t.Fatal("first pairing use must succeed")
	}
	if s.consume(token) {
		t.Fatal("pairing token replay must fail")
	}
	for i := 0; i < 5; i++ {
		if _, _, err := s.issue("127.0.0.1"); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, err := s.issue("127.0.0.1"); err == nil {
		t.Fatal("expected per-IP pairing rate limit")
	}
}

type capturedAPNS struct {
	mu       sync.Mutex
	requests []map[string]any
}

func newEndToEndServer(t *testing.T) (*server, *capturedAPNS) {
	t.Helper()
	captured := &capturedAPNS{}
	apnsStub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("authorization") == "" || r.Header.Get("apns-topic") != "com.webbridgekit.superapp" {
			t.Errorf("missing APNs authorization or topic")
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Errorf("decode APNs payload: %v", err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		captured.mu.Lock()
		captured.requests = append(captured.requests, payload)
		captured.mu.Unlock()
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(apnsStub.Close)
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	st, err := newStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	c := config{PublicURL: "https://push.example.test", APNSKeyID: "KEY", APNSTeamID: "TEAM", APNSTopic: "com.webbridgekit.superapp", APNSEnv: "production"}
	return &server{cfg: c, store: st, apns: newAPNSWithClient(c, key, apnsStub.Client(), apnsStub.URL)}, captured
}

func jsonRequest(t *testing.T, h http.Handler, method, path string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var reader *bytes.Reader
	if body == nil {
		reader = bytes.NewReader(nil)
	} else {
		encoded, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		reader = bytes.NewReader(encoded)
	}
	req := httptest.NewRequest(method, path, reader)
	req.Header.Set("content-type", "application/json")
	response := httptest.NewRecorder()
	h.ServeHTTP(response, req)
	return response
}

func pairAndRegister(t *testing.T, s *server) (http.Handler, string) {
	t.Helper()
	h := s.handler()
	pair := jsonRequest(t, h, http.MethodPost, "/self-hosted/pairings", nil)
	if pair.Code != http.StatusOK {
		t.Fatalf("pair returned %d: %s", pair.Code, pair.Body.String())
	}
	var pairing struct {
		Token string `json:"pairingToken"`
	}
	if err := json.NewDecoder(pair.Body).Decode(&pairing); err != nil {
		t.Fatal(err)
	}
	deviceKey := "device-key-for-test"
	publicKey := base64.RawURLEncoding.EncodeToString(make([]byte, 32))
	registered := jsonRequest(t, h, http.MethodPost, "/self-hosted/register", map[string]string{
		"pairingToken": pairing.Token, "deviceToken": "device-token-for-test", "deviceKey": deviceKey, "encryptionPublicKey": publicKey,
	})
	if registered.Code != http.StatusOK {
		t.Fatalf("register returned %d: %s", registered.Code, registered.Body.String())
	}
	return h, deviceKey
}

func TestDirectEncryptedAndRevokedLifecycle(t *testing.T) {
	s, captured := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)

	direct := jsonRequest(t, h, http.MethodPost, "/push", map[string]string{
		"deviceKey": deviceKey, "title": "Deployment complete", "body": "Build 61", "url": "https://drel.app/",
	})
	if direct.Code != http.StatusOK {
		t.Fatalf("direct push returned %d: %s", direct.Code, direct.Body.String())
	}
	captured.mu.Lock()
	if len(captured.requests) != 1 {
		t.Fatalf("expected one APNs request, got %d", len(captured.requests))
	}
	plain := captured.requests[0]
	captured.mu.Unlock()
	if plain["url"] != "https://drel.app/" || plain["drelEnvelope"] != nil {
		t.Fatalf("direct payload was not passed as an ordinary APNs message: %#v", plain)
	}
	if plain["drelSourceChannel"] != "drel.selfhosted.https://push.example.test" {
		t.Fatalf("direct payload did not carry the relay-owned source label: %#v", plain)
	}

	now := time.Now().Unix()
	envelopeJSON, err := json.Marshal(envelope{Schema: envelopeSchema, MessageID: "encrypted-message", CreatedAt: now - 1, ExpiresAt: now + 60, EphemeralPublicKey: base64.RawURLEncoding.EncodeToString(make([]byte, 32)), Ciphertext: "opaque"})
	if err != nil {
		t.Fatal(err)
	}
	encrypted := jsonRequest(t, h, http.MethodPost, "/push", map[string]string{"deviceKey": deviceKey, "drelEnvelope": base64.RawURLEncoding.EncodeToString(envelopeJSON)})
	if encrypted.Code != http.StatusOK {
		t.Fatalf("encrypted push returned %d: %s", encrypted.Code, encrypted.Body.String())
	}
	captured.mu.Lock()
	if len(captured.requests) != 2 {
		t.Fatalf("expected encrypted APNs request")
	}
	strict := captured.requests[1]
	captured.mu.Unlock()
	if strict["drelEnvelope"] == nil || strict["url"] != nil {
		t.Fatalf("strict payload exposed outer content: %#v", strict)
	}
	if strict["drelSourceChannel"] != "drel.selfhosted.https://push.example.test" {
		t.Fatalf("encrypted payload did not carry the relay-owned source label: %#v", strict)
	}

	revoked := jsonRequest(t, h, http.MethodPost, "/unregister", map[string]string{"deviceToken": "device-token-for-test", "key": deviceKey})
	if revoked.Code != http.StatusOK {
		t.Fatalf("unregister returned %d: %s", revoked.Code, revoked.Body.String())
	}
	afterRevoke := jsonRequest(t, h, http.MethodPost, "/push", map[string]string{"deviceKey": deviceKey, "title": "must not deliver"})
	if afterRevoke.Code != http.StatusNotFound {
		t.Fatalf("revoked key still delivered: %d", afterRevoke.Code)
	}
}

func TestBarkURLUsesTheDirectDeliveryPath(t *testing.T) {
	s, captured := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)
	request := httptest.NewRequest(http.MethodGet, "/"+deviceKey+"/Build%20ready/Inspect%20the%20result?url=https%3A%2F%2Fdrel.app%2F", nil)
	response := httptest.NewRecorder()
	h.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("Bark URL returned %d: %s", response.Code, response.Body.String())
	}
	captured.mu.Lock()
	defer captured.mu.Unlock()
	if len(captured.requests) != 1 || captured.requests[0]["drelEnvelope"] != nil {
		t.Fatalf("Bark URL did not use direct mode: %#v", captured.requests)
	}
}

func TestPushDiscoveryNegotiatesHTMLMarkdownAndJSON(t *testing.T) {
	s, _ := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)

	checks := []struct {
		path, accept, contentType, marker string
	}{
		{"/" + deviceKey, "text/html", "text/html", "Drel Push Discovery"},
		{"/" + deviceKey + ".md", "", "text/markdown", "# Drel Push Discovery"},
		{"/" + deviceKey + "?format=markdown", "text/html", "text/markdown", "## Quick start"},
		{"/" + deviceKey + "?format=json", "text/html", "application/json", `"schema":"drel.push-discovery.v1"`},
	}
	for _, check := range checks {
		req := httptest.NewRequest(http.MethodGet, check.path, nil)
		req.Header.Set("accept", check.accept)
		response := httptest.NewRecorder()
		h.ServeHTTP(response, req)
		if response.Code != http.StatusOK || !strings.Contains(response.Header().Get("content-type"), check.contentType) || !strings.Contains(response.Body.String(), check.marker) {
			t.Fatalf("discovery %s failed: status=%d type=%q body=%s", check.path, response.Code, response.Header().Get("content-type"), response.Body.String())
		}
		if response.Header().Get("cache-control") != "no-store" || response.Header().Get("x-robots-tag") != "noindex, nofollow" || response.Header().Get("referrer-policy") != "no-referrer" {
			t.Fatalf("discovery security headers missing for %s", check.path)
		}
	}
}

func TestPushDiscoveryRequiresARegisteredKey(t *testing.T) {
	s, _ := newEndToEndServer(t)
	response := httptest.NewRecorder()
	s.handler().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/unknown-key?format=json", nil))
	if response.Code != http.StatusNotFound {
		t.Fatalf("unknown discovery key returned %d", response.Code)
	}
}

func TestDirectPushPreservesOfficialRoutingAndPresentationFields(t *testing.T) {
	s, captured := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)
	urlTarget := "https://pi-chat.example.test:8443/?token=demo-test-token"
	request := httptest.NewRequest(
		http.MethodGet,
		"/"+deviceKey+"/1112?mode=immersive&display=full&group=deploy&badge=3&level=time-sensitive&url="+url.QueryEscape(urlTarget),
		nil,
	)
	response := httptest.NewRecorder()
	h.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("Bark URL returned %d: %s", response.Code, response.Body.String())
	}

	captured.mu.Lock()
	defer captured.mu.Unlock()
	if len(captured.requests) != 1 {
		t.Fatalf("expected one APNs request, got %#v", captured.requests)
	}
	payload := captured.requests[0]
	if payload["mode"] != "immersive" || payload["display"] != "full" || payload["url"] != urlTarget {
		t.Fatalf("direct route fields were dropped: %#v", payload)
	}
	if payload["group"] != "deploy" || payload["level"] != "time-sensitive" {
		t.Fatalf("direct presentation fields were dropped: %#v", payload)
	}
	aps, ok := payload["aps"].(map[string]any)
	if !ok || aps["badge"] != float64(3) || aps["interruption-level"] != "time-sensitive" {
		t.Fatalf("APNs alert fields do not match the official contract: %#v", payload)
	}
}

func TestJSONDirectPushPreservesTheExtendedOfficialContract(t *testing.T) {
	s, captured := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)
	response := jsonRequest(t, h, http.MethodPost, "/push", map[string]any{
		"deviceKey":    deviceKey,
		"schema":       "webbridgekit.message.v1",
		"type":         "markdown",
		"title":        "Release note",
		"body":         "**Drel** is ready",
		"markdown":     "**Drel** is ready",
		"threadId":     "deployments",
		"copy":         "release-token",
		"autoCopy":     true,
		"appId":        "drel.demo",
		"route":        "/release/62",
		"mode":         "immersive",
		"display":      "full",
		"presentation": "native",
		"params":       map[string]string{"source": "self-hosted"},
	})
	if response.Code != http.StatusOK {
		t.Fatalf("JSON push returned %d: %s", response.Code, response.Body.String())
	}
	captured.mu.Lock()
	defer captured.mu.Unlock()
	if len(captured.requests) != 1 {
		t.Fatalf("expected one APNs request, got %#v", captured.requests)
	}
	payload := captured.requests[0]
	for key, want := range map[string]any{
		"schema": "webbridgekit.message.v1", "type": "markdown", "markdown": "**Drel** is ready",
		"threadId": "deployments", "copy": "release-token", "appId": "drel.demo", "route": "/release/62",
		"mode": "immersive", "display": "full", "presentation": "native", "state": "",
	} {
		if key == "state" {
			if _, exists := payload[key]; exists {
				t.Fatalf("state should be absent without an action state: %#v", payload)
			}
			continue
		}
		if payload[key] != want {
			t.Fatalf("JSON field %s was not forwarded: %#v", key, payload)
		}
	}
	if payload["autoCopy"] != true {
		t.Fatalf("JSON boolean field was not forwarded: %#v", payload)
	}
	params, ok := payload["params"].(map[string]any)
	if !ok || params["source"] != "self-hosted" {
		t.Fatalf("JSON params were not forwarded: %#v", payload)
	}
	aps, ok := payload["aps"].(map[string]any)
	if !ok || aps["thread-id"] != "deployments" || aps["category"] != "DREL_COPY" {
		t.Fatalf("JSON APNs fields do not match the official contract: %#v", payload)
	}
}

func TestJSONDirectPushCarriesEveryDocumentedPortableField(t *testing.T) {
	s, captured := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)
	response := jsonRequest(t, h, http.MethodPost, "/push", map[string]any{
		"deviceKey": deviceKey, "schema": "webbridgekit.message.v1", "type": "approval",
		"title": "Complete contract", "body": "Every portable field", "subtitle": "sub", "category": "deploy",
		"markdown": "**Every portable field**", "sound": "bell.caf", "badge": 7, "icon": "https://example.test/icon.png",
		"image": "https://example.test/image.png", "group": "release", "threadId": "thread-1", "url": "https://example.test/full",
		"copy": "copy-value", "isArchive": true, "level": "time-sensitive", "volume": 0.6, "call": true,
		"autoCopy": true, "appId": "drel.demo", "route": "/release", "mode": "immersive", "display": "full",
		"verificationCode": "482901", "expiresAt": "2026-09-08T16:00:00Z", "ttl": 90.5, "id": "replace-1",
		"delete": true, "actionState": "pending", "requestId": "request-1", "contentType": "approval",
		"qrPayload": "drel://qr", "statePath": "/state/1", "revision": 4, "params": map[string]string{"env": "test"},
		"presentation": "native", "approval": map[string]any{"actions": []map[string]any{{"id": "approve", "title": "Approve"}}},
	})
	if response.Code != http.StatusOK {
		t.Fatalf("complete JSON push returned %d: %s", response.Code, response.Body.String())
	}
	captured.mu.Lock()
	defer captured.mu.Unlock()
	if len(captured.requests) != 1 {
		t.Fatalf("expected one APNs request, got %#v", captured.requests)
	}
	payload := captured.requests[0]
	for key, want := range map[string]string{
		"schema": "webbridgekit.message.v1", "type": "approval", "title": "Complete contract", "body": "Every portable field",
		"subtitle": "sub", "category": "deploy", "markdown": "**Every portable field**", "sound": "bell.caf",
		"icon": "https://example.test/icon.png", "image": "https://example.test/image.png", "group": "release",
		"threadId": "thread-1", "url": "https://example.test/full", "copy": "copy-value", "level": "time-sensitive",
		"appId": "drel.demo", "route": "/release", "mode": "immersive", "display": "full", "verificationCode": "482901",
		"expiresAt": "2026-09-08T16:00:00Z", "id": "replace-1", "delete": "", "actionState": "pending",
		"state": "pending", "requestId": "request-1", "contentType": "approval", "qrPayload": "drel://qr",
		"statePath": "/state/1", "presentation": "native", "drelSourceChannel": "drel.selfhosted.https://push.example.test",
	} {
		if key == "delete" {
			if payload[key] != true {
				t.Fatalf("field %s was not forwarded: %#v", key, payload)
			}
			continue
		}
		if payload[key] != want {
			t.Fatalf("field %s was not forwarded: %#v", key, payload)
		}
	}
	for key, want := range map[string]any{"badge": float64(7), "isArchive": true, "volume": 0.6, "call": true, "autoCopy": true, "ttl": 90.5, "revision": float64(4)} {
		if payload[key] != want {
			t.Fatalf("typed field %s was not forwarded: %#v", key, payload)
		}
	}
	params, ok := payload["params"].(map[string]any)
	if !ok || params["env"] != "test" {
		t.Fatalf("params were not forwarded: %#v", payload)
	}
	approval, ok := payload["approval"].(map[string]any)
	if !ok || approval["actions"] == nil {
		t.Fatalf("approval payload was not forwarded: %#v", payload)
	}
	aps, ok := payload["aps"].(map[string]any)
	if !ok || aps["sound"] != "bell.caf" || aps["badge"] != float64(7) || aps["thread-id"] != "thread-1" || aps["interruption-level"] != "time-sensitive" || aps["category"] != "DREL_COPY" || aps["content-available"] != float64(1) {
		t.Fatalf("APNs metadata does not match the official contract: %#v", payload)
	}
}

func TestEncryptedPushRejectsAnyPlaintextPresentationWrapper(t *testing.T) {
	s, _ := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)
	now := time.Now().Unix()
	encoded, err := json.Marshal(envelope{
		Schema: envelopeSchema, MessageID: "encrypted-message", CreatedAt: now - 1, ExpiresAt: now + 60,
		EphemeralPublicKey: base64.RawURLEncoding.EncodeToString(make([]byte, 32)), Ciphertext: "opaque",
	})
	if err != nil {
		t.Fatal(err)
	}
	response := jsonRequest(t, h, http.MethodPost, "/push", map[string]string{
		"deviceKey": deviceKey, "drelEnvelope": base64.RawURLEncoding.EncodeToString(encoded), "mode": "immersive",
	})
	if response.Code != http.StatusBadRequest {
		t.Fatalf("encrypted push accepted a plaintext presentation wrapper: %d %s", response.Code, response.Body.String())
	}
}

func TestDirectPushRejectsSenderSuppliedSourceChannel(t *testing.T) {
	s, _ := newEndToEndServer(t)
	h, deviceKey := pairAndRegister(t, s)
	response := jsonRequest(t, h, http.MethodPost, "/push", map[string]string{
		"deviceKey": deviceKey, "title": "spoof", "drelSourceChannel": "official",
	})
	if response.Code != http.StatusBadRequest {
		t.Fatalf("sender-controlled source label should be rejected, got %d %s", response.Code, response.Body.String())
	}
}
