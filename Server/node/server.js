const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const devices = new Map();
const commands = new Map();
const manifests = new Map();
const pushHistory = [];
const wsClients = new Set();
const sseClients = new Set();

const messagesDir = path.join(__dirname, 'messages');
const packagesDir = path.join(__dirname, 'packages');
if (!fs.existsSync(messagesDir)) fs.mkdirSync(messagesDir, { recursive: true });
if (!fs.existsSync(packagesDir)) fs.mkdirSync(packagesDir, { recursive: true });

const messageStore = {
  save(msg) {
    const filePath = path.join(messagesDir, `${msg.id}.json`);
    fs.writeFileSync(filePath, JSON.stringify(msg, null, 2));
  },
  get(id) {
    try { return JSON.parse(fs.readFileSync(path.join(messagesDir, `${id}.json`), 'utf8')); } catch { return null; }
  },
  list(limit = 50, offset = 0) {
    try {
      const files = fs.readdirSync(messagesDir).filter(f => f.endsWith('.json')).sort().reverse();
      const total = files.length;
      const page = files.slice(offset, offset + limit);
      const items = page.map(f => { try { return JSON.parse(fs.readFileSync(path.join(messagesDir, f), 'utf8')); } catch { return null; } }).filter(Boolean);
      return { items, total };
    } catch { return { items: [], total: 0 }; }
  },
  cleanup(maxAgeMs = 30 * 24 * 60 * 60 * 1000) {
    try {
      const cutoff = Date.now() - maxAgeMs;
      const files = fs.readdirSync(messagesDir).filter(f => f.endsWith('.json'));
      let deleted = 0;
      for (const f of files) {
        try {
          const msg = JSON.parse(fs.readFileSync(path.join(messagesDir, f), 'utf8'));
          if (msg.createDate && new Date(msg.createDate).getTime() < cutoff) {
            fs.unlinkSync(path.join(messagesDir, f));
            deleted++;
          }
        } catch {}
      }
      return deleted;
    } catch { return 0; }
  }
};

const hmacKey = process.env.HMAC_KEY || crypto.randomBytes(32).toString('hex');
const startTime = Date.now();

const adminHTML = fs.readFileSync(path.join(__dirname, 'admin.html'), 'utf8');
const adminPushHTML = fs.readFileSync(path.join(__dirname, 'admin-push.html'), 'utf8');

function json(res, data, status = 200) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data));
}

function html(res, content, status = 200) {
  res.writeHead(status, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(content);
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => data += chunk);
    req.on('end', () => {
      if (!data) return resolve({});
      try { resolve(JSON.parse(data)); }
      catch { resolve({}); }
    });
    req.on('error', reject);
  });
}

function routeMatch(pathname, pattern) {
  const pParts = pathname.split('/').filter(Boolean);
  const rParts = pattern.split('/').filter(Boolean);
  if (pParts.length !== rParts.length) return null;
  const params = {};
  for (let i = 0; i < rParts.length; i++) {
    if (rParts[i].startsWith(':')) {
      params[rParts[i].slice(1)] = decodeURIComponent(pParts[i]);
    } else if (rParts[i] !== pParts[i]) {
      return null;
    }
  }
  return params;
}

function generateId() {
  return crypto.randomUUID();
}

function getMimeType(filename) {
  const ext = path.extname(filename).toLowerCase();
  const mimeTypes = {
    '.html': 'text/html; charset=utf-8',
    '.htm': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
    '.eot': 'application/vnd.ms-fontobject',
    '.webp': 'image/webp',
    '.mp4': 'video/mp4',
    '.webm': 'video/webm',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg'
  };
  return mimeTypes[ext] || 'application/octet-stream';
}

