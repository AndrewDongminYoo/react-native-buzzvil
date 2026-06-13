# Buzzvil BuzzBanner Ad — Implementation Plan

> **Execution:** subagent-driven (implementer per task + spec/quality review), same as the Native ad + Interstitial work.
> **Spec source:** `docs/specs/2026-06-12-ad-formats-expansion-design.md` (M1 → BuzzBanner). This is the executable task breakdown.
> **Reference impl:** `BuzzvilNativeAdView` (shipped on `main`) — BuzzBanner is a second per-format **Fabric Native Component** and mirrors its structure exactly.

**Goal:** Add Buzzvil BuzzBenefit v6 **BuzzBanner** (non-rewarded embedded banner) as a Fabric Native Component `BuzzBannerView`, exported to JS as `BuzzBanner`, on Android & iOS.

**Architecture:** Embedded-view Fabric component (like `BuzzvilNativeAdView`) — RN renders `<BuzzBanner placementId size onLoaded onFailed onClicked />`, the native side hosts Buzzvil's own `BuzzBannerView` and drives its config/lifecycle. Per-format component (Decision 4): its own native name, ViewManager, spec file, `codegenConfig.ios.components` entry, and index export. `codegenConfig` stays `type: "all"`.

**Tech stack:** unchanged — RN 0.85 New-Arch codegen, Kotlin/AGP (Android), Obj-C++ + direct Swift-SDK calls (iOS, no shim — BuzzAdBenefitSDK classes are `@objc`), `BuzzvilSDK`/`BuzzAdBenefitSDK ~> 6.7.5`.

---

## Public API (M1)

```tsx
type BannerSize = 'W320XH50' | 'W320XH100'; // DYNAMIC deferred (resolved-size-in-onLoaded later)

<BuzzBanner
  placementId="..."
  size="W320XH50"
  onLoaded={() => {}}
  onFailed={({ code, message }) => {}}
  onClicked={() => {}}
/>;
```

### Fabric component spec (`src/BuzzBannerViewNativeComponent.ts`)

```ts
import { codegenNativeComponent, type ViewProps } from 'react-native';
import type { CodegenTypes } from 'react-native';

type FailedEvent = Readonly<{ code: string; message: string }>;

export interface NativeProps extends ViewProps {
  placementId: string;
  size: string; // 'W320XH50' | 'W320XH100' — friendly union lives in the wrapper
  onLoaded?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onFailed?: CodegenTypes.DirectEventHandler<FailedEvent>;
  onClicked?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>('BuzzBannerView');
```

(Mirror `BuzzvilNativeAdViewNativeComponent.ts`. Flat primitive event payloads; `size` a plain string in the spec.)

---

## Verification reality

