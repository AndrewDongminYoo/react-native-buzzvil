# Buzzvil BuzzBenefit v6 — RN bridge ↔ native API mapping

Status: **spec / current**. This is the contract the TurboModule spec
(`src/NativeBuzzvil.ts`) wraps and the reference for implementing the native
modules (`android/.../BuzzvilModule.kt`, `ios/Buzzvil.mm`).

Source docs:

- Android: <https://docs.buzzvil.com/docs/buzzbenefit-android/v6/introduction>
- iOS: <https://docs.buzzvil.com/docs/buzzbenefit-ios/v6/introduction>

## v1 surface (implemented in the spec)

Scope is the **common, foundational** surface only: initialize → login →
present BenefitHub. Feature-specific inventory (FlexAd, Pop/EntryPoint)
is deferred until the PRD defines which are used. LuckyBox is accessible
via `showLuckyBox()` (no new native code; routes through `showBenefitHub`
with `page: 'luckyBox'`).

| Bridge method (`Spec`)                      | Android (`BuzzvilSdk` / `BuzzBenefitHub`)                                                                     | iOS (`BuzzBenefit.shared` / `BuzzBenefitHub`)                                                      |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `initialize(appId)`                         | `BuzzvilSdk.initialize(application, BuzzBenefitConfig.Builder(appId).build())`                                | `BuzzBenefit.shared.initialize(with: BuzzBenefitConfig.Builder(appId:).build())`                   |
| `login(userId, gender, birthYear): Promise` | `BuzzvilSdk.login(BuzzvilSdkUser(userId, Gender?, birthYear?), BuzzvilSdkLoginListener{onSuccess/onFailure})` | `BuzzBenefit.shared.login(with: BuzzBenefitUser.Builder(userId:)…build(), onSuccess:, onFailure:)` |
| `logout()`                                  | `BuzzvilSdk.logout()`                                                                                         | `BuzzBenefit.shared.logout()`                                                                      |
| `isLoggedIn(): Promise<boolean>`            | `BuzzvilSdk.isLoggedIn` (property)                                                                            | `BuzzBenefit.shared.isLoggedIn()`                                                                  |
| `showBenefitHub(routePath, showHistory, page)` | `BuzzBenefitHub.show(currentActivity, BuzzBenefitHubConfig.Builder()…build())`                              | `BuzzBenefitHub().show(on: currentViewController)` (+ `BuzzBenefitHubConfig.Builder()`)            |

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
| `page`        | named page; `''` → not set. `'luckyBox'` / `'missionPack'` / `'history'`. Takes precedence over `routePath`/`showHistory` |

### Named BenefitHub pages (LuckyBox / MissionPack / History)

The SDK exposes `BuzzBenefitHubPage` (Android enum `LUCKY_BOX` / `MISSION_PACK`
/ `HISTORY`; iOS class properties `luckyBox` / `missionPack` / `history`). Its
`toRoutePath()` returns the route string and `toRedirectQueryParams()` the
history redirect — both computed at runtime, so the route values are **not**
hardcoded in JS. The `page` sentinel carries the page name to native, which
resolves it:

- `'luckyBox'` / `'missionPack'` → `configBuilder.routePath(PAGE.toRoutePath())`
- `'history'` → `configBuilder.queryParams(HISTORY.toRedirectQueryParams())`
  (identical to the legacy `showHistory: true` path)

JS surface: `showLuckyBox()` is a convenience for `showBenefitHub({ page:
'luckyBox' })`. `showHistory: true` and `page: 'history'` are equivalent; both
are supported.

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

## Interstitial (TurboModule — imperative + close event)

Added to the `Buzzvil` TurboModule (`src/NativeBuzzvil.ts`); friendly wrapper
`src/interstitial.native.tsx` (web fallback `src/interstitial.tsx`). The native
side holds one instance per `unitId` (design Decision 1). **Implemented**
(spec + JS wrapper + native impls).

### JS API (`src/interstitial.native.tsx`, re-exported from `src/index.tsx`)

| Function                                                | Behavior                                                                                 |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `loadInterstitial(unitId, type?): Promise<void>`        | Loads for `unitId`; resolves on loaded, rejects on load-fail. `type` default `'dialog'`. |
| `showInterstitial(unitId): void`                        | Presents the interstitial previously loaded for `unitId`.                                |
| `addInterstitialClosedListener(unitId, cb): { remove }` | Subscribes to the close event, filtered to the given `unitId`.                           |