function parseMultipartForm(body, boundary) {
  const parts = [];
  const boundaryBuffer = Buffer.from('--' + boundary);
  const endBoundary = Buffer.from('--' + boundary + '--');
  let pos = 0;
  while (pos < body.length) {
    if (body.slice(pos, pos + boundaryBuffer.length).equals(boundaryBuffer)) {
      pos += boundaryBuffer.length;
      while (pos < body.length && (body[pos] === 13 || body[pos] === 10)) pos++;
      const headerEnd = body.indexOf('\r\n\r\n', pos);
      if (headerEnd === -1) break;
      const headerSection = body.slice(pos, headerEnd).toString('utf-8');
      const dataStart = headerEnd + 4;
      const nextBoundary = body.indexOf('\r\n--' + boundary, dataStart);
      if (nextBoundary === -1) break;
      const data = body.slice(dataStart, nextBoundary);
      const headers = {};
      const headerLines = headerSection.split('\r\n');
      for (const line of headerLines) {
        const colonIdx = line.indexOf(':');
        if (colonIdx > 0) {
          const key = line.slice(0, colonIdx).trim().toLowerCase();
          const value = line.slice(colonIdx + 1).trim();
          headers[key] = value;
        }
      }
      if (headers['content-disposition']) {
        const disposition = headers['content-disposition'];
        const nameMatch = disposition.match(/name="([^"]+)"/);
        const filenameMatch = disposition.match(/filename="([^"]*)"/);
        if (nameMatch) {
          parts.push({
            name: nameMatch[1],
            filename: filenameMatch ? filenameMatch[1] : null,
            data: data,
            headers: headers
          });
        }
      }
      pos = nextBoundary + 2;
    } else if (body.slice(pos, pos + endBoundary.length).equals(endBoundary)) {
      break;
    } else {
      pos++;
    }
  }
  return parts;
}

function extractSimpleZip(zipBuffer, destDir) {
  const localFileHeaderSignature = Buffer.from([0x50, 0x4b, 0x03, 0x04]);
  const centralDirectorySignature = Buffer.from([0x50, 0x4b, 0x01, 0x02]);
  let pos = 0;
  const files = [];
  let totalSize = 0;
  while (pos < zipBuffer.length) {
    if (zipBuffer.slice(pos, pos + 4).equals(localFileHeaderSignature)) {
      const version = zipBuffer.readUInt16LE(pos + 4);
      const flags = zipBuffer.readUInt16LE(pos + 6);
      const compressionMethod = zipBuffer.readUInt16LE(pos + 8);
      const modTime = zipBuffer.readUInt16LE(pos + 10);
      const modDate = zipBuffer.readUInt16LE(pos + 12);
      const crc32 = zipBuffer.readUInt32LE(pos + 14);
      const compressedSize = zipBuffer.readUInt32LE(pos + 18);
      const uncompressedSize = zipBuffer.readUInt32LE(pos + 22);
      const nameLength = zipBuffer.readUInt16LE(pos + 26);
      const extraLength = zipBuffer.readUInt16LE(pos + 28);
      const fileName = zipBuffer.slice(pos + 30, pos + 30 + nameLength).toString('utf-8');
      const fileDataStart = pos + 30 + nameLength + extraLength;
      const fileDataEnd = fileDataStart + compressedSize;
      if (!fileName.endsWith('/')) {
        const filePath = path.join(destDir, fileName);
        const dirPath = path.dirname(filePath);
        if (!fs.existsSync(dirPath)) {
          fs.mkdirSync(dirPath, { recursive: true });
        }
        if (compressionMethod === 0) {
          fs.writeFileSync(filePath, zipBuffer.slice(fileDataStart, fileDataEnd));
        } else if (compressionMethod === 8) {
          const compressedData = zipBuffer.slice(fileDataStart, fileDataEnd);
          const decompressed = zlib.inflateRawSync(compressedData);
          fs.writeFileSync(filePath, decompressed);
        }
        files.push(fileName);
        totalSize += uncompressedSize;
      }
      pos = fileDataEnd;
    } else if (pos + 4 <= zipBuffer.length && zipBuffer.slice(pos, pos + 4).equals(centralDirectorySignature)) {
      break;
    } else {
      pos++;
    }
  }
  return { files, totalSize };
}

