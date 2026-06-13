# Changelog

All notable changes to this project are documented here. The format follows
[Conventional Commits](https://www.conventionalcommits.org/) and
[Keep a Changelog](https://keepachangelog.com/); this project adheres to
[Semantic Versioning](https://semver.org/).

> **Unofficial package.** `react-native-buzzvil-ad` is community-maintained and
> is **not** affiliated with, endorsed by, or supported by Buzzvil.

## 0.2.0 (2026-06-13)

### Features

- **interstitial:** add Buzzvil BuzzBenefit v6 interstitial ads (full-screen
  `dialog` / `bottomSheet`) on Android & iOS — `loadInterstitial(unitId, type?)`
  (resolves on load, rejects on failure), `showInterstitial(unitId)`, and the
  `onInterstitialClosed` event via `addInterstitialClosedListener(unitId, cb)`.
  Built on the existing `Buzzvil` TurboModule using a New-Architecture typed
  `EventEmitter`; native instances are tracked per `unitId`. (#5)
- **example:** add interstitial smoke-test controls (type toggle, load/show,
  close-event log) to the example app. (#5)

### Bug Fixes

- **interstitial:** reject a new `loadInterstitial` while an instance for the
  same `unitId` is still loaded or showing, so the previous ad's close can no
  longer remove a newer instance (and, on iOS, can no longer deallocate a
  currently-visible ad). (#5)

### Build / Dependencies

- **deps:** resolve OSV-Scanner advisories (all dev-only, not shipped) — bump
  `joi` to 17.13.4 (#2), pin `esbuild` `^0.28.1` via `resolutions`, and document
  the `fast-xml-parser` suppression in `osv-scanner.toml`. (#4)

## 0.1.0 (2026-06-13)

Initial public release as the unofficial `react-native-buzzvil-ad` package
(renamed from the scoped `@dongminyu/react-native-buzzvil`).

### Features

- **session:** BuzzBenefit v6 session API via the `Buzzvil` TurboModule —
  `initialize`, `login`, `logout`, `isLoggedIn`, and `showBenefitHub` (the
  BenefitHub offerwall), with a primitives-only spec + sentinel contract.
- **native-ad:** `BuzzvilNativeAdView` Fabric component for in-feed native ads
  on Android & iOS — inventory-size layout variants (banner / card), self-sizing
  wrapper, and `onAdLoaded` / `onAdFailed` / `onAdClicked` / `onImpressed` /
  `onRewarded` events. iOS calls the Swift SDK directly from Objective-C++
  (no shim).
- **login:** dev-mode warnings for non-PII / malformed `userId` values (Buzzvil
  rejects emails and other identifiable ids).

### Documentation

- Add the SDK API-mapping spec, the ad-format expansion design, and project
  guidance (`CLAUDE.md`) covering the two native surfaces.