- `type InterstitialType = 'dialog' \| 'bottomSheet'`.
- The `onInterstitialClosed` event carries payload `{ unitId }`; the wrapper
  gates the callback on `event.unitId === unitId` so listeners for other units
  never fire.

### Native mapping

| Bridge member (`Spec`)                    | Android (`BuzzInterstitial`)                                               | iOS (`BuzzInterstitial`)                                        |
| ----------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `loadInterstitial(unitId, type): Promise` | `Builder(unitId).buildDialog()` / `.buildBottomSheet()`; `.load(listener)` | `BuzzInterstitial(unitId:type:)`, set delegate, `load()`        |
| `showInterstitial(unitId)`                | `.show(context)` on the stored instance (UI thread, `currentActivity`)     | `present(on:)` from `RCTPresentedViewController()` (main queue) |
| `onInterstitialClosed: EventEmitter`      | `onAdClosed` → `emitOnInterstitialClosed({unitId})`                        | `BuzzInterstitialDidDismiss` → `emitOnInterstitialClosed:`      |

- **Android:** `BuzzInterstitial.Builder(unitId).buildDialog()` /
  `.buildBottomSheet()`, with a `BuzzInterstitialListener` (load / fail / close)
  kept in a `unitId`-keyed map.
- **iOS:** `BuzzInterstitial(unitId:type:)` with a `BuzzInterstitialDelegate`
  (`buzzInterstitialDidLoadAd:` / `...didFailToLoadAd:withError:` /
  `buzzInterstitialDidDismiss:`); shown via `presentOnViewController:`.

`type` carries `'dialog'` / `'bottomSheet'` as a plain string (no codegen
enums); the `InterstitialType` union + `'dialog'` default live in the wrapper.
`load` resolves on `onAdLoaded` / `DidLoadAd`, rejects on `onAdLoadFailed` /
`DidFail(toLoadAd:)`.

A concurrent `loadInterstitial` for a `unitId` that is already in flight is
rejected with `buzzvil_interstitial_load_failed`.

### Interstitial events — codegen mechanism decision (verified)

\*\*Decision: codegen typed `EventEmitter<T>` (NOT the classic `NativeEventEmitter`

- `addListener`/`removeListeners` pattern).\*\* The spec member is:

```ts
readonly onInterstitialClosed: CodegenTypes.EventEmitter<InterstitialClosedEvent>;
```

Imported as `CodegenTypes.EventEmitter` (matches the existing
`BuzzvilNativeAdViewNativeComponent.ts` convention). Note: the runtime
`EventEmitter` exported from `react-native`'s index is a **class**, not this
type — so it must come from the `CodegenTypes` namespace. Codegen matches the
event member by the **bare type name** `EventEmitter` (`getTypeAnnotationName`
returns the `.right.name` of a qualified name), so `CodegenTypes.EventEmitter`
is recognized identically to a bare `EventEmitter`.

**Empirical evidence (RN 0.85 codegen, run against this spec):**

- Schema: `onInterstitialClosed` parsed as
  `{"type":"EventEmitterTypeAnnotation","typeAnnotation":{"type":"TypeAliasTypeAnnotation","name":"InterstitialClosedEvent"}}`.
- Generated Java (`NativeBuzzvilSpec.java`): a **concrete** `protected final void
emitOnInterstitialClosed(ReadableMap value)` — `loadInterstitial`/`showInterstitial`
  are the only new `abstract` methods.
- Generated iOS (`BuzzvilSpecJSI.h` + `BuzzvilSpec.h`): concrete
  `emitOnInterstitialClosed(...)` on `NativeBuzzvilCxxSpec`, `eventEmitterMap_`
  auto-registers `"onInterstitialClosed"`, and `emitOnInterstitialClosed:` is
  declared in the `RCTTurboModule` category (concrete).

**Consequences:** the native stubs implement only `loadInterstitial` /
`showInterstitial`; the emit hook needs no stub. The JS wrapper subscribes via
the generated `onInterstitialClosed` member (shape `(handler) =>
EventSubscription`) and filters by `event.unitId`.

## BuzzBanner (Fabric component `BuzzBannerView`)