function buildWSFrame(payload) {
  const msg = Buffer.from(payload);
  let header;
  if (msg.length < 126) {
    header = Buffer.alloc(2);
    header[0] = 0x81;
    header[1] = msg.length;
  } else if (msg.length < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 126;
    header.writeUInt16BE(msg.length, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x81;
    header[1] = 127;
    header.writeUInt32BE(0, 2);
    header.writeUInt32BE(msg.length, 6);
  }
  return Buffer.concat([header, msg]);
}

function broadcastToClients(message) {
  const payload = typeof message === 'string' ? message : JSON.stringify(message);
  const frame = buildWSFrame(payload);
  let sent = 0;
  for (const client of wsClients) {
    try { client.write(frame); sent++; } catch {}
  }
  for (const client of sseClients) {
    if (client.alive) {
      try { client.res.write('data: ' + payload + '\n\n'); sent++; } catch { client.alive = false; sseClients.delete(client); }
    }
  }
  return sent;
}

function signPayload(payload) {
  const data = typeof payload === 'string' ? payload : JSON.stringify(payload);
  return crypto.createHmac('sha256', hmacKey).update(data).digest('hex');
}

function createCommand(type, data, format, ttlSeconds) {
  const id = generateId();
  const now = Date.now();
  const expiresAt = ttlSeconds ? now + ttlSeconds * 1000 : null;
  const payload = { type, data, format: format || type, createdAt: now, expiresAt };
  const payloadStr = JSON.stringify(payload);
  const tokenBase64 = Buffer.from(payloadStr).toString('base64url');
  const token = `${id}.${tokenBase64}`;
  const signature = signPayload(token);
  const url = `webbridgekit://command/${token}`;
  const cmd = { id, token, url, signature, payload, createdAt: now, expiresAt, shareCount: 0 };
  commands.set(id, cmd);
  return cmd;
}

function resolveCommand(token) {
  const dotIdx = token.indexOf('.');
  if (dotIdx === -1) return null;
  const id = token.slice(0, dotIdx);
  const base64Part = token.slice(dotIdx + 1);
  try {
    const payloadStr = Buffer.from(base64Part, 'base64url').toString('utf8');
    const payload = JSON.parse(payloadStr);
    if (payload.expiresAt && Date.now() > payload.expiresAt) return { expired: true, id };
    return { id, payload, format: payload.format, output: payload.data };
  } catch {
    const cmd = commands.get(id);
    if (!cmd) return null;
    if (cmd.expiresAt && Date.now() > cmd.expiresAt) return { expired: true, id };
    return { id, payload: cmd.payload, format: cmd.payload.format, output: cmd.payload.data };
  }
}

function buildBarkMessage(params) {
  const id = params.id || generateId();
  const hasMarkdown = !!(params.markdown && params.markdown.trim());
  return {
    id,
    title: params.title || '',
    subtitle: params.subtitle || '',
    body: params.body || '',
    bodyType: hasMarkdown ? 'markdown' : 'plainText',
    markdown: params.markdown || '',
    url: params.url || '',
    sound: params.sound || '',
    call: params.call || '',
    icon: params.icon || '',
    image: params.image || '',
    group: params.group || '',
    level: params.level || 'active',
    volume: params.volume || '',
    badge: params.badge || 0,
    action: params.action || '',
    copy: params.copy || '',
    autoCopy: params.autoCopy || '',
    isArchive: params.isArchive || '',
    ciphertext: params.ciphertext || '',
    iv: params.iv || '',
    mode: params.mode || 'normal',
    appid: params.appid || '',
    deviceKey: params.device_key || params.key || '',
    createDate: new Date().toISOString(),
    timestamp: Date.now()
  };
}

async function handleRequest(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;
  const method = req.method;

  if (method === 'GET' && (pathname === '/' || pathname === '/admin')) {
    return html(res, adminHTML);
  }

  if (method === 'GET' && pathname === '/admin-push') {
    return html(res, adminPushHTML);
  }

  if (method === 'GET' && pathname === '/health') {
    return json(res, { timestamp: new Date().toISOString(), status: 'ok', uptime: Math.floor((Date.now() - startTime) / 1000) });
  }

  if (method === 'GET' && pathname === '/admin/api/stats') {
    return json(res, {
      devices: devices.size,
      commands: commands.size,
      manifests: manifests.size,
      wsClients: wsClients.size,
      uptime: Math.floor((Date.now() - startTime) / 1000),
      startTime: new Date(startTime).toISOString()
    });
  }

  if (method === 'GET' && pathname === '/admin/api/devices') {
    return json(res, Array.from(devices.values()));
  }

  if (method === 'GET' && pathname === '/admin/api/commands') {
    return json(res, Array.from(commands.values()).map(c => ({
      id: c.id, token: c.token, url: c.url, signature: c.signature,
      type: c.payload.type, data: c.payload.data, createdAt: c.createdAt,
      expiresAt: c.expiresAt, shareCount: c.shareCount
    })));
  }

  if (method === 'GET' && pathname === '/admin/api/manifests') {
    return json(res, Array.from(manifests.values()));
  }

  if (method === 'GET' && pathname === '/admin/api/push-history') {
    return json(res, pushHistory.slice(-50).reverse());
  }

  if (method === 'POST' && pathname === '/register') {
    const body = await parseBody(req);
    if (!body.deviceToken || !body.key) return json(res, { error: 'deviceToken and key required' }, 400);
    const device = {
      deviceToken: body.deviceToken,
      key: body.key,
      platform: body.platform || 'unknown',
      appVersion: body.appVersion || 'unknown',
      registeredAt: Date.now()
    };
    devices.set(body.key, device);
    return json(res, { status: 'ok', key: body.key });
  }

  if (method === 'POST' && pathname === '/push') {
    const body = await parseBody(req);
    const deviceKeys = body.device_keys || body.deviceKey || (body.device_key ? [body.device_key] : (body.key ? [body.key] : []));
    if (!deviceKeys || deviceKeys.length === 0) return json(res, { error: 'device_key required' }, 400);
    const keys = Array.isArray(deviceKeys) ? deviceKeys : [deviceKeys];
    const results = [];
    for (const key of keys) {
      const device = devices.get(key);
      const msg = buildBarkMessage({ ...body, deviceKey: key });
      messageStore.save(msg);
      pushHistory.push({
        id: msg.id,
        deviceKey: key,
        title: msg.title,
        body: msg.body,
        url: msg.url,
        timestamp: msg.timestamp,
        deviceExists: !!device
      });
      results.push({ key, id: msg.id, success: true });
      broadcastToClients({ type: 'push', data: msg });
    }
    return json(res, { code: 200, message: 'success', results });
  }

  if (method === 'POST' && pathname === '/api/v1/commands') {
    const body = await parseBody(req);
    if (!body.type || !body.data) return json(res, { error: 'type and data required' }, 400);
    const validTypes = ['urlScheme', 'base64', 'plainText', 'json'];
    if (!validTypes.includes(body.type)) return json(res, { error: `type must be one of: ${validTypes.join(', ')}` }, 400);
    const cmd = createCommand(body.type, body.data, body.format, body.ttlSeconds);
    return json(res, { id: cmd.id, token: cmd.token, url: cmd.url, signature: cmd.signature });
  }

  {
    const m = routeMatch(pathname, '/api/v1/commands/:id/resolve');
    if (m && method === 'POST') {
      const body = await parseBody(req);
      const token = body.token;
      if (!token) return json(res, { error: 'token required' }, 400);
      const resolved = resolveCommand(token);
      if (!resolved) return json(res, { error: 'Invalid token' }, 400);
      if (resolved.expired) return json(res, { error: 'Command expired' }, 410);
      return json(res, resolved);
    }
  }

  {
    const m = routeMatch(pathname, '/api/v1/commands/:id/share');
    if (m && method === 'POST') {
      const cmd = commands.get(m.id);
      if (!cmd) return json(res, { error: 'Command not found' }, 404);
      cmd.shareCount++;
      const shareURL = cmd.url;
      const shareText = `[WebBridgeKit Command] ${cmd.payload.type}: ${cmd.payload.data}`;
      return json(res, { id: cmd.id, shareCount: cmd.shareCount, shareURL, shareText });
    }
  }

  {
    const m = routeMatch(pathname, '/api/v1/commands/:id');
    if (m && method === 'GET') {
      const cmd = commands.get(m.id);
      if (!cmd) return json(res, { error: 'Command not found' }, 404);
      if (cmd.expiresAt && Date.now() > cmd.expiresAt) return json(res, { error: 'Command expired' }, 410);
      return json(res, { id: cmd.id, payload: cmd.payload, format: cmd.payload.format, output: cmd.payload.data });
    }
  }

  if (method === 'GET' && pathname === '/api/v1/manifests') {
    return json(res, Array.from(manifests.values()));
  }

  if (method === 'POST' && pathname === '/api/v1/manifests') {
    const body = await parseBody(req);
    if (!body.appId) return json(res, { error: 'appId required' }, 400);
    const mf = {
      appId: body.appId,
      version: body.version || '1.0.0',
      buildNumber: body.buildNumber || 1,
      resources: body.resources || [],
      integrity: body.integrity || {},
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    if (manifests.has(body.appId)) {
      mf.createdAt = manifests.get(body.appId).createdAt;
    }
    manifests.set(body.appId, mf);
    return json(res, { status: 'ok', appId: mf.appId, version: mf.version });
  }

  {
    const m = routeMatch(pathname, '/api/v1/manifests/:appId/version');
    if (m && method === 'GET') {
      const mf = manifests.get(m.appId);
      if (!mf) return json(res, { error: 'Manifest not found' }, 404);
      return json(res, { appId: mf.appId, version: mf.version, buildNumber: mf.buildNumber });
    }
  }

  {
    const m = routeMatch(pathname, '/api/v1/manifests/:appId');
    if (m) {
      if (method === 'GET') {
        const mf = manifests.get(m.appId);
        if (!mf) return json(res, { error: 'Manifest not found' }, 404);
        return json(res, mf);
      }
      if (method === 'DELETE') {
        if (!manifests.delete(m.appId)) return json(res, { error: 'Manifest not found' }, 404);
        return json(res, { status: 'ok' });
      }
    }
  }

  if (method === 'GET' && pathname === '/ws/status') {
    return json(res, { connectedClients: wsClients.size + sseClients.size });
  }

  if (method === 'GET' && pathname === '/ws/stream') {
    const clientId = Date.now().toString(36);
    const ua = req.headers['user-agent'] || 'unknown';
    console.log(`[SSE] ${clientId} New connection from UA: ${ua}`);
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no'
    });
    const now = Date.now();
    res.write('data: {"type":"connected","timestamp":' + now + '}\n\n');
    const heartbeat = setInterval(() => {
      if (client.alive) {
        client.res.write(': heartbeat\n\n');
      }
    }, 15000);
    const client = { res, alive: true, id: clientId };
    sseClients.add(client);
    req.on('close', () => {
      const elapsed = Date.now() - now;
      client.alive = false;
      clearInterval(heartbeat);
      sseClients.delete(client);
      console.log(`[SSE] ${clientId} disconnected after ${elapsed}ms. Total: ${sseClients.size}`);
    });
    console.log(`[SSE] ${clientId} Client connected. Total: ${sseClients.size}`);
    return;
  }

  if (method === 'POST' && pathname === '/ws/push') {
    const body = await parseBody(req);
    const wsMessage = {
      type: 'push',
      id: generateId(),
      timestamp: Date.now(),
      data: {
        title: body.title || '通知',
        body: body.body || '',
        subtitle: body.subtitle || '',
        bodyType: body.bodyType || 'plainText',
        markdown: body.markdown || '',
        sound: body.sound || 'default',
        call: body.call || '',
        icon: body.icon || '',
        image: body.image || '',
        url: body.url || '',
        badge: body.badge || 0,
        group: body.group || 'default',
        level: body.level || 'active',
        volume: body.volume || '',
        action: body.action || '',
        copy: body.copy || '',
        autoCopy: body.autoCopy || '',
        isArchive: body.isArchive || '',
        ciphertext: body.ciphertext || '',
        iv: body.iv || '',
        mode: body.mode || 'normal',
        appid: body.appid || '',
        params: body.params || {}
      }
    };
    const sent = broadcastToClients(wsMessage);
    pushHistory.push({
      id: wsMessage.id,
      deviceKey: 'ws-broadcast',
      title: wsMessage.data.title,
      body: wsMessage.data.body,
      url: wsMessage.data.url,
      timestamp: wsMessage.timestamp,
      wsClients: sent,
      deviceExists: sent > 0
    });
    return json(res, {
      status: 'ok',
      id: wsMessage.id,
      wsClients: sent,
      message: sent > 0 ? `Pushed to ${sent} connected client(s)` : 'No connected clients'
    });
  }

  if (method === 'GET') {
    const m = routeMatch(pathname, '/message/:id');
    if (m) {
      const msg = messageStore.get(m.id);
      if (!msg) return json(res, { error: 'Message not found' }, 404);
      return json(res, msg);
    }
  }

  if (method === 'GET' && pathname === '/messages') {
    const limit = parseInt(url.searchParams.get('limit') || '50');
    const offset = parseInt(url.searchParams.get('offset') || '0');
    return json(res, messageStore.list(limit, offset));
  }

  if (method === 'GET' && pathname === '/ping') {
    return json(res, { code: 200, message: 'pong', timestamp: Date.now() });
  }

  if (method === 'POST' && pathname === '/admin/upload-package') {
    const contentType = req.headers['content-type'] || '';
    if (!contentType.startsWith('multipart/form-data')) return json(res, { error: 'Content-Type must be multipart/form-data' }, 400);
    const boundaryMatch = contentType.match(/boundary=([^\s]+)/);
    if (!boundaryMatch) return json(res, { error: 'Missing boundary in Content-Type' }, 400);
    const boundary = boundaryMatch[1];
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    await new Promise(resolve => req.on('end', resolve));
    const body = Buffer.concat(chunks);
    const parts = parseMultipartForm(body, boundary);
    let filePart = null;
    let appid = '';
    let version = '1.0.0';
    for (const part of parts) {
      if (part.name === 'file' && part.data) {
        filePart = part;
      } else if (part.name === 'appid') {
        appid = part.data.toString('utf-8').trim();
      } else if (part.name === 'version') {
        version = part.data.toString('utf-8').trim();
      }
    }
    if (!filePart || !appid) return json(res, { error: 'file and appid required' }, 400);
    const appDir = path.join(packagesDir, appid);
    const filesDir = path.join(appDir, 'files');
    const versionPath = path.join(appDir, `${version}.zip`);
    if (!fs.existsSync(appDir)) fs.mkdirSync(appDir, { recursive: true });
    if (!fs.existsSync(filesDir)) fs.mkdirSync(filesDir, { recursive: true });
    fs.writeFileSync(versionPath, filePart.data);
    const { files: extractedFiles, totalSize } = extractSimpleZip(filePart.data, filesDir);
    const manifest = {
      appid: appid,
      version: version,
      files: extractedFiles,
      totalSize: totalSize,
      createdAt: new Date().toISOString(),
      entry: extractedFiles.find(f => f === 'index.html' || f.endsWith('.html')) || extractedFiles[0] || ''
    };
    const manifestPath = path.join(appDir, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    return json(res, manifest);
  }

  if (method === 'GET' && pathname === '/packages') {
    const packages = [];
    try {
      const appDirs = fs.readdirSync(packagesDir).filter(f => {
        const appDir = path.join(packagesDir, f);
        return fs.statSync(appDir).isDirectory();
      });
      for (const appid of appDirs) {
        const manifestPath = path.join(packagesDir, appid, 'manifest.json');
        if (fs.existsSync(manifestPath)) {
          try {
            const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
            packages.push(manifest);
          } catch {}
        }
      }
    } catch {}
    return json(res, packages);
  }

  {
    const m = routeMatch(pathname, '/package/:appid/manifest');
    if (m && method === 'GET') {
      const manifestPath = path.join(packagesDir, m.appid, 'manifest.json');
      if (!fs.existsSync(manifestPath)) return json(res, { error: 'Package not found' }, 404);
      try {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
        return json(res, manifest);
      } catch {
        return json(res, { error: 'Failed to read manifest' }, 500);
      }
    }
  }

  {
    const m = routeMatch(pathname, '/package/:appid');
    if (m && method === 'DELETE') {
      const appDir = path.join(packagesDir, m.appid);
      if (!fs.existsSync(appDir)) return json(res, { error: 'Package not found' }, 404);
      try {
        const rmRecursive = (dir) => {
          const entries = fs.readdirSync(dir);
          for (const entry of entries) {
            const fullPath = path.join(dir, entry);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory()) {
              rmRecursive(fullPath);
            } else {
              fs.unlinkSync(fullPath);
            }
          }
          fs.rmdirSync(dir);
        };
        rmRecursive(appDir);
        return json(res, { status: 'ok' });
      } catch {
        return json(res, { error: 'Failed to delete package' }, 500);
      }
    }
  }

  {
    const m = routeMatch(pathname, '/package/:appid/*');
    if (m && method === 'GET') {
      const wildcardMatch = pathname.match(/^\/package\/[^/]+\/(.+)$/);
      if (!wildcardMatch) return json(res, { error: 'Invalid path' }, 400);
      const filePath = path.join(packagesDir, m.appid, 'files', wildcardMatch[1]);
      if (!fs.existsSync(filePath)) return json(res, { error: 'File not found' }, 404);
      const stat = fs.statSync(filePath);
      if (stat.isDirectory()) {
        const indexPath = path.join(filePath, 'index.html');
        if (fs.existsSync(indexPath)) {
          const indexData = fs.readFileSync(indexPath);
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=31536000' });
          res.end(indexData);
          return;
        }
        return json(res, { error: 'Directory index not supported' }, 403);
      }
      const data = fs.readFileSync(filePath);
      res.writeHead(200, { 'Content-Type': getMimeType(wildcardMatch[1]), 'Cache-Control': 'public, max-age=31536000' });
      res.end(data);
      return;
    }
  }

  if (method === 'POST' && pathname === '/admin/upload-package') {
    const contentType = req.headers['content-type'] || '';
    if (!contentType.startsWith('multipart/form-data')) return json(res, { error: 'Content-Type must be multipart/form-data' }, 400);
    const boundaryMatch = contentType.match(/boundary=([^\s]+)/);
    if (!boundaryMatch) return json(res, { error: 'Missing boundary in Content-Type' }, 400);
    const boundary = boundaryMatch[1];
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    await new Promise(resolve => req.on('end', resolve));
    const body = Buffer.concat(chunks);
    const parts = parseMultipartForm(body, boundary);
    let filePart = null;
    let appid = '';
    let version = '1.0.0';
    for (const part of parts) {
      if (part.name === 'file' && part.data) {
        filePart = part;
      } else if (part.name === 'appid') {
        appid = part.data.toString('utf-8').trim();
      } else if (part.name === 'version') {
        version = part.data.toString('utf-8').trim();
      }
    }
    if (!filePart || !appid) return json(res, { error: 'file and appid required' }, 400);
    const appDir = path.join(packagesDir, appid);
    const filesDir = path.join(appDir, 'files');
    const versionPath = path.join(appDir, `${version}.zip`);
    if (!fs.existsSync(appDir)) fs.mkdirSync(appDir, { recursive: true });
    if (!fs.existsSync(filesDir)) fs.mkdirSync(filesDir, { recursive: true });
    fs.writeFileSync(versionPath, filePart.data);
    const { files: extractedFiles, totalSize } = extractSimpleZip(filePart.data, filesDir);
    const manifest = {
      appid: appid,
      version: version,
      files: extractedFiles,
      totalSize: totalSize,
      createdAt: new Date().toISOString(),
      entry: extractedFiles.find(f => f === 'index.html' || f.endsWith('.html')) || extractedFiles[0] || ''
    };
    const manifestPath = path.join(appDir, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    return json(res, manifest);
  }

  if (method === 'GET' && pathname === '/packages') {
    const packages = [];
    try {
      const appDirs = fs.readdirSync(packagesDir).filter(f => {
        const appDir = path.join(packagesDir, f);
        return fs.statSync(appDir).isDirectory();
      });
      for (const appid of appDirs) {
        const manifestPath = path.join(packagesDir, appid, 'manifest.json');
        if (fs.existsSync(manifestPath)) {
          try {
            const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
            packages.push(manifest);
          } catch {}
        }
      }
    } catch {}
    return json(res, packages);
  }

  {
    const m = routeMatch(pathname, '/package/:appid/manifest');
    if (m && method === 'GET') {
      const manifestPath = path.join(packagesDir, m.appid, 'manifest.json');
      if (!fs.existsSync(manifestPath)) return json(res, { error: 'Package not found' }, 404);
      try {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
        return json(res, manifest);
      } catch {
        return json(res, { error: 'Failed to read manifest' }, 500);
      }
    }
  }

  {
    const m = routeMatch(pathname, '/package/:appid');
    if (m && method === 'DELETE') {
      const appDir = path.join(packagesDir, m.appid);
      if (!fs.existsSync(appDir)) return json(res, { error: 'Package not found' }, 404);
      try {
        const rmRecursive = (dir) => {
          const entries = fs.readdirSync(dir);
          for (const entry of entries) {
            const fullPath = path.join(dir, entry);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory()) {
              rmRecursive(fullPath);
            } else {
              fs.unlinkSync(fullPath);
            }
          }
          fs.rmdirSync(dir);
        };
        rmRecursive(appDir);
        return json(res, { status: 'ok' });
      } catch {
        return json(res, { error: 'Failed to delete package' }, 500);
      }
    }
  }

  {
    const m = routeMatch(pathname, '/package/:appid/*');
    if (m && method === 'GET') {
      const wildcardMatch = pathname.match(/^\/package\/[^/]+\/(.+)$/);
      if (!wildcardMatch) return json(res, { error: 'Invalid path' }, 400);
      const filePath = path.join(packagesDir, m.appid, 'files', wildcardMatch[1]);
      if (!fs.existsSync(filePath)) return json(res, { error: 'File not found' }, 404);
      const stat = fs.statSync(filePath);
      if (stat.isDirectory()) {
        const indexPath = path.join(filePath, 'index.html');
        if (fs.existsSync(indexPath)) {
          const indexData = fs.readFileSync(indexPath);
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=31536000' });
          res.end(indexData);
          return;
        }
        return json(res, { error: 'Directory index not supported' }, 403);
      }
      const data = fs.readFileSync(filePath);
      res.writeHead(200, { 'Content-Type': getMimeType(wildcardMatch[1]), 'Cache-Control': 'public, max-age=31536000' });
      res.end(data);
      return;
    }
  }

  if (method === 'GET' && pathname.startsWith('/push/')) {
    return handleBarkPush(req, res, pathname, url);
  }
  if ((method === 'GET' || method === 'POST') && !pathname.startsWith('/api/') && !pathname.startsWith('/admin') && !pathname.startsWith('/package') && !pathname.startsWith('/messages') && !pathname.startsWith('/message/') && pathname.split('/').filter(Boolean).length >= 1 && pathname !== '/') {
    return handleBarkPush(req, res, pathname, url);
  }

  json(res, { error: 'Not Found', path: pathname }, 404);
}

