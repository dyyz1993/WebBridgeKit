# Drel website

Static Cloudflare Pages site for `drel.app`. The public strong-offline fixture
is generated into a staging directory so its byte digests always match the
published resource and Web App manifests.

## Local preview

```bash
python3 -m http.server 8788 --directory docs/site
```

Open `http://127.0.0.1:8788`.

To preview the complete site including the generated offline test package:

```bash
bash tools/build-drel-offline-demo-site.sh
python3 -m http.server 8788 --directory build/drel-site-staging
```

## Cloudflare Pages

- Production branch: `main`
- Build command: leave empty
- Direct-upload output directory: `build/drel-site-staging`
- Custom domains: `drel.app`, then `www.drel.app`

Build, deploy and verify the public fixture with:

```bash
bash tools/build-drel-offline-demo-site.sh
npx wrangler pages deploy build/drel-site-staging --project-name=drel --branch=main
bash tools/verify-drel-offline-demo-public.sh
```

Build the companion offline-network demonstration (which keeps the base fixture
in the same Pages deployment) with:

```bash
bash tools/build-drel-offline-network-demo-site.sh
bash tools/verify-drel-offline-network-demo.sh
```

The generated `test/offline-network/gateway-manifest.json` is deliberately an
operator input: it must be signed by the gateway before `appId + route` push
opening is trusted by Drel.

Add each domain through **Workers & Pages → project → Custom domains**. Do not
create a manual Pages CNAME before associating the custom domain in Pages.

Before launch, configure Cloudflare Email Routing for `support@drel.app`,
`privacy@drel.app`, and `security@drel.app`, or replace those addresses with
verified inboxes.
