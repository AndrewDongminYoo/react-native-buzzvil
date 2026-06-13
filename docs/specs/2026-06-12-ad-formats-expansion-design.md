# Buzzvil ad-format expansion — design

Status: **approved design / M1 spec**. Date: 2026-06-12.

Extends the package beyond the current session + BenefitHub surface (see [`buzzvil-sdk-api-mapping.md`](./buzzvil-sdk-api-mapping.md)) to the BuzzBenefit v6 ad formats: **Native, Interstitial, BuzzBanner, FlexAd, EntryPoint**.

Source docs:

- Android: <https://docs.buzzvil.com/docs/buzzbenefit-android/v6/introduction>
- iOS: <https://docs.buzzvil.com/docs/buzzbenefit-ios/v6/introduction>

## Goal

Let a React Native app integrate Buzzvil's various ad formats, not just the BenefitHub offerwall. The design covers the architecture for all five formats so the contract accommodates them; implementation is phased.

## Scope

**Already shipped (v1 — sets the embedded-view precedent):**

- **Native** (in-feed) — `BuzzvilNativeAdView` Fabric component (see `docs/plans/2026-06-12-buzzvil-native-ad-fabric-component.md`). M1's Fabric work mirrors this component.

**Milestone 1 (fully specified here):**

- **Interstitial** — establishes the imperative-with-events pattern.
- **BuzzBanner** — second per-format Fabric component, modelled on `BuzzvilNativeAdView`.

**Deferred — architecture TBD pending per-format doc verification:**

- **FlexAd** — the v6 intro does not specify whether it is a view or imperative. Do **not** assume Fabric until verified.
- **EntryPoint (팝)** — the Android intro describes an "imperative FAB navigation" widget; it may be imperative rather than an embedded view. Verify before classifying.

Each deferred format gets its own doc-verification → spec → implementation pass.

## Starting point (already implemented)

- The `create-react-native-library` **fabric-view** scaffold was generated and adapted into `BuzzvilNativeAdView`: `src/BuzzvilNativeAdViewNativeComponent.ts`, `src/BuzzvilNativeAdView.{tsx,native.tsx}`, `android/.../BuzzvilNativeAdView.kt` + `BuzzvilNativeAdViewManager.kt` (registered in `BuzzvilPackage.kt` via `createViewManagers`), `ios/BuzzvilNativeAdView.{h,mm}`.
- `package.json` → `codegenConfig.type` is `"all"` with `ios.components.BuzzvilNativeAdView`; Java compat at 17.

M1 **adds a new `BuzzBannerView` component alongside `BuzzvilNativeAdView`** (per Decision 4 — per-format components, not a generic view switched by a `format` prop).

## Architecture — two bridge categories

The RN New Architecture splits cleanly along the SDK's own shape:

| Category                      | Mechanism                                     | Formats                                                  |
| ----------------------------- | --------------------------------------------- | -------------------------------------------------------- |
| Imperative (methods + events) | existing `Buzzvil` **TurboModule** (extended) | Interstitial (later: EntryPoint imperative)              |
| Embedded view                 | **Fabric Native Component** (per format)      | Native (`BuzzvilNativeAdView`, shipped), BuzzBanner (M1) |

The view category was introduced by `BuzzvilNativeAdView`; each new per-format component repeats this shape:

- A codegen view spec in a `*NativeComponent.ts` file using `codegenNativeComponent('<NativeName>')`, name matching the native view manager (extends the codegen-naming discipline in `CLAUDE.md`).
- Android: a Fabric ViewManager (e.g. `BuzzBannerViewManager`), registered in `BuzzvilPackage.kt` via `createViewManagers`.
- iOS: an `RCTViewComponentView` subclass hosting the native ad view.
- `package.json` → `codegenConfig.type` stays `"all"` and each component gets its own entry under `ios.components`.

## Decisions (approved)