async function handleBarkPush(req, res, pathname, urlObj) {
  let key, title, body, params;
  if (req.method === 'POST') {
    const bodyData = await parseBody(req);
    const pathParts = pathname.split('/').filter(Boolean);
    const urlKey = pathParts.length > 0 ? pathParts[0] : '';
    key = urlKey || bodyData.key || bodyData.device_key || '';
    title = bodyData.title || '';
    body = bodyData.body || '';
    params = { ...bodyData, device_key: key, key: key };
  } else {
    const parts = pathname.startsWith('/push/') ? pathname.replace('/push/', '').split('/') : pathname.split('/').filter(Boolean);
    key = parts[0];
    title = parts[1] || '';
    body = parts.slice(2).join('/') || '';
    params = {
      key,
      title: decodeURIComponent(title),
      body: decodeURIComponent(body)
    };
    const queryParams = urlObj.searchParams;
    const barkParams = ['sound', 'url', 'icon', 'image', 'group', 'level', 'badge', 'mode', 'appid', 'markdown', 'copy', 'autoCopy', 'isArchive', 'action', 'call', 'ciphertext', 'iv', 'volume', 'subtitle'];
    for (const p of barkParams) {
      params[p] = queryParams.get(p) || '';
    }
  }
  if (!key) return json(res, { error: 'device key required' }, 400);
  const msg = buildBarkMessage(params);
  messageStore.save(msg);
  pushHistory.push({
    id: msg.id,
    deviceKey: key,
    title: msg.title,
    body: msg.body,
    url: msg.url,
    timestamp: msg.timestamp,
    deviceExists: devices.has(key)
  });
  broadcastToClients({ type: 'push', data: msg });
  return json(res, { code: 200, message: 'success', id: msg.id });
}

