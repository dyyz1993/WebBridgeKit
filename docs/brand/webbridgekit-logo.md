# WebBridgeKit Logo

WebBridgeKit now has a dedicated full bridge logo. The mark is a pair of rounded
web/native surfaces connected by a substantial central bridge, retaining the
interface details from the approved visual direction:

- the left node represents the Web/PWA surface;
- the right node represents native capabilities;
- the center bridge represents the JavaScript-to-native Bridge;
- the white inner surfaces and small interface details reinforce the Web/PWA and
  native-app relationship;
- the white background is intentional for the primary approved logo artwork.

## Source assets

- `SuperApp/Resources/branding/webbridgekit-mark.svg` — primary white-background logo
- `SuperApp/Resources/branding/webbridgekit-app-icon.svg` — white-background iOS app-icon artwork
- `SuperApp/Sources/Assets.xcassets/AppIcon.appiconset` — exported iPhone/iPad app-icon sizes

`SuperApp/Resources/images/logo.svg` remains at its existing cache/test-fixture
path, but now renders the same bridge mark so static resource previews stay on
brand without changing their loading contract.

## Colors

- WebBridgeKit blue: `#4F6AF6`
- WebBridgeKit violet: `#8B5CF6`
- Ink: `#1A1D2E`

Use the blue-violet gradient for the primary mark and keep the white inner
surfaces/details intact. Keep at least 10% clear space around the mark and do
not add a checkmark, globe, shield, or extra decoration. Functional product
icons remain semantic Lucide icons; this logo is reserved for product identity.

## Exporting PNG artwork

The SVG sources are the canonical logo assets. To create a 1024px PNG preview
or an app-icon source image locally:

```bash
rsvg-convert -w 1024 -h 1024 \
  SuperApp/Resources/branding/webbridgekit-app-icon.svg \
  -o /tmp/webbridgekit-app-icon-1024.png
```
