# Release Notes / Process

## Current release model

The repository is private.
Unsigned IPA-style artifacts are attached to GitHub Releases for testing/reference.

## Current release tag

- `v0.1.0`

## Local packaging command

```bash
APP="~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug-iphoneos/LANScope.app"
OUTDIR="build-artifacts"
STAGE="$OUTDIR/unsigned-ipa"
IPA="$OUTDIR/LANScope-unsigned.ipa"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
cd "$STAGE"
zip -qry "$IPA" Payload
```

## For future signed releases

Likely next step:
- Ad Hoc or TestFlight export
- proper signing identity
- provisioning profile
- device registration / distribution path

## CI note

The GitHub Actions workflow currently builds an unsigned artifact only.
It does not handle signing secrets or App Store Connect automation.
