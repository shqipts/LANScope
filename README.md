# LANScope

LANScope is a native SwiftUI iOS network utility app focused on:

- Wi‑Fi / network info
- LAN device discovery
- Bonjour / mDNS discovery
- host details and open ports
- ping / DNS / WHOIS / port scan tools

## Current status

This project is an MVP with a public GitHub repository and release flow.
It currently supports:

- Info tab with Wi‑Fi, external IP, gateway, DNS, and limited cellular info
- LAN tab with one strong default scanner
- host source badges: `PORT`, `BONJOUR`, `BOTH`, `CACHED`
- repeated-scan merge and recent-host caching
- Tools tab with ping, DNS, WHOIS/RDAP, and configurable port scan
- first-launch onboarding for permissions

## Permissions used

The app needs:

- **Local Network** — for LAN scanning and Bonjour discovery
- **Location When In Use** — for SSID/BSSID access on iOS

The app does **not** need:

- Contacts
- Photos
- Microphone
- Camera
- Bluetooth

## Build notes

### Local Xcode build

Open:
- `LANScope.xcodeproj`

Target:
- iOS 26.0+

### Unsigned IPA artifact

Local artifact path:
- `build-artifacts/LANScope-unsigned.ipa`

GitHub Release:
- attached to the private repo release

## Project structure

- `LANScope/App/` — app entry and root navigation
- `LANScope/Models/` — app models
- `LANScope/Services/` — network, discovery, permissions, cache
- `LANScope/ViewModels/` — UI state
- `LANScope/Views/` — screens and reusable components

## Future improvements

- stronger vendor fingerprinting
- better router/device classification
- manual subnet/range scanning
- favorites/history UI
- signed ad hoc build/export flow
ow
