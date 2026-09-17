# Drel container-only launch context

The first Drel App Store release does not expose a native JavaScript bridge.
When a notification opens an HTTPS destination, Drel opens the specified route
directly and adds these URL query parameters:

| Parameter | Meaning |
| --- | --- |
| `drel_route` | The notification route supplied by the sender. |
| `drel_source` | `notification`, `direct`, or `restore`. |
| `drel_param_<name>` | One verified notification parameter; `<name>` is the original parameter key. |

For example, a notification with route `/tasks/42` and parameters
`{"status":"ready"}` opens a page with `drel_route=/tasks/42` and
`drel_param_status=ready`. Read these values with `URLSearchParams`; do not
expect `window.WebBridgeKit`, `window.BarkBridge`, or an injected launch event
in the Store build.

Remote web authors must treat every query value as untrusted display/input data.
V1 only permits HTTPS destinations; opening a page never approves an action or
grants native capability.
