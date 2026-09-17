// Drel's native self-hosted push relay.  It is deliberately dependency-free
// so the target machine needs neither Docker nor a Swift toolchain.
package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"html"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const envelopeSchema = "drel.push-envelope.v1"

type config struct {
	ListenAddr string
	PublicURL  string
	Name       string
	DataDir    string
	APNSKeyID  string
	APNSTeamID string
	APNSKey    string
	APNSTopic  string
	APNSEnv    string
}

type registration struct {
	DeviceToken         string `json:"deviceToken"`
	DeviceKey           string `json:"deviceKey"`
	EncryptionPublicKey string `json:"encryptionPublicKey"`
	Platform            string `json:"platform,omitempty"`
	AppVersion          string `json:"appVersion,omitempty"`
	// SourceChannel is assigned by this relay from its own public URL. It is
	// never accepted from a sender and exists only for Drel's local inbox view.
	SourceChannel string `json:"sourceChannel,omitempty"`
}

type pairing struct{ Expiry time.Time }
type rateBucket struct {
	Started time.Time
	Count   int
}

type store struct {
	mu            sync.Mutex
	registrations map[string]registration
	pairings      map[string]pairing
	rates         map[string]rateBucket
	dataFile      string
}

func newStore(dataDir string) (*store, error) {
	if err := os.MkdirAll(dataDir, 0700); err != nil {
		return nil, err
	}
	s := &store{registrations: map[string]registration{}, pairings: map[string]pairing{}, rates: map[string]rateBucket{}, dataFile: filepath.Join(dataDir, "drel-registrations.json")}
	if data, err := os.ReadFile(s.dataFile); err == nil {
		if err := json.Unmarshal(data, &s.registrations); err != nil {
			return nil, fmt.Errorf("read registrations: %w", err)
		}
	}
	return s, nil
}

func (s *store) saveLocked() error {
	data, err := json.Marshal(s.registrations)
	if err != nil {
		return err
	}
	tmp := s.dataFile + ".tmp"
	if err := os.WriteFile(tmp, data, 0600); err != nil {
		return err
	}
	return os.Rename(tmp, s.dataFile)
}

func (s *store) issue(ip string) (string, time.Time, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	for digest, ticket := range s.pairings {
		if !ticket.Expiry.After(now) {
			delete(s.pairings, digest)
		}
	}
	bucket := s.rates[ip]
	if bucket.Started.IsZero() || now.Sub(bucket.Started) >= time.Minute {
		bucket = rateBucket{Started: now}
	}
	if bucket.Count >= 6 {
		return "", time.Time{}, errors.New("pairing requests are rate limited; try again shortly")
	}
	bucket.Count++
	s.rates[ip] = bucket
	if len(s.pairings) >= 256 {
		return "", time.Time{}, errors.New("too many outstanding pairing tickets; try again shortly")
	}
	raw := make([]byte, 24)
	if _, err := rand.Read(raw); err != nil {
		return "", time.Time{}, err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	expiry := now.Add(10 * time.Minute)
	s.pairings[digestToken(token)] = pairing{Expiry: expiry}
	return token, expiry, nil
}

func (s *store) consume(token string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	digest := digestToken(token)
	ticket, ok := s.pairings[digest]
	delete(s.pairings, digest)
	return ok && ticket.Expiry.After(time.Now())
}

func (s *store) register(r registration) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.registrations[r.DeviceKey] = r
	return s.saveLocked()
}
func (s *store) recipient(key string) (registration, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	r, ok := s.registrations[key]
	return r, ok
}
func (s *store) unregister(deviceToken, key string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	r, ok := s.registrations[key]
	if !ok || r.DeviceToken != deviceToken {
		return false, nil
	}
	delete(s.registrations, key)
	return true, s.saveLocked()
}
func digestToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return fmt.Sprintf("%x", sum[:])
}

type envelope struct {
	Schema             string `json:"schema"`
	MessageID          string `json:"messageID"`
	CreatedAt          int64  `json:"createdAt"`
	ExpiresAt          int64  `json:"expiresAt"`
	EphemeralPublicKey string `json:"ephemeralPublicKey"`
	Ciphertext         string `json:"ciphertext"`
}