1. **Interstitial instance management.** The native side holds each `BuzzInterstitial` instance in a **map keyed by `unitId`**. `load(unitId, type)` creates/loads the instance; `show(unitId)` presents the stored instance. Chosen over returning an opaque handle to JS: simpler, and matches the common one-interstitial-per-placement usage.
2. **Module composition.** Imperative methods stay in the **single `Buzzvil` TurboModule** (session + interstitial). View formats are separate per-format Fabric components. Does not multiply native modules.
3. **Banner sizing (M1).** **Fixed sizes only** (`W320XH50`, `W320XH100`); JS sets explicit `width`/`height`. `DYNAMIC` is deferred — when added, the native side emits the resolved size in the `onLoaded` event and JS sizes the container (avoids C++ shadow-node measurement).
4. **Component naming.** Per-format Fabric components (`BuzzvilNativeAdView` shipped, **`BuzzBannerView`** added in M1) rather than one generic view switched by a `format` prop. Each component has its own native name + ViewManager + spec file + `codegenConfig.ios.components` key + index export, so each format's props/events stay isolated and typed; FlexAd (if Fabric) adds its own component.

## Public JS API (M1)

```tsx
// Interstitial — imperative
type InterstitialType = 'dialog' | 'bottomSheet';
loadInterstitial(unitId: string, type?: InterstitialType): Promise<void>; // resolves on onAdLoaded, rejects on onAdLoadFailed
showInterstitial(unitId: string): void;                                   // presents the loaded instance
addInterstitialClosedListener(unitId: string, cb: () => void): { remove(): void }; // onAdClosed / didDismiss

// BuzzBanner — Fabric component
type BannerSize = 'W320XH50' | 'W320XH100'; // DYNAMIC deferred
<BuzzBanner
  placementId="..."
  size="W320XH50"
  onLoaded={() => {}}
  onFailed={({ code, message }) => {}}
  onClicked={() => {}}
/>;
```

Web fallback (`*.tsx` / `BuzzBanner.web.tsx`): imperative methods reject/throw with the existing `react-native-buzzvil is not supported on web.` message; the banner renders nothing.

### TurboModule spec additions (`src/NativeBuzzvil.ts`)

Primitive-only, per the existing codegen constraint. Closed events use a codegen typed `EventEmitter`:

```ts
loadInterstitial(unitId: string, type: string): Promise<void>;
showInterstitial(unitId: string): void;
readonly onInterstitialClosed: EventEmitter<{ unitId: string }>;
```

`type` carries `'dialog'` | `'bottomSheet'` as a string (no codegen enums); the JS wrapper exposes the union.

### Fabric component spec (`src/BuzzBannerNativeComponent.ts`)

```ts
import { codegenNativeComponent, type ViewProps } from 'react-native';
import type { CodegenTypes } from 'react-native';

interface NativeProps extends ViewProps {
  placementId: string;
  size: string; // 'W320XH50' | 'W320XH100'
  onLoaded?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onFailed?: CodegenTypes.DirectEventHandler<
    Readonly<{ code: string; message: string }>
  >;
  onClicked?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>('BuzzBannerView');
```

(Matches the import + no-payload event-type convention already used by `src/BuzzvilNativeAdViewNativeComponent.ts`.)

## Event surface

Full lifecycle exposure means **only what each non-rewarded format actually emits** — no invented impression/reward events.

| Format       | JS surface                                                    | SDK callbacks (Android / iOS)                                                                                                                    |
| ------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Interstitial | `load` Promise resolve / reject, `onInterstitialClosed` event | `onAdLoaded` / `BuzzInterstitialDidLoadAd`; `onAdLoadFailed` / `DidFail(toLoadAd:withError:)`; `onAdClosed` / `BuzzInterstitialDidDismiss`       |
| BuzzBanner   | `onLoaded`, `onFailed`, `onClicked` props                     | `onLoaded` / `bannerView(_:didLoadApid:)`; `onFailed(AdError)` / `didFailApid:error:`; `onClicked` / `didClickApid:` (iOS also `didRemoveApid:`) |

Reward events live on the shipped `BuzzvilNativeAdView` (`onRewarded`) and the BenefitHub surface; Interstitial and BuzzBanner are non-rewarded formats.