Implemented as a Fabric (New Architecture) view component (like the native ad,
not a TurboModule method). The TS spec is `src/BuzzBannerViewNativeComponent.ts`;
the friendly wrapper is `src/BuzzBanner.native.tsx` (web fallback:
`src/BuzzBanner.tsx`), re-exported from `src/index.tsx`. **Implemented** (spec +
JS wrapper + native impls).

### JS API (`src/BuzzBanner.native.tsx`)

```tsx
<BuzzBanner placementId size onLoaded onFailed onClicked />
```

| Prop          | Type                             | Notes                                                           |
| ------------- | -------------------------------- | --------------------------------------------------------------- |
| `placementId` | `string`                         | BuzzBanner placement id from the Buzzvil admin. Required.       |
| `size`        | `BannerSize`                     | `'W320XH50'` (320 × 50) or `'W320XH100'` (320 × 100). Required. |
| `onLoaded`    | `() => void`                     | Fires when the banner ad loads.                                 |
| `onFailed`    | `(e: { code; message }) => void` | Load failure; payload already unwrapped from `nativeEvent`.     |
| `onClicked`   | `() => void`                     | Fires on banner tap.                                            |

- `type BannerSize = 'W320XH50' \| 'W320XH100'`. The SDK's `DYNAMIC` size is
  **deferred** (not exposed).
- Like the native ad, under Fabric the host frame comes from the JS shadow node
  (`style`). Give the banner an explicit width/height matching the `size`
  (320 × 50 / 320 × 100), or iOS bounds stay `0` and the ad never loads.