// pushRequest deliberately mirrors the official PushPayload contract for
// direct delivery. A self-hosted URL must not silently turn into a reduced
// API merely because it is served by the portable Go relay. Fields are kept
// typed so the APNs payload remains property-list/JSON safe for the Drel NSE.
type pushRequest struct {
	DeviceKey        string            `json:"deviceKey"`
	LegacyDeviceKey  string            `json:"device_key"`
	Schema           string            `json:"schema,omitempty"`
	Type             string            `json:"type,omitempty"`
	Title            string            `json:"title"`
	Body             string            `json:"body"`
	Subtitle         string            `json:"subtitle,omitempty"`
	Category         string            `json:"category,omitempty"`
	Markdown         string            `json:"markdown,omitempty"`
	Sound            string            `json:"sound,omitempty"`
	Badge            *int              `json:"badge,omitempty"`
	Icon             string            `json:"icon,omitempty"`
	Image            string            `json:"image,omitempty"`
	Group            string            `json:"group,omitempty"`
	ThreadID         string            `json:"threadId,omitempty"`
	URL              string            `json:"url,omitempty"`
	Copy             string            `json:"copy,omitempty"`
	IsArchive        *bool             `json:"isArchive,omitempty"`
	Level            string            `json:"level,omitempty"`
	Volume           *float64          `json:"volume,omitempty"`
	IsCall           *bool             `json:"call,omitempty"`
	AutoCopy         *bool             `json:"autoCopy,omitempty"`
	LegacyAutoCopy   *bool             `json:"automaticallyCopy,omitempty"`
	AppID            string            `json:"appId,omitempty"`
	LegacyAppID      string            `json:"appid,omitempty"`
	Route            string            `json:"route,omitempty"`
	Mode             string            `json:"mode,omitempty"`
	Display          string            `json:"display,omitempty"`
	VerificationCode string            `json:"verificationCode,omitempty"`
	ExpiresAt        string            `json:"expiresAt,omitempty"`
	TTL              *float64          `json:"ttl,omitempty"`
	ReplacementID    string            `json:"id,omitempty"`
	IsDeleted        *bool             `json:"delete,omitempty"`
	ActionState      string            `json:"actionState,omitempty"`
	State            string            `json:"state,omitempty"`
	RequestID        string            `json:"requestId,omitempty"`
	ContentType      string            `json:"contentType,omitempty"`
	QRPayload        string            `json:"qrPayload,omitempty"`
	StatePath        string            `json:"statePath,omitempty"`
	Revision         *int              `json:"revision,omitempty"`
	Params           map[string]string `json:"params,omitempty"`
	Presentation     string            `json:"presentation,omitempty"`
	Approval         map[string]any    `json:"approval,omitempty"`
	Envelope         string            `json:"drelEnvelope"`
}

func (p *pushRequest) normalize() {
	if p.DeviceKey == "" {
		p.DeviceKey = p.LegacyDeviceKey
	}
	if p.AutoCopy == nil {
		p.AutoCopy = p.LegacyAutoCopy
	}
	if p.AppID == "" {
		p.AppID = p.LegacyAppID
	}
	if p.ActionState == "" {
		p.ActionState = p.State
	}
	if p.ContentType == "" {
		p.ContentType = p.Type
	}
}

func (p pushRequest) hasDirectContentOrAction() bool {
	return p.Title != "" || p.Body != "" || p.Badge != nil || p.IsDeleted != nil || p.ReplacementID != ""
}

// hasOuterFields protects the opaque envelope route. No sender-controlled
// field, including a presentation mode, may accompany encrypted content.
func (p pushRequest) hasOuterFields() bool {
	return p.Schema != "" || p.Type != "" || p.Title != "" || p.Body != "" || p.Subtitle != "" ||
		p.Category != "" || p.Markdown != "" || p.Sound != "" || p.Badge != nil || p.Icon != "" ||
		p.Image != "" || p.Group != "" || p.ThreadID != "" || p.URL != "" || p.Copy != "" ||
		p.IsArchive != nil || p.Level != "" || p.Volume != nil || p.IsCall != nil || p.AutoCopy != nil ||
		p.LegacyAutoCopy != nil || p.AppID != "" || p.LegacyAppID != "" || p.Route != "" ||
		p.Mode != "" || p.Display != "" || p.VerificationCode != "" || p.ExpiresAt != "" ||
		p.TTL != nil || p.ReplacementID != "" || p.IsDeleted != nil || p.ActionState != "" ||
		p.State != "" || p.RequestID != "" || p.ContentType != "" || p.QRPayload != "" ||
		p.StatePath != "" || p.Revision != nil || len(p.Params) != 0 || p.Presentation != "" ||
		len(p.Approval) != 0
}