## Native implementation notes

### Interstitial

- **Android** (`BuzzvilModule.kt`): `BuzzInterstitial.Builder(unitId).buildDialog()` or `.buildBottomSheet()`; `.load(BuzzInterstitialListener)`; `.show(context)`. Hold instances in a `Map<String, BuzzInterstitial>`. `onAdLoaded` → `promise.resolve`; `onAdLoadFailed(BuzzAdError?)` → `promise.reject`; `onAdClosed` → emit `onInterstitialClosed`. `show` must run on the UI thread with `currentActivity` (parity with BenefitHub).
- **iOS** (`Buzzvil.mm`): `BuzzInterstitial(unitId:type:)`, set `delegate`, `load()`, `present(on:)` from `RCTPresentedViewController()` on the main queue. `BuzzInterstitialDidLoadAd` → resolve; `DidFail` → reject; `DidDismiss` → emit event. Hold instances in an `NSMutableDictionary` keyed by `unitId`.

### BuzzBanner (view component)

- **Android** (`BuzzBannerViewManager`): host `com.buzzvil.buzzbanner.BuzzBannerView`. Apply `BuzzBannerConfig.Builder().bannerSize(...).placementId(...).build()` via `setBuzzBannerConfig`. Wire `BuzzBannerViewListener` → `onLoaded`/`onFailed`/`onClicked` events. **Lifecycle (silent-bug guard):** register a `LifecycleEventListener` on the `ReactApplicationContext` mapping `onHostResume`/`onHostPause` to the view's `onResume()`/`onPause()`; call `onDestroy()` and unregister the listener in `onDropViewInstance`. Without this the view never receives Activity lifecycle, leaking and counting impressions in the background.
- **iOS** (`RCTViewComponentView` subclass): host `BuzzBannerView`; configure via `BuzzBannerConfig.Builder(placementId:).setSize(...).build()` + `setConfig(rootViewController:config:)`. Call `requestAd()` on mount / `didMoveToWindow`, `removeAd()` on unmount. Map `BuzzBannerViewDelegate` (`didLoad`/`didFail`/`didClick`/`didRemove`) to events.

## File structure

```log
src/
  NativeBuzzvil.ts                        # TurboModule spec (session + interstitial + events)
  BuzzvilNativeAdViewNativeComponent.ts   # existing — Native ad Fabric spec
  BuzzBannerNativeComponent.ts            # NEW (M1) — BuzzBanner Fabric spec
  types.ts                                # shared friendly types
  layout.ts                               # existing — Native ad layout/size helpers
  index.tsx                               # public exports
  buzzvil.native.tsx / .tsx               # existing — session + BenefitHub
  BuzzvilNativeAdView.native.tsx / .tsx   # existing — Native ad JS wrapper
  interstitial.native.tsx / .tsx          # NEW (M1)
  BuzzBanner.tsx / BuzzBanner.web.tsx     # NEW (M1)
```

Existing `buzzvil.*` and `BuzzvilNativeAdView*` files stay as-is; broad renaming is out of scope.

## Verification

- **JS**: extend the existing sentinel-mapping test style — interstitial argument mapping (type default, unitId passthrough) and banner prop mapping.
- **Native compile**: Android via `./gradlew :dongminyu_react-native-buzzvil:compileDebugKotlin` (the command used to verify the current module against the resolved AAR); iOS via `bundle exec pod install` + build. The Android Buzzvil Maven repo and `buzzvil-bom` already resolve `buzzvil-sdk`; confirm `buzzbanner` / interstitial artifacts are pulled by the BOM (verify at first sync).
- **Device run**: requires real `placementId` / interstitial `unitId` values from the Buzzvil admin — needed before end-to-end verification.

## Open questions

1. **FlexAd / EntryPoint classification** — verify against their doc pages before adding to the contract (see Scope).
2. **`DYNAMIC` banner sizing** — deferred; resolved-size-in-`onLoaded` approach noted above.
3. **Buzzvil unit/placement IDs** — needed from the app owner for device testing.
