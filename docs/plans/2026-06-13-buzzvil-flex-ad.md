# Buzzvil FlexAd — Implementation Plan

**Goal:** add Buzzvil BuzzBenefit v6 **FlexAd** as a Fabric component
`BuzzFlexAdView` (public wrapper `BuzzFlexAd`), mirroring `BuzzBanner`'s
architecture (controller object + bindable SDK view + load/fail/click events).

## Doc verification summary

**Android** (`docs.buzzvil.com/docs/buzzbenefit-android/v6/flexad`, confirmed via
`javap` on `buzzad-benefit-base-6.7.7.aar`):

- `com.buzzvil.buzzbenefit.flexad.BuzzFlex(unitId: String)` — `setListener(Listener)`,
  `setPrimaryColor(Int)`, `load()`, `dispose()`.
- `BuzzFlex.Listener`: `onSuccess()`, `onFailure(BuzzAdError)`, `onClicked()`.
- `com.buzzvil.buzzbenefit.BuzzAdError.getType()` → `BuzzAdError.Type` enum
  (same symbolic-name shape as the native-ad error, NOT BuzzBanner's numeric code).
- `com.buzzvil.buzzbenefit.flexad.BuzzFlexAdView extends LinearLayout`, ctor
  `(Context, AttributeSet)` (no plain-`Context` ctor → construct with
  `(context, null)`), `bind(BuzzFlex)`. Self-contained — inflates its own
  internal layout, manages its own attach/detach lifecycle (no
  `handleResume`/`handlePause` wiring needed, unlike `BuzzNative`).
- Sizing: ad content is 16:9, total view height ≈ 16:9 + ~41dp (CTA + divider).
  Width fills the container.

**iOS** (`docs.buzzvil.com/docs/buzzbenefit-ios/v6/flexad`, confirmed via
`BuzzAdBenefitSDK-Swift.h` + `.swiftinterface`):

- `BuzzFlex(unitId:)` — `@objc`, `delegate: BuzzFlexDelegate?` (weak),
  `setPrimaryColor(UIColor)`, `load()`. Fully Obj-C-bridgeable.
- `BuzzFlexDelegate` (`@objc optional`): `buzzFlexOnSuccess()`,
  `buzzFlexOnFailure(_ error: Error)`, `buzzFlexOnClicked()`.
- `BuzzFlexAdView: UIView` — `init(frame:)` is `@objc`, but **`bind(_:)` and
  `setLoadingText(_:)` are plain Swift, NOT `@objc`** → unreachable from
  Obj-C++ directly. Requires a minimal `@objc` Swift shim exposing just `bind`.
- Sizing: same 16:9 + ~41pt; height auto-calculated, don't pin an explicit
  height constraint; width fills the container.

**Conclusion:** near-identical to `BuzzBanner` — controller (`BuzzFlex`) +
listener/delegate (`onSuccess`/`onFailure`/`onClicked` ↔
`onLoaded`/`onFailed`/`onClicked`) + bindable SDK view. iOS needs one
`@objc` shim method (`bind`); Android needs none.

## Public API

`BuzzFlexAd` (`BuzzFlexAdView` Fabric component, library `BuzzvilSpec`):

```ts
interface BuzzFlexAdProps {
  unitId: string;
  primaryColor?: ColorValue; // optional → SDK default if omitted
  style?: StyleProp<ViewStyle>;
  onLoaded?: () => void;
  onFailed?: (e: { code: string; message: string }) => void;
  onClicked?: () => void;
}
```

- `onFailed.code` = `BuzzAdError.Type` enum name (Android) / NSError
  domain+code (iOS) — mirrors the native-ad / BuzzBanner conventions
  respectively (symbolic vs domain-qualified).
- No size prop: FlexAd has one shape (16:9 + CTA). Consumer sizes via `style`
  (width drives height under Fabric, same "consumer style wins" gotcha as the
  other components — document in the spec mapping).

## Tasks

1. **Spec + JS wrapper (TDD) + native stubs** — `BuzzFlexAdViewNativeComponent.ts`,
   `BuzzFlexAd.native.tsx`/`.tsx`, `types.ts`, `index.tsx`, jest tests mirroring
   `BuzzBanner.test.tsx`. `package.json` codegen: register `BuzzFlexAdView` iOS
   component. Native stubs (empty Kotlin/Obj-C++ that compile) + manager
   registration in `BuzzvilPackage.kt`.
2. **Android implementation** — `BuzzFlexAdView.kt` (host `FrameLayout`,
   `loadIfReady` guard keyed on `unitId`, mirrors `BuzzBannerView.kt` minus the
   lifecycle-listener plumbing since the SDK view self-manages), `BuzzFlexAdViewManager.kt`
   (props + event constants + `onDropViewInstance` → `dispose()`).
3. **iOS implementation** — `ios/BuzzFlexAdShim.swift` (one `@objc` static
   `bind` method), `ios/BuzzFlexAdHost.{h,mm}` (SDK isolation, mirrors
   `BuzzBannerAdHost`), `ios/BuzzFlexAdView.{h,mm}` (Fabric host). Add
   `s.swift_version` to `Buzzvil.podspec` (first Swift file in the pod).
4. **Example + docs** — smoke-test section in `example/src/App.tsx`
   (placeholder `BUZZVIL_FLEXAD_UNIT_ID`), move FlexAd from "Deferred" to
   "implemented" in `docs/specs/buzzvil-sdk-api-mapping.md`.
5. **Final verification + PR** — `yarn typecheck && yarn lint && yarn test`,
   `yarn turbo run build:android build:ios`.

## Verification reality

Same as prior surfaces: JS gates are real TDD; native compile is
compile-only verification; on-device ad rendering is manual smoke (not
CI-verifiable, needs real `unitId` + logged-in user).

## Risks

1. iOS shim surface is intentionally tiny (one static `bind` call) — keep it
   that way; everything else (`BuzzFlex`, `BuzzFlexAdView` init, delegate) is
   directly Obj-C++-usable.
2. `BuzzFlexAdView(Context, AttributeSet)` has no plain-`Context` constructor —
   must pass `(context, null)`.
3. Sizing: no fixed layout-variant table like native-ad; document the 16:9 +
   ~41dp/pt rule in the spec mapping so consumers size `style` correctly.
