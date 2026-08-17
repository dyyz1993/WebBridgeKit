# WebBridgeKit Logo

WebBridgeKit now has a dedicated brand mark. The mark is a pair of open, rounded
nodes connected by a short central bridge:

- the left node represents the Web/PWA surface;
- the right node represents native capabilities;
- the center bridge represents the JavaScript-to-native Bridge;
- the open sides keep the symbol lightweight and legible at small sizes.

## Source assets

- `SuperApp/Resources/branding/webbridgekit-mark.svg` — transparent brand mark
- `SuperApp/Resources/branding/webbridgekit-app-icon.svg` — artwork for an iOS app icon
- `SuperApp/Sources/Assets.xcassets/AppIcon.appiconset` — exported iPhone/iPad app-icon sizes

`SuperApp/Resources/images/logo.svg` remains at its existing cache/test-fixture
path, but now renders the same bridge mark so static resource previews stay on
brand without changing their loading contract.

## Colors

- WebBridgeKit blue: `#4F6AF6`
- WebBridgeKit violet: `#8B5CF6`
- Ink: `#1A1D2E`

Use the blue-violet gradient for the primary mark. Use the white mark on the
gradient background for the app-icon artwork. Keep at least 16% clear space
around the mark and do not add a checkmark, globe, shield, or extra decoration.

## Exporting PNG artwork

The SVG sources are the canonical logo assets. To create a 1024px PNG preview
or an app-icon source image locally:

```bash
rsvg-convert -w 1024 -h 1024 \
  SuperApp/Resources/branding/webbridgekit-app-icon.svg \
  -o /tmp/webbridgekit-app-icon-1024.png
```
