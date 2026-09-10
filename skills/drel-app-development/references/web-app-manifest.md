# Web App Manifest and application identity

Use the standard Web App Manifest for presentation metadata. It keeps the page
compatible with browsers and other PWA hosts.

```html
<link rel="manifest" href="/manifest.webmanifest">
```

```json
{
  "id": "/",
  "name": "Example Console",
  "short_name": "Console",
  "start_url": "/app/",
  "scope": "/app/",
  "display": "standalone",
  "theme_color": "#5B5CF0",
  "background_color": "#F6F7FB",
  "icons": [{
    "src": "/assets/icon-512.png",
    "sizes": "512x512",
    "type": "image/png",
    "purpose": "any"
  }]
}
```

## Drel requirements

- The operator chooses a stable `appId` for the signed Drel parent manifest.
  A remote page cannot replace that identity by editing its Web Manifest.
- `start_url` and `scope` must stay inside the confirmed HTTPS origin. Remove
  credentials, one-time tokens and temporary parameters before publishing them.
- Drel validates the Web Manifest URL and SHA-256 against the signed parent
  manifest. Redirects, a changed digest, out-of-origin icons, or a start URL
  outside the scope are rejected.
- `icons` supply a Drel application-card icon only. They do not replace the
  iOS Drel app icon or the system-notification icon.
- `display` is a presentation preference, not permission to remove Drel's
  navigation or security controls.

Read the repository's `docs/api/drel-web-app-manifest-profile.md` if a change
needs the complete field-to-host mapping.