func (p pushRequest) messageID() string {
	if p.ReplacementID != "" {
		return p.ReplacementID
	}
	if p.RequestID != "" {
		return p.RequestID
	}
	return newMessageID()
}

func queryBool(query url.Values, key string) *bool {
	switch strings.ToLower(query.Get(key)) {
	case "1", "true":
		value := true
		return &value
	case "0", "false":
		value := false
		return &value
	default:
		return nil
	}
}

func queryInt(query url.Values, key string) *int {
	value := query.Get(key)
	if value == "" {
		return nil
	}
	var parsed int
	if _, err := fmt.Sscan(value, &parsed); err != nil {
		return nil
	}
	return &parsed
}

func queryFloat(query url.Values, key string) *float64 {
	value := query.Get(key)
	if value == "" {
		return nil
	}
	var parsed float64
	if _, err := fmt.Sscan(value, &parsed); err != nil {
		return nil
	}
	return &parsed
}

func queryPushRequest(deviceKey string, query url.Values) pushRequest {
	markdown := query.Get("markdown")
	if markdown == "1" || strings.EqualFold(markdown, "true") {
		markdown = query.Get("body")
	}
	input := pushRequest{
		DeviceKey: deviceKey, Schema: query.Get("schema"), Type: query.Get("type"), Title: query.Get("title"), Body: query.Get("body"),
		Subtitle: query.Get("subtitle"), Category: query.Get("category"), Markdown: markdown, Sound: query.Get("sound"),
		Badge: queryInt(query, "badge"), Icon: query.Get("icon"), Image: query.Get("image"), Group: query.Get("group"),
		ThreadID: query.Get("threadId"), URL: query.Get("url"), Copy: query.Get("copy"), IsArchive: queryBool(query, "isArchive"),
		Level: query.Get("level"), Volume: queryFloat(query, "volume"), IsCall: queryBool(query, "call"),
		AutoCopy: queryBool(query, "autoCopy"), LegacyAutoCopy: queryBool(query, "automaticallyCopy"),
		AppID: query.Get("appId"), LegacyAppID: query.Get("appid"), Route: query.Get("route"), Mode: query.Get("mode"),
		Display: query.Get("display"), VerificationCode: query.Get("verificationCode"), ExpiresAt: query.Get("expiresAt"),
		TTL: queryFloat(query, "ttl"), ReplacementID: query.Get("id"), IsDeleted: queryBool(query, "delete"),
		ActionState: query.Get("actionState"), State: query.Get("state"), RequestID: query.Get("requestId"),
		ContentType: query.Get("contentType"), QRPayload: query.Get("qrPayload"), StatePath: query.Get("statePath"),
		Revision: queryInt(query, "revision"), Presentation: query.Get("presentation"),
	}
	input.normalize()
	return input
}

type apns struct {
	cfg      config
	key      *ecdsa.PrivateKey
	client   *http.Client
	token    string
	issued   time.Time
	endpoint string
	mu       sync.Mutex
}

