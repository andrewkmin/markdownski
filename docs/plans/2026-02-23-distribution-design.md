# Distribution Design: GitHub Releases + DMG

**Date:** 2026-02-23
**Status:** Approved

## Context

markdownski is a local-only macOS utility (no network access, no external dependencies). The app is unsigned (no Apple Developer account). The repo is hosted at `github.com/andrewkmin/markdownski`.

Target audience: general Mac users who may not be developers.

## Goals

1. **Pre-built download** — a DMG disk image with drag-to-Applications for easy installation
2. **Build from source** — clear instructions for developers who prefer to compile themselves
3. **Security transparency** — `SECURITY.md` documenting the line-by-line audit (already written)

## Distribution: GitHub Releases + DMG

### Pre-built download

A `.dmg` disk image attached to each GitHub Release, containing:
- `markdownski.app` (universal binary: arm64 + x86_64)
- Symlink to `/Applications` for drag-and-drop install

The DMG is created using `hdiutil` (macOS built-in, no extra tooling).

### Build from source

Already works:
```bash
git clone https://github.com/andrewkmin/markdownski.git
cd markdownski
swift build && swift run
```

Or for a release `.app` bundle: `make build && open markdownski.app`

### CI automation

A GitHub Actions workflow (`.github/workflows/release.yml`) that:
1. Triggers on `v*` tag push
2. Runs on `macos-14` runner
3. Builds universal binary: `swift build -c release --arch arm64 --arch x86_64`
4. Assembles `.app` bundle (same as Makefile but for universal)
5. Creates DMG with `hdiutil`
6. Creates GitHub Release with DMG attached

### Versioning

- Git tags: `v1.0.0`, `v1.0.1`, etc.
- `Info.plist` `CFBundleVersion` and `CFBundleShortVersionString` should match the tag

### Makefile updates

Add a `dmg` target for local DMG creation:
```makefile
dmg: build
	hdiutil create -volname "markdownski" -srcfolder markdownski.app \
		-ov -format UDZO markdownski.dmg
```

Add a `universal` target for universal builds:
```makefile
universal:
	swift build -c release --arch arm64 --arch x86_64
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/apple/Products/Release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/apple/Products/Release/markdownski_markdownski.bundle \
		markdownski.app/Contents/Resources/
```

### README updates

- Add "Install" section at top with download link to latest GitHub Release
- Add Gatekeeper bypass instructions for unsigned app
- Link to `SECURITY.md`
- Keep existing "Build from source" section

### Gatekeeper handling

Since the app is unsigned:
1. README and SECURITY.md document the right-click > Open workaround
2. The security audit gives users confidence the app is safe
3. Building from source bypasses Gatekeeper entirely (since the binary is created locally)

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Distribution format | DMG | Standard Mac delivery format, familiar to general users |
| Architecture | Universal (arm64 + x86_64) | Broadest compatibility |
| CI | GitHub Actions | Free for public repos, native macOS runners available |
| DMG tooling | hdiutil (built-in) | No extra dependencies, works on CI runners |
| Code signing | None | No Apple Developer account; mitigated by security audit |
| Homebrew | Deferred | Can add later as an additional channel |

## Files to create/modify

- **Create:** `.github/workflows/release.yml`
- **Modify:** `Makefile` (add `universal` and `dmg` targets)
- **Modify:** `README.md` (add Install section, link to SECURITY.md)
