const HOP_BY_HOP_REQUEST_HEADERS = [
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding"
];

import { ManagedPushRegistry, handleManagedPush } from "./managed-push.js";

export { ManagedPushRegistry };

function upstreamURL(requestURL, origin) {
  const inbound = new URL(requestURL);
  const upstream = new URL(origin);
  upstream.pathname = inbound.pathname;
  upstream.search = inbound.search;
  return upstream;
}

function forwardedHeaders(request, upstream, originalHost) {
  const headers = new Headers(request.headers);
  for (const name of HOP_BY_HOP_REQUEST_HEADERS) headers.delete(name);

  // fetch() derives Host from the upstream URL. Preserve the public host only
  // as forwarding metadata for logs and future origin-side validation.
  headers.delete("host");
  headers.set("x-forwarded-host", originalHost);
  headers.set("x-forwarded-proto", "https");
  headers.set("x-drel-api-proxy", "1");
  return headers;
}

function proxyError() {
  return Response.json(
    { code: 502, message: "Drel API is temporarily unavailable." },
    {
      status: 502,
      headers: {
        "cache-control": "no-store",
        "x-drel-api-proxy": "edge"
      }
    }
  );
}

export default {
  async fetch(request, env) {
    const managedResponse = await handleManagedPush(request, env);
    if (managedResponse) return managedResponse;

    const publicURL = new URL(request.url);
    let upstream;
    try {
      upstream = upstreamURL(request.url, env.UPSTREAM_ORIGIN);
    } catch {
      return proxyError();
    }

    try {
      const response = await fetch(upstream, {
        method: request.method,
        headers: forwardedHeaders(request, upstream, publicURL.host),
        body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
        redirect: "manual"
      });

      // A WebSocket upgrade carries a WebSocket handle on the response; return
      // it untouched so reconstructing Response does not drop that handle.
      if (request.headers.get("upgrade")?.toLowerCase() === "websocket") {
        return response;
      }

      // API responses must never be cached at the edge. The original streaming
      // body is retained, so SSE remains streaming through the proxy.
      const headers = new Headers(response.headers);
      headers.set("cache-control", "no-store");
      headers.set("x-drel-api-proxy", "edge");
      headers.set("x-content-type-options", "nosniff");
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers
      });
    } catch {
      return proxyError();
    }
  }
};