func newAPNS(c config) (*apns, error) {
	if c.APNSKeyID == "" || c.APNSTeamID == "" || c.APNSKey == "" || c.APNSTopic == "" {
		return nil, errors.New("APNs is not configured")
	}
	data, err := os.ReadFile(c.APNSKey)
	if err != nil {
		return nil, err
	}
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, errors.New("invalid APNs p8 file")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok || key.Curve != elliptic.P256() {
		return nil, errors.New("APNs key must be P-256 ECDSA")
	}
	endpoint := "https://api.push.apple.com"
	if strings.EqualFold(c.APNSEnv, "sandbox") {
		endpoint = "https://api.sandbox.push.apple.com"
	}
	return newAPNSWithClient(c, key, &http.Client{Timeout: 15 * time.Second, Transport: &http.Transport{ForceAttemptHTTP2: true}}, endpoint), nil
}
func newAPNSWithClient(c config, key *ecdsa.PrivateKey, client *http.Client, endpoint string) *apns {
	return &apns{cfg: c, key: key, client: client, endpoint: strings.TrimRight(endpoint, "/")}
}
func (a *apns) jwt() (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.token != "" && time.Since(a.issued) < 50*time.Minute {
		return a.token, nil
	}
	header, _ := json.Marshal(map[string]string{"alg": "ES256", "kid": a.cfg.APNSKeyID})
	payload, _ := json.Marshal(map[string]any{"iss": a.cfg.APNSTeamID, "iat": time.Now().Unix()})
	base := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	hash := sha256.Sum256([]byte(base))
	r, s, err := ecdsa.Sign(rand.Reader, a.key, hash[:])
	if err != nil {
		return "", err
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	a.token = base + "." + base64.RawURLEncoding.EncodeToString(sig)
	a.issued = time.Now()
	return a.token, nil
}
func (a *apns) sendPayload(token string, payload map[string]any) error {
	jwt, err := a.jwt()
	if err != nil {
		return err
	}
	encoded, _ := json.Marshal(payload)
	req, err := http.NewRequest(http.MethodPost, a.endpoint+"/3/device/"+url.PathEscape(token), strings.NewReader(string(encoded)))
	if err != nil {
		return err
	}
	req.Header.Set("authorization", "bearer "+jwt)
	req.Header.Set("apns-topic", a.cfg.APNSTopic)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")
	req.Header.Set("content-type", "application/json")
	resp, err := a.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		return fmt.Errorf("APNs %s: %s", resp.Status, strings.TrimSpace(string(b)))
	}
	return nil
}

func (a *apns) sendEnvelope(token, opaque, messageID, sourceChannel string) error {
	payload := map[string]any{
		"aps":          map[string]any{"alert": map[string]string{"title": "", "body": ""}, "sound": "default", "mutable-content": 1},
		"drelEnvelope": opaque,
		"messageId":    messageID,
	}
	if sourceChannel != "" {
		payload["drelSourceChannel"] = sourceChannel
	}
	return a.sendPayload(token, payload)
}

func (a *apns) sendPlain(token string, input pushRequest, messageID, sourceChannel string) error {
	aps := map[string]any{"alert": map[string]string{"title": input.Title, "body": input.Body}, "mutable-content": 1}
	// Keep the official passive semantic: a passive notification must not carry
	// a sound key at all, otherwise iOS may still play the default sound.
	if input.Level != "passive" {
		if input.Sound != "" {
			aps["sound"] = input.Sound
		} else {
			aps["sound"] = "default"
		}
	}
	if input.Badge != nil {
		aps["badge"] = *input.Badge
	}
	if input.ThreadID != "" {
		aps["thread-id"] = input.ThreadID
	} else if input.Group != "" {
		aps["thread-id"] = input.Group
	}
	switch input.Level {
	case "passive", "active":
		aps["interruption-level"] = input.Level
	case "timeSensitive", "time-sensitive":
		aps["interruption-level"] = "time-sensitive"
	}
	if input.Copy != "" {
		aps["category"] = "DREL_COPY"
	}
	if input.IsDeleted != nil && *input.IsDeleted {
		aps["content-available"] = 1
	}

	payload := map[string]any{
		"aps":       aps,
		"messageId": messageID,
		// The top-level summary is retained just like the official service so
		// the NSE and the foreground path produce the same inbox message.
		"title": input.Title,
		"body":  input.Body,
	}
	add := func(key string, value any, present bool) {
		if present {
			payload[key] = value
		}
	}
	add("schema", input.Schema, input.Schema != "")
	add("type", input.Type, input.Type != "")
	add("subtitle", input.Subtitle, input.Subtitle != "")
	add("category", input.Category, input.Category != "")
	add("markdown", input.Markdown, input.Markdown != "")
	add("sound", input.Sound, input.Sound != "")
	if input.Badge != nil {
		add("badge", *input.Badge, true)
	}
	add("icon", input.Icon, input.Icon != "")
	add("image", input.Image, input.Image != "")
	add("group", input.Group, input.Group != "")
	add("threadId", input.ThreadID, input.ThreadID != "")
	add("url", input.URL, input.URL != "")
	add("copy", input.Copy, input.Copy != "")
	if input.IsArchive != nil {
		add("isArchive", *input.IsArchive, true)
	}
	add("level", input.Level, input.Level != "")
	if input.Volume != nil {
		add("volume", *input.Volume, true)
	}
	if input.IsCall != nil {
		add("call", *input.IsCall, true)
	}
	if input.AutoCopy != nil {
		add("autoCopy", *input.AutoCopy, true)
	}
	add("appId", input.AppID, input.AppID != "")
	add("route", input.Route, input.Route != "")
	add("mode", input.Mode, input.Mode != "")
	add("display", input.Display, input.Display != "")
	add("verificationCode", input.VerificationCode, input.VerificationCode != "")
	add("expiresAt", input.ExpiresAt, input.ExpiresAt != "")
	if input.TTL != nil {
		add("ttl", *input.TTL, true)
	}
	add("id", input.ReplacementID, input.ReplacementID != "")
	if input.IsDeleted != nil {
		add("delete", *input.IsDeleted, true)
	}
	add("actionState", input.ActionState, input.ActionState != "")
	if input.Schema == "webbridgekit.message.v1" {
		add("state", input.ActionState, input.ActionState != "")
	}
	add("requestId", input.RequestID, input.RequestID != "")
	add("contentType", input.ContentType, input.ContentType != "")
	add("qrPayload", input.QRPayload, input.QRPayload != "")
	add("statePath", input.StatePath, input.StatePath != "")
	if input.Revision != nil {
		add("revision", *input.Revision, true)
	}
	add("params", input.Params, len(input.Params) != 0)
	add("presentation", input.Presentation, input.Presentation != "")
	add("approval", input.Approval, len(input.Approval) != 0)
	if sourceChannel != "" {
		payload["drelSourceChannel"] = sourceChannel
	}
	return a.sendPayload(token, payload)
}

