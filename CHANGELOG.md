# Changelog

All notable changes to this project are documented here. The format follows
[Conventional Commits](https://www.conventionalcommits.org/) and
[Keep a Changelog](https://keepachangelog.com/); this project adheres to
[Semantic Versioning](https://semver.org/).

> **Unofficial package.** `react-native-buzzvil-ad` is community-maintained and
> is **not** affiliated with, endorsed by, or supported by Buzzvil.

## 0.3.0 (2026-06-13)

### Features

- **banner:** add Buzzvil BuzzBenefit v6 **BuzzBanner** (embedded, non-rewarded)
  as the `BuzzBanner` Fabric component on Android & iOS — `placementId`, `size`
  (`W320XH50` / `W320XH100`), and `onLoaded` / `onFailed({ code, message })` /
  `onClicked` events. Android drives the SDK banner through the RN host lifecycle
  (`onResume` / `onPause` / `onDestroy`); iOS hosts the SDK banner via an isolated
  host view and configures it against the presented root view controller. (#7)
- **android:** `initialize(appId, appSecret)` now also initializes BuzzBanner on
  Android via `BuzzBanner().init(appId, appSecret, context)`. `appSecret` is
  optional (rep-provisioned, required only for BuzzBanner) and ignored on iOS. (#7)
- **example:** add a BuzzBanner smoke-test section (size toggle, event log). (#7)

### Bug Fixes

- **banner:** include the SDK error domain (iOS) and code in the `onFailed`
  `message`, so terse SDK descriptions (e.g. iOS `"exception"`) are
  self-describing in logs; the numeric `code` field is unchanged. (#7)
- **android:** defer the banner load to the view manager's
  `onAfterUpdateTransaction`, so a render that changes both `placementId` and
  `size` issues a single ad request with the final pair instead of an
  intermediate request for a stale (placementId, size) combination. (#7)
- **ios:** gate the banner load on window attachment and retry from
  `didMoveToWindow`, mirroring Android's lifecycle guard — requesting an ad
  before the view has a frame could fire impressions against a zero-size view. (#7)

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
