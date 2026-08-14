# WebBridgeKit Release Checklist

## Next Phase Integration

- [x] Official, gateway and strong-offline commits share the recorded base and reproduce at the integration SHA.
- [x] Official home has no required gateway form and notification enablement remains explicit.
- [x] Gateway validation precedes activation; secret fields are rejected; cross-identity grants are cleared by model tests.
- [x] Strong-offline fixtures and installer tests cover digest validation and rollback.
- [x] Seven message types and approval consent contracts pass.
- [x] AppTemplate boundary gate passes independently.
- [x] SwiftLint, design lint and crash scan pass.
- [ ] Run `bash tools/verify-next-phase-acceptance.sh --full` before a release candidate archive.
- [ ] Complete paid-team physical APNs, background and lock-screen observations.

Simulator/open-source recommendation is GO-WITH-MANUAL-GATE. Do not label real APNs available until both unchecked items are complete.