Real TDD on the **JS wrapper** (jest, mocked codegen component / pure mapping fn — mirror `BuzzvilNativeAdView`'s `sizeForLayout`/wrapper tests). Native Kotlin/Obj-C++ verified by codegen + compile + on-device smoke. Gates per task: `yarn typecheck`/`lint`/`test` → `pod install`/Gradle codegen → `build:android`/`build:ios` → manual on-device smoke (Task 5).

---

## Task 1 — Spec + JS wrapper (TDD) + native STUBS (green-to-green)

**Files:** create `src/BuzzBannerViewNativeComponent.ts`, `src/BuzzBanner.native.tsx`, `src/BuzzBanner.tsx` (web), tests in `src/__tests__/`; modify `src/types.ts` (+`BannerSize`, `BuzzBannerProps`), `src/index.tsx` (+`BuzzBanner` + types), `package.json` (`codegenConfig.ios.components` += `BuzzBannerView`); **stub** `android/.../BuzzBannerView.kt` + `BuzzBannerViewManager.kt` (+register in `BuzzvilPackage.kt` `createViewManagers`) and `ios/BuzzBannerView.{h,mm}` so codegen + both builds stay green.

- **Spec** as above. Add the `BuzzBannerView` entry to `codegenConfig.ios.components` (alongside `BuzzvilNativeAdView`).
- **types.ts:** `export type BannerSize = 'W320XH50' | 'W320XH100';` + a friendly `BuzzBannerProps` (placementId, size, onLoaded/onFailed/onClicked callbacks).
- **Wrapper** (`BuzzBanner.native.tsx`): maps friendly props → native, unwraps `e.nativeEvent` for `onFailed`; default `size` if desired. Web (`BuzzBanner.tsx`): inert `<View>` (no native import — keep web bundle clean, mirror `BuzzvilNativeAdView.tsx`).
- **Android stubs:** `BuzzBannerView` (a `FrameLayout` storing props), `BuzzBannerViewManager` (`SimpleViewManager`, `@ReactProp` placementId/size store-only, `getExportedCustomDirectEventTypeConstants` for `topLoaded`/`topFailed`/`topClicked`), registered in `BuzzvilPackage.createViewManagers` next to `BuzzvilNativeAdViewManager`.
- **iOS stub:** `BuzzBannerView : RCTViewComponentView` reading `placementId`/`size` in `updateProps` (no SDK yet); generated headers under `<react/renderer/components/BuzzvilSpec/...>`.
- **TDD:** failing jest first (wrapper prop mapping + event unwrap), then implement. Green-to-green gate: typecheck/lint/test + `pod install` + `build:android` + `build:ios`.

---

## Task 2 — Android BuzzBanner implementation

Fill the stubs (verify exact API against the resolved AAR via `javap`; confirm the pod/package, likely `com.buzzvil.buzzbanner`):

- Host `com.buzzvil.buzzbanner.BuzzBannerView` inside the RN view.
- Configure: `BuzzBannerConfig.Builder().bannerSize(<W320XH50|W320XH100>).placementId(placementId).build()` then apply via the view's config setter (verify name, e.g. `setBuzzBannerConfig`).
- Wire `BuzzBannerViewListener` → emit `onLoaded`/`onFailed({code,message})`/`onClicked` (Fabric direct events via `UIManagerHelper` + named `Event` subclass, exactly like `BuzzvilNativeAdView`).
- **Lifecycle (silent-bug guard — REQUIRED):** register a `LifecycleEventListener` on the `ReactApplicationContext` mapping `onHostResume`/`onHostPause` to the banner's `onResume()`/`onPause()`; call `onDestroy()` and **unregister** the listener in `onDropViewInstance`. Without this the banner never receives Activity lifecycle → leaks + counts impressions in the background.
- Gate: `build:android` compiles.

---

## Task 3 — iOS BuzzBanner implementation (`RCTViewComponentView`, DIRECT)

Fill the stub, calling the Swift SDK directly via `<BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>` (verify exact selectors in the generated `-Swift.h` first):

- Host `BuzzBannerView`; configure via `BuzzBannerConfig.Builder(placementId:).setSize(...).build()` + `setConfig(rootViewController:config:)` (use `RCTPresentedViewController()` / the window's root for the rootViewController — verify the exact selector).
- `requestAd()` on mount / `didMoveToWindow`; `removeAd()` on unmount / `prepareForRecycle`.
- Map `BuzzBannerViewDelegate` (`didLoadApid:` / `didFailApid:error:` / `didClickApid:` / `didRemoveApid:`) → emit via the generated component `EventEmitter` (`onLoaded`/`onFailed`/`onClicked`), like `BuzzvilNativeAdView`.
- Note the `BuzzvilSDK-WithoutThirdParty` caveat from the design doc — confirm the full `BuzzvilSDK`/`BuzzAdBenefitSDK` (already a dep) vends `BuzzBannerView`.
- Gate: `pod install` + `build:ios` compiles.

---

## Task 4 — Example + docs

- `example/src/App.tsx`: add a BuzzBanner section — a `size` toggle + a `<BuzzBanner placementId={...} size={...} onLoaded/onFailed/onClicked → log />`. Placeholder `BUZZVIL_BANNER_PLACEMENT_ID` (banners use a placement id; do not commit real keys). Keep the native-ad + interstitial sections.
- `docs/specs/buzzvil-sdk-api-mapping.md`: move BuzzBanner out of Deferred; document props/events + Android lifecycle guard + iOS config/delegate.
- Gate: `yarn typecheck && yarn lint && yarn test` + both native builds.

---

## Task 5 — Final verification + PR

- Full gates (typecheck/lint/test/prepare/build:android/build:ios).
- Comprehensive Android↔iOS parity review (same `onLoaded`/`onFailed{code,message}`/`onClicked`; Android lifecycle guard; iOS requestAd/removeAd on mount/unmount; clean teardown both).
- On-device smoke (registered bundle + logged-in user): banner renders at the chosen size; `onLoaded` fires; tap → `onClicked` + landing.
- Push `feat/buzz-banner` + open PR. (Version bump to 0.3.0 handled at the next release, separate from this PR.)

---

## Risks

1. **`BuzzBannerView` SDK availability / pod** — the design doc notes `BuzzvilSDK-WithoutThirdParty` limits full-screen/banner; confirm the configured pods vend `BuzzBannerView` (Task 1/3 codegen+compile gates catch this).
2. **Android lifecycle guard** — easy to forget; it's the documented silent bug (background impressions / leak). REQUIRED in Task 2.
3. **iOS rootViewController for `setConfig`** — banners need a presenting VC for click handling; resolve at runtime (`RCTPresentedViewController()`), guard nil.
4. Exact SDK selectors differ from the design-doc sketch — verify against AAR / `-Swift.h` per task (as in the Native ad + Interstitial work).