type server struct {
	cfg   config
	store *store
	apns  *apns
}

func (s *server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "apnsReady": s.apns != nil})
}
func (s *server) descriptor(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"schema": "drel.self-hosted-push.v1", "name": s.cfg.Name, "publicBaseURL": s.cfg.PublicURL, "registrationPath": "/self-hosted/register", "pairingPath": "/self-hosted/pairings", "recipientPath": "/self-hosted/recipients/{deviceKey}", "pushPath": "/push", "unregisterPath": "/unregister", "healthPath": "/health", "deliveryModes": []string{"direct", "encrypted"}})
}

func (s *server) sourceChannelFor(item registration) string {
	if item.SourceChannel != "" {
		return item.SourceChannel
	}
	// Existing registrations predate the persisted field. Derive the same
	// server-owned label at delivery time so an operator upgrade never requires
	// a customer to pair again.
	return "drel.selfhosted." + strings.ToLower(strings.TrimRight(s.cfg.PublicURL, "/"))
}
func (s *server) createPairing(w http.ResponseWriter, r *http.Request) {
	if s.apns == nil {
		writeError(w, http.StatusServiceUnavailable, "APNs is not configured")
		return
	}
	token, expiry, err := s.store.issue(clientIP(r))
	if err != nil {
		writeError(w, http.StatusTooManyRequests, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"schema": "drel.self-hosted-pairing.v1", "pairingToken": token, "expiresAt": expiry.UTC().Format(time.RFC3339), "configurationURL": "drel://self-hosted-push?server=" + url.QueryEscape(s.cfg.PublicURL) + "&token=" + token})
}
func (s *server) register(w http.ResponseWriter, r *http.Request) {
	if s.apns == nil {
		writeError(w, 503, "APNs is not configured")
		return
	}
	var input struct {
		DeviceToken         string `json:"deviceToken"`
		DeviceKey           string `json:"deviceKey"`
		EncryptionPublicKey string `json:"encryptionPublicKey"`
		PairingToken        string `json:"pairingToken"`
		Platform            string `json:"platform"`
		AppVersion          string `json:"appVersion"`
	}
	if decodeJSON(w, r, &input) != nil || input.DeviceToken == "" || input.DeviceKey == "" || !validKey(input.EncryptionPublicKey) || !s.store.consume(input.PairingToken) {
		writeError(w, 400, "invalid or expired pairing registration")
		return
	}
	if err := s.store.register(registration{
		DeviceToken: input.DeviceToken, DeviceKey: input.DeviceKey,
		EncryptionPublicKey: input.EncryptionPublicKey, Platform: input.Platform,
		AppVersion:    input.AppVersion,
		SourceChannel: "drel.selfhosted." + strings.ToLower(strings.TrimRight(s.cfg.PublicURL, "/")),
	}); err != nil {
		writeError(w, 500, "registration could not be persisted")
		return
	}
	writeJSON(w, 200, map[string]any{"schema": "drel.self-hosted-registration.v1", "deviceKey": input.DeviceKey, "pushURL": strings.TrimRight(s.cfg.PublicURL, "/") + "/" + input.DeviceKey, "message": "Self-hosted direct and encrypted push are ready"})
}
func (s *server) recipient(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimPrefix(r.URL.Path, "/self-hosted/recipients/")
	if key == "" || strings.Contains(key, "/") {
		writeError(w, 400, "invalid device key")
		return
	}
	item, ok := s.store.recipient(key)
	if !ok {
		writeError(w, 404, "no paired encrypted recipient")
		return
	}
	writeJSON(w, 200, map[string]any{"schema": "drel.self-hosted-recipient.v1", "deviceKey": key, "encryptionPublicKey": item.EncryptionPublicKey, "pushPath": "/push", "envelopeSchema": envelopeSchema})
}
func (s *server) push(w http.ResponseWriter, r *http.Request) {
	if s.apns == nil {
		writeError(w, 503, "APNs is not configured")
		return
	}
	var input pushRequest
	if decodeJSON(w, r, &input) != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON push")
		return
	}
	input.normalize()
	if input.DeviceKey == "" {
		writeError(w, 400, "a deviceKey is required")
		return
	}
	recipient, ok := s.store.recipient(input.DeviceKey)
	if !ok {
		writeError(w, 404, "no paired recipient")
		return
	}
	if input.Envelope != "" {
		if input.hasOuterFields() {
			writeError(w, 400, "encrypted pushes cannot include outer message fields")
			return
		}
		env, ok := validEnvelope(input.Envelope)
		if !ok {
			writeError(w, 400, "invalid or expired drelEnvelope")
			return
		}
		if err := s.apns.sendEnvelope(recipient.DeviceToken, input.Envelope, env.MessageID, s.sourceChannelFor(recipient)); err != nil {
			log.Printf("APNs encrypted delivery failed for registered recipient: %v", err)
			writeError(w, 502, "APNs delivery failed")
			return
		}
		writeJSON(w, 200, map[string]any{"code": 200, "message": "encrypted push accepted", "messageId": env.MessageID})
		return
	}
	if !input.hasDirectContentOrAction() {
		writeError(w, 400, "a direct push needs a title, body, or supported action")
		return
	}
	messageID := input.messageID()
	if err := s.apns.sendPlain(recipient.DeviceToken, input, messageID, s.sourceChannelFor(recipient)); err != nil {
		log.Printf("APNs delivery failed for registered recipient: %v", err)
		writeError(w, 502, "APNs delivery failed")
		return
	}
	writeJSON(w, 200, map[string]any{"code": 200, "message": "direct push accepted", "messageId": messageID})
}