- `onFailed.code` is the SDK's **numeric** error code rendered as a string
  (distinct from the native ad's symbolic codes).

### Native mapping

| Bridge member (`Spec`)                | Android (`com.buzzvil.buzzbanner`)                                                       | iOS (`BuzzBannerView`)                                                      |
| ------------------------------------- | ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `placementId` + `size`                | `BuzzBannerConfig(placementId, BuzzBanner.BannerSize)` → `BuzzBannerView`                | `BuzzBannerView` via `setConfigWithRootViewController:config:`              |
| load                                  | driven by the Activity lifecycle (`onResume()`), wired via `LifecycleEventListener`      | `requestAd`                                                                 |
| unload / teardown                     | `onDestroy()` + unregister the `LifecycleEventListener` on drop                          | `removeAd`                                                                  |
| `onLoaded` / `onFailed` / `onClicked` | `BuzzBannerViewListener` (`onLoaded` / `onFailed(AdError)` → code/message / `onClicked`) | `BuzzBannerViewDelegate` (`didLoad` / `didFail` / `didClick` / `didRemove`) |

- **Android:** hosts `com.buzzvil.buzzbanner.BuzzBannerView`, configured with
  `BuzzBannerConfig` (placement id + `BuzzBanner.BannerSize`) and a
  `BuzzBannerViewListener`. The **load is driven by the Activity lifecycle**:
  the view loads on `onResume()`, wired through a `LifecycleEventListener` (with
  an explicit resume kick at mount so the first load fires); `onDestroy()` tears
  it down and the listener is unregistered when the view is dropped.
- **iOS:** hosts `BuzzBannerView`, configured via
  `setConfigWithRootViewController:config:` then `requestAd` (and `removeAd` on
  teardown), with a `BuzzBannerViewDelegate` (`didLoad` / `didFail` / `didClick`
  / `didRemove`).

### Init asymmetry (important)

BuzzBanner has a platform-specific init requirement:

- **Android** BuzzBanner needs `BuzzBanner().init(appId, appSecret, context)`,
  wired through the `appSecret` arg now accepted by `initialize(appId, appSecret)`.
- **iOS** needs **no** separate banner init — the standard
  `BuzzBenefit.shared.initialize(...)` is sufficient.

So `appSecret` is required **only** for BuzzBanner on Android; it is optional
(sentinel `''`) for every other surface.

## FlexAd (Fabric component `BuzzFlexAdView`)

Implemented as a Fabric (New Architecture) view component (like `BuzzBanner`,
not a TurboModule method). The TS spec is `src/BuzzFlexAdViewNativeComponent.ts`;
the friendly wrapper is `src/BuzzFlexAd.native.tsx` (web fallback:
`src/BuzzFlexAd.tsx`), re-exported from `src/index.tsx`. **Implemented** (spec +
JS wrapper + native impls).

### JS API (`src/BuzzFlexAd.native.tsx`)

```tsx
<BuzzFlexAd unitId primaryColor onLoaded onFailed onClicked />
```

| Prop           | Type                             | Notes                                                                       |
| -------------- | -------------------------------- | --------------------------------------------------------------------------- |
| `unitId`       | `string`                         | FlexAd unit id from the Buzzvil admin. Required.                            |
| `primaryColor` | `ColorValue`                     | Optional accent color (`BuzzFlex.setPrimaryColor`). SDK default if omitted. |
| `onLoaded`     | `() => void`                     | Fires when the ad has loaded and been bound to the view.                    |
| `onFailed`     | `(e: { code; message }) => void` | Load failure; payload already unwrapped from `nativeEvent`.                 |
| `onClicked`    | `() => void`                     | Fires on ad tap.                                                            |

- FlexAd has a single fixed layout (no size variants, unlike the native ad /
  BuzzBanner). The ad content is **16:9**, and the total view height is
  **16:9 + ~41dp/pt** (CTA button + divider, auto-added by the SDK).
- As with the native ad / BuzzBanner, under Fabric the host frame comes from
  the JS shadow node (`style`) — give the view an explicit width and a height
  of `width * 9/16 + 41`, or iOS bounds stay `0` and the ad never loads.
- `onFailed.code` is the **NSError code as a string** on iOS (the `message`
  appends `domain`/`code` for self-describing logs, mirroring BuzzBanner) and
  the **symbolic `BuzzAdError.Type` name** on Android (mirroring the native ad)
  — the two platforms intentionally differ here, following each platform's
  existing convention for their respective error shapes.

### Native mapping

| Bridge member (`Spec`)                | Android (`com.buzzvil.buzzbenefit.flexad`)                                 | iOS (`BuzzFlex` / `BuzzFlexAdView`)                                                         |
| ------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `unitId`                              | `BuzzFlex(unitId)`                                                         | `BuzzFlex(unitId:)`                                                                         |
| `primaryColor`                        | `BuzzFlex.setPrimaryColor(Int)`                                            | `BuzzFlex.setPrimaryColor(UIColor)`                                                         |
| load                                  | `BuzzFlex.load()`                                                          | `BuzzFlex.load()`                                                                           |
| bind                                  | `BuzzFlexAdView.bind(buzzFlex)` on `onSuccess`                             | `BuzzFlexAdView.bind(_:)` on `buzzFlexOnSuccess` (via Swift shim — see below)               |
| unload / teardown                     | `BuzzFlex.dispose()`                                                       | `BuzzFlex.delegate = nil` + drop references                                                 |
| `onLoaded` / `onFailed` / `onClicked` | `BuzzFlex.Listener` (`onSuccess` / `onFailure(BuzzAdError)` / `onClicked`) | `BuzzFlexDelegate` (`buzzFlexOnSuccess` / `buzzFlexOnFailure(Error)` / `buzzFlexOnClicked`) |

- **Android:** hosts `com.buzzvil.buzzbenefit.flexad.BuzzFlexAdView` (a
  `LinearLayout`), constructed with `(context, null)` (no plain-`Context`
  constructor). The SDK view is **self-contained** — it inflates its own
  layout and manages its own attach/detach lifecycle; unlike the native ad, no
  external `handleResume`/`handlePause` wiring is needed.
- **iOS:** hosts `BuzzFlexAdView` (a `UIView`). `BuzzFlex` and
  `BuzzFlexAdView`'s designated initializer are fully `@objc`/Obj-C-bridgeable,
  but **`BuzzFlexAdView.bind(_:)` and `setLoadingText(_:)` are plain Swift, not
  `@objc`** — calling `bind` requires the small `@objc` shim
  `ios/BuzzFlexAdShim.swift` (`BuzzFlexAdBinder.bind(_:to:)`). This is the only
  Swift file in the pod; `Buzzvil.podspec` sets `s.swift_version`.
- Both platforms' Fabric class is named `BuzzFlexAdView`, which collides with
  the SDK's own view class of the same name on each platform — isolated via
  `ios/BuzzFlexAdHost.{h,mm}` (Obj-C++) / a Kotlin import alias
  (`BuzzFlexAdView as SdkBuzzFlexAdView`), mirroring `BuzzBannerAdHost`.

## Deferred (not in v1)

Pop/EntryPoint, UI configuration.
Add to the spec per the PRD. (Native ads + Interstitial + BuzzBanner + FlexAd
are implemented; LuckyBox is reachable via `showLuckyBox()` — see above.)