const PORT = process.env.PORT || 8765;
const server = http.createServer(handleRequest);
server.listen(PORT, '0.0.0.0', () => {
  console.log(`WebBridgeKit API Server running on http://0.0.0.0:${PORT}`);
  console.log(`Admin dashboard: http://localhost:${PORT}/admin`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`WebSocket endpoint: ws://localhost:${PORT}/ws`);
  console.log(`HMAC Key: ${hmacKey.slice(0, 8)}...`);
});

server.on('upgrade', (req, socket, head) => {
  if (req.url === '/ws') {
    const acceptKey = req.headers['sec-websocket-key'];
    if (!acceptKey) { socket.destroy(); return; }
    const hash = crypto.createHash('sha1')
      .update(acceptKey + '258EAFA5-E914-47DA-95CA-C5AB5DC11B5A6')
      .digest('base64');
    socket.write(
      'HTTP/1.1 101 Switching Protocols\r\n' +
      'Upgrade: websocket\r\n' +
      'Connection: Upgrade\r\n' +
      `Sec-WebSocket-Accept: ${hash}\r\n\r\n`
    );
    wsClients.add(socket);
    console.log(`[WS] Client connected. Total: ${wsClients.size}`);

    socket.on('data', (buffer) => {
      const opcode = buffer[0] & 0x0f;
      if (opcode === 0x8) {
        wsClients.delete(socket);
        socket.end();
      } else if (opcode === 0x9) {
        const pong = Buffer.alloc(2);
        pong[0] = 0x8A;
        pong[1] = 0x00;
        socket.write(pong);
      }
    });

    socket.on('close', () => {
      wsClients.delete(socket);
      console.log(`[WS] Client disconnected. Total: ${wsClients.size}`);
    });

    socket.on('error', () => {
      wsClients.delete(socket);
    });
  } else {
    socket.destroy();
  }
});