// barkPush keeps the short, copyable URL form for scripts. It is deliberately
// direct mode: content arrives at the server and is not claimed to be E2E.
func (s *server) barkPush(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/"), "/"), "/")
	if len(parts) == 0 || parts[0] == "" || len(parts) > 3 {
		writeError(w, 404, "not found")
		return
	}
	if len(parts) == 1 && r.URL.Query().Get("body") == "" && r.URL.Query().Get("title") == "" {
		s.pushDiscovery(w, r, strings.TrimSuffix(parts[0], ".md"), strings.HasSuffix(parts[0], ".md"))
		return
	}
	if s.apns == nil {
		writeError(w, 503, "APNs is not configured")
		return
	}
	input := queryPushRequest(parts[0], r.URL.Query())
	if len(parts) == 2 && input.Body == "" {
		input.Body = parts[1]
	}
	if len(parts) == 3 {
		if input.Title == "" {
			input.Title = parts[1]
		}
		if input.Body == "" {
			input.Body = parts[2]
		}
	}
	if !input.hasDirectContentOrAction() {
		writeError(w, 400, "a direct push needs a title, body, or supported action")
		return
	}
	recipient, ok := s.store.recipient(input.DeviceKey)
	if !ok {
		writeError(w, 404, "no paired recipient")
		return
	}
	messageID := input.messageID()
	if err := s.apns.sendPlain(recipient.DeviceToken, input, messageID, s.sourceChannelFor(recipient)); err != nil {
		log.Printf("APNs direct delivery failed for registered recipient: %v", err)
		writeError(w, 502, "APNs delivery failed")
		return
	}
	writeJSON(w, 200, map[string]any{"code": 200, "message": "direct push accepted", "messageId": messageID})
}

