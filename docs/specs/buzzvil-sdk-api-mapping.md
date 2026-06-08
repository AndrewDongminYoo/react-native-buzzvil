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

Native ads, Interstitial, BuzzBanner, FlexAd, Pop/EntryPoint, LuckyBox,
UI configuration. Add to the spec per the PRD.
