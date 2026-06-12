# Buzzvil BuzzBenefit v6 — RN bridge ↔ native API mapping

Status: **spec / current**. This is the contract the TurboModule spec
(`src/NativeBuzzvil.ts`) wraps and the reference for implementing the native
modules (`android/.../BuzzvilModule.kt`, `ios/Buzzvil.mm`).

Source docs:

- Android: <https://docs.buzzvil.com/docs/buzzbenefit-android/v6/introduction>
- iOS: <https://docs.buzzvil.com/docs/buzzbenefit-ios/v6/introduction>

## v1 surface (implemented in the spec)

Scope is the **common, foundational** surface only: initialize → login →
present BenefitHub. Feature-specific inventory (Native, Interstitial,
BuzzBanner, FlexAd, Pop, LuckyBox) is deferred until the PRD defines which are
used.

| Bridge method (`Spec`)                      | Android (`BuzzvilSdk` / `BuzzBenefitHub`)                                                                     | iOS (`BuzzBenefit.shared` / `BuzzBenefitHub`)                                                      |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `initialize(appId)`                         | `BuzzvilSdk.initialize(application, BuzzBenefitConfig.Builder(appId).build())`                                | `BuzzBenefit.shared.initialize(with: BuzzBenefitConfig.Builder(appId:).build())`                   |
| `login(userId, gender, birthYear): Promise` | `BuzzvilSdk.login(BuzzvilSdkUser(userId, Gender?, birthYear?), BuzzvilSdkLoginListener{onSuccess/onFailure})` | `BuzzBenefit.shared.login(with: BuzzBenefitUser.Builder(userId:)…build(), onSuccess:, onFailure:)` |
| `logout()`                                  | `BuzzvilSdk.logout()`                                                                                         | `BuzzBenefit.shared.logout()`                                                                      |
| `isLoggedIn(): Promise<boolean>`            | `BuzzvilSdk.isLoggedIn` (property)                                                                            | `BuzzBenefit.shared.isLoggedIn()`                                                                  |
| `showBenefitHub(routePath, showHistory)`    | `BuzzBenefitHub.show(currentActivity, BuzzBenefitHubConfig.Builder()…build())`                                | `BuzzBenefitHub().show(on: currentViewController)` (+ `BuzzBenefitHubConfig.Builder()`)            |

## Sentinel contract (no optionals in codegen)

The spec is primitive-only, so the JS wrapper (`src/buzzvil.native.tsx`)
encodes "not provided" as sentinels. **Both native impls must interpret these
identically:**

| Param         | Sentinel meaning                                                                   |
| ------------- | ---------------------------------------------------------------------------------- |
| `gender`      | `'MALE'`/`'FEMALE'`; `''` → pass `null` to the user builder (don't set)            |
| `birthYear`   | 4-digit year; `0` → pass `null` (don't set)                                        |
| `routePath`   | admin page number; `''` → no route path (default hub)                              |
| `showHistory` | `true` → open history page (Android `BuzzBenefitHubPage.HISTORY` / iOS `.history`) |

## Native ad (Fabric component `BuzzvilNativeAdView`)

Implemented as a Fabric (New Architecture) view component, not a TurboModule
method. The TS spec is `src/BuzzvilNativeAdViewNativeComponent.ts`; the friendly
wrapper is `src/BuzzvilNativeAdView.native.tsx` (web fallback:
`src/BuzzvilNativeAdView.tsx`).

### Props

| Prop     | Type                    | Notes                                                                                   |
| -------- | ----------------------- | --------------------------------------------------------------------------------------- |
| `unitId` | `string`                | Native-ad unit id from the Buzzvil admin. Required.                                     |
| `layout` | `BuzzvilNativeAdLayout` | One of `320x50` / `320x100` / `320x130` / `300x250` / `320x480`. Defaults to `300x250`. |

### Events (friendly payloads, `nativeEvent` already unwrapped)

| Event         | Payload                             |
| ------------- | ----------------------------------- |
| `onAdLoaded`  | `{ width: number; height: number }` |
| `onAdFailed`  | `{ code: string; message: string }` |
| `onAdClicked` | _(none)_                            |
| `onImpressed` | _(none)_                            |
| `onRewarded`  | `{ success: boolean }`              |

### Size → family layout mapping

The `layout` size selects both a layout **family** and a fixed height:

| Layout    | Family | Default size (dp) |
| --------- | ------ | ----------------- |
| `320x50`  | banner | 320 × 50          |
| `320x100` | banner | 320 × 100         |
| `320x130` | banner | 320 × 130         |
| `300x250` | card   | 300 × 250         |
| `320x480` | card   | 320 × 480         |

Under Fabric the component's frame comes from the JS shadow node (its `style`),
so the native per-size height is only a hint. The wrapper applies the default
size above as the base `style`; a consumer `style` is layered on top and wins.
Without a JS-side height, iOS bounds stay `0` and `onAdLoaded` never fires —
hence the default. (Sizes are shared by both platforms via `src/layout.ts`.)

### iOS interop decision: DIRECT

No Swift shim. The BuzzAd Native-ad classes (`BuzzNative`,
`BuzzNativeViewBinder`, `BuzzNativeAdView`, `BuzzMediaView`, …) are exposed as
`@objc` in `<BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>` (verified against
BuzzAdBenefitSDK 6.7.5) and are called directly from `ios/BuzzvilNativeAdView.mm`
— the same direct-from-Obj-C++ import the TurboModule (`ios/Buzzvil.mm`) uses.
The view binder is built and bound as:

```objc
_binder = [BuzzNativeViewBinder viewBinderWith:^(BuzzNativeViewBinderBuilder *builder) {
  builder.nativeAdView = _adContainer;
  builder.mediaView = _mediaView;
  builder.iconImageView = _iconView;
  builder.titleLabel = _titleLabel;
  builder.descriptionLabel = _descriptionLabel;
  builder.ctaView = _ctaView;
}];
[_binder bind:_native]; // bind() takes the BuzzNative loader, not the loaded ad (mirrors Android)
```

## Open questions for native-impl time

1. **Android init path.** Confirm JS-driven init works by passing
   `reactContext.applicationContext as Application` and running before any
   `login`/`showBenefitHub`. If the SDK requires `Application.onCreate()` /
   manifest setup, `initialize` becomes iOS-effective with an Android no-op
   (mirror the AdPopcorn `setAppKey` asymmetry).
2. **`showBenefitHub` host.** Needs the current `Activity` (Android) /
   `UIViewController` (iOS); resolve from the bridge at call time.
3. **Reward/close events.** v6 docs expose no BenefitHub reward/close
   callbacks — verify against the actual SDK before promising any
   `EventEmitter` surface; none in v1.

## Deferred (not in v1)

Interstitial, BuzzBanner, FlexAd, Pop/EntryPoint, LuckyBox, UI configuration.
Add to the spec per the PRD. (Native ads are implemented — see above.)
