# Adnan iOS Wrapper V1 (WKWebView + Native STT + Web Bridge V1)

Minimal, production-grade iOS app shell that hosts the existing Render frontend in `WKWebView` and uses native iOS Speech framework STT to send transcripts to the web app via **Web Bridge V1**:

- `window.AdnanBridgeV1.nativeHello(...)`
- `window.AdnanBridgeV1.submitFinalTranscript(...)`
- optional `window.AdnanBridgeV1.updatePartialTranscript(...)`

This folder is intended to be a **separate iOS repo/app shell**. It is placed here only so it is visible in the current VS Code workspace.

## Build (macOS)

Prereqs:
- Xcode 15+
- XcodeGen: `brew install xcodegen`

Generate the Xcode project:

```bash
cd ios-wrapper-v1
xcodegen generate
open AdnanIOSWrapperV1.xcodeproj
```

Set the Render frontend URL:
- Edit `Config/AppConfig.swift` (`renderBaseURL`)

Run:
- Select an iPhone device/simulator
- Build & Run

## Smoke test (device)
1. App loads Render page.
2. Tap mic button (native). Grant permissions.
3. Speak; on final result the app calls `window.AdnanBridgeV1.submitFinalTranscript`.
4. Verify the web app auto-sends after grace delay.
5. Verify backend audio attempts autoplay; if blocked, wrapper emits telemetry over the native bridge.