func (s *server) pushDiscovery(w http.ResponseWriter, r *http.Request, key string, markdownPath bool) {
	if _, ok := s.store.recipient(key); !ok {
		writeError(w, http.StatusNotFound, "no paired recipient")
		return
	}
	base := strings.TrimRight(s.cfg.PublicURL, "/")
	pushURL := base + "/" + key
	format := strings.ToLower(r.URL.Query().Get("format"))
	if format == "json" {
		w.Header().Set("x-robots-tag", "noindex, nofollow")
		writeJSON(w, 200, map[string]any{"schema": "drel.push-discovery.v1", "name": "Drel Push Discovery", "pushURL": pushURL, "api": map[string]string{"get": pushURL + "/{title}/{body}", "post": base + "/push"}, "documentation": "https://drel.app/self-hosted/", "source": "https://github.com/dyyz1993/WebBridgeKit"})
		return
	}
	markdown := "# Drel Push Discovery\n\nThis address sends notifications to one Drel installation. Treat it as a secret capability.\n\n## Quick start\n\n```sh\ncurl '" + pushURL + "/Build%20ready/Open%20Drel'\n```\n\n## References\n\n- Product: https://drel.app/\n- Self-hosting: https://drel.app/self-hosted/\n- Source: https://github.com/dyyz1993/WebBridgeKit\n"
	if markdownPath || format == "markdown" || format == "md" || !strings.Contains(r.Header.Get("accept"), "text/html") {
		w.Header().Set("content-type", "text/markdown; charset=utf-8")
		w.Header().Set("cache-control", "no-store")
		w.Header().Set("x-robots-tag", "noindex, nofollow")
		_, _ = w.Write([]byte(markdown))
		return
	}
	escapedURL := html.EscapeString(pushURL)
	page := `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>Drel Push Discovery</title><style>body{font:16px system-ui;background:#f5f7fb;color:#172033;margin:0}.wrap{max-width:760px;margin:auto;padding:48px 20px}.card{background:white;border-radius:24px;padding:28px;box-shadow:0 18px 60px #17203318}h1{margin-top:0}label{display:block;margin:16px 0 6px}input,textarea{box-sizing:border-box;width:100%;padding:13px;border:1px solid #ccd3df;border-radius:12px;font:inherit}button{margin-top:18px;border:0;border-radius:999px;padding:13px 20px;background:#5b5cf0;color:white;font-weight:700}.muted{color:#697386}code{overflow-wrap:anywhere}a{color:#4d50d8}</style></head><body><main class="wrap"><section class="card"><p class="muted">Drel developer endpoint</p><h1>Drel Push Discovery</h1><p>Send a notification to this Drel installation. Keep this address private; anyone holding it can send notifications.</p><p><code>` + escapedURL + `</code></p><form id="push"><label>Title</label><input id="title" value="Build ready"><label>Body</label><textarea id="body">Open Drel to inspect the result.</textarea><label>URL (optional)</label><input id="url" type="url" placeholder="https://example.com"><button>Send test notification</button></form><p id="result" class="muted"></p><hr><p><a href="https://drel.app/self-hosted/">Self-hosting guide</a> · <a href="https://github.com/dyyz1993/WebBridgeKit">Open source</a> · <a href="?format=markdown">Markdown</a></p></section></main><script>push.onsubmit=async(e)=>{e.preventDefault();const p='` + escapedURL + `/'+encodeURIComponent(title.value)+'/'+encodeURIComponent(body.value);const q=url.value?'?url='+encodeURIComponent(url.value):'';result.textContent='Sending…';try{const r=await fetch(p+q,{headers:{accept:'application/json'}});result.textContent=r.ok?'Sent successfully':('Failed: '+r.status)}catch{result.textContent='Network request failed'}}</script></body></html>`
	w.Header().Set("content-type", "text/html; charset=utf-8")
	w.Header().Set("cache-control", "no-store")
	w.Header().Set("x-robots-tag", "noindex, nofollow")
	_, _ = w.Write([]byte(page))
}

func (s *server) unregister(w http.ResponseWriter, r *http.Request) {
	var input struct {
		DeviceToken string `json:"deviceToken"`
		Key         string `json:"key"`
	}
	if decodeJSON(w, r, &input) != nil || input.DeviceToken == "" || input.Key == "" {
		writeError(w, 400, "deviceToken and key are required")
		return
	}
	removed, err := s.store.unregister(input.DeviceToken, input.Key)
	if err != nil {
		writeError(w, 500, "registration could not be removed")
		return
	}
	writeJSON(w, 200, map[string]any{"removed": removed})
}

func newMessageID() string {
	raw := make([]byte, 18)
	if _, err := rand.Read(raw); err != nil {
		return fmt.Sprintf("drel-%d", time.Now().UnixNano())
	}
	return base64.RawURLEncoding.EncodeToString(raw)
}

func validKey(value string) bool {
	raw, err := base64.RawURLEncoding.DecodeString(value)
	return err == nil && len(raw) == 32
}
func validEnvelope(value string) (envelope, bool) {
	raw, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return envelope{}, false
	}
	var e envelope
	if json.Unmarshal(raw, &e) != nil || e.Schema != envelopeSchema || e.MessageID == "" || !validKey(e.EphemeralPublicKey) || e.Ciphertext == "" {
		return envelope{}, false
	}
	now := time.Now().Unix()
	return e, e.CreatedAt <= now+60 && e.ExpiresAt > now && e.ExpiresAt <= e.CreatedAt+600
}
func decodeJSON(w http.ResponseWriter, r *http.Request, v any) error {
	r.Body = http.MaxBytesReader(w, r.Body, 64<<10)
	defer r.Body.Close()
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	return d.Decode(v)
}
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("content-type", "application/json")
	w.Header().Set("cache-control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
func clientIP(r *http.Request) string {
	if ip := net.ParseIP(strings.TrimSpace(r.Header.Get("CF-Connecting-IP"))); ip != nil {
		return ip.String()
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}
	return r.RemoteAddr
}
func loadConfig() config {
	return config{ListenAddr: env("DREL_LISTEN_ADDR", "127.0.0.1:8080"), PublicURL: strings.TrimRight(env("DREL_SELF_HOSTED_PUBLIC_BASE_URL", ""), "/"), Name: env("DREL_SELF_HOSTED_NAME", "Drel Self-hosted Push"), DataDir: env("DREL_DATA_DIR", "/var/lib/drel-selfhosted"), APNSKeyID: os.Getenv("APNS_KEY_ID"), APNSTeamID: os.Getenv("APNS_TEAM_ID"), APNSKey: os.Getenv("APNS_KEY_PATH"), APNSTopic: env("APNS_TOPIC", "com.webbridgekit.superapp"), APNSEnv: env("APNS_ENVIRONMENT", "production")}
}
func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
func main() {
	c := loadConfig()
	if c.PublicURL == "" || !strings.HasPrefix(c.PublicURL, "https://") {
		log.Fatal("DREL_SELF_HOSTED_PUBLIC_BASE_URL must be an HTTPS URL")
	}
	st, err := newStore(c.DataDir)
	if err != nil {
		log.Fatal(err)
	}
	a, err := newAPNS(c)
	if err != nil {
		log.Printf("APNs unavailable; pairings and pushes remain fail-closed: %v", err)
	}
	s := &server{c, st, a}
	log.Printf("Drel native relay listening on %s", c.ListenAddr)
	log.Fatal(http.ListenAndServe(c.ListenAddr, s.handler()))
}

func (s *server) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/ping", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("pong\n")) })
	mux.HandleFunc("/health", s.health)
	mux.HandleFunc("/.well-known/drel-push.json", s.descriptor)
	mux.HandleFunc("/self-hosted/pairings", method(http.MethodPost, s.createPairing))
	mux.HandleFunc("/self-hosted/register", method(http.MethodPost, s.register))
	mux.HandleFunc("/self-hosted/recipients/", method(http.MethodGet, s.recipient))
	mux.HandleFunc("/push", method(http.MethodPost, s.push))
	mux.HandleFunc("/unregister", method(http.MethodPost, s.unregister))
	mux.HandleFunc("/", method(http.MethodGet, s.barkPush))
	return securityHeaders(mux)
}
func method(expected string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != expected {
			w.Header().Set("allow", expected)
			writeError(w, 405, "method not allowed")
			return
		}
		next(w, r)
	}
}
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("x-content-type-options", "nosniff")
		w.Header().Set("referrer-policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}
