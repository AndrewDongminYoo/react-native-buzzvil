import { TurboModuleRegistry, type TurboModule } from 'react-native';
import type { CodegenTypes } from 'react-native';

/**
 * Payload for the interstitial "closed" event. Flat primitive (codegen events
 * cannot carry nested objects); `unitId` identifies which placement closed so
 * the JS wrapper can route the callback to the right listener.
 */
type InterstitialClosedEvent = Readonly<{ unitId: string }>;

/**
 * TurboModule spec for the native `Buzzvil` module — a thin bridge over
 * Buzzvil's BuzzBenefit v6 SDKs (Android / iOS).
 *
 * This file is the **source of truth**: codegen generates the native
 * interfaces from it. The codegen type system is restricted, so the spec
 * intentionally uses **primitives only** — no optional fields, no object
 * params, no enums/unions. Friendly types (optional fields, the `'MALE' |
 * 'FEMALE'` gender union) live in `./types` and are applied in the JS
 * wrapper (`./buzzvil.native.tsx`).
 *
 * ## Sentinel contract (MUST be interpreted identically by both native impls)
 *
 * Because the spec has no optionals, the JS wrapper encodes "not provided"
 * as sentinel values. `BuzzvilModule.kt` and `Buzzvil.mm` must treat them
 * the same way or the platforms will silently diverge:
 *
 * - `gender`: `'MALE'` or `'FEMALE'`. **Empty string `''` → do not set gender**
 *   (pass `null` to the native user builder).
 * - `birthYear`: a 4-digit year. **`0` → do not set birth year** (pass `null`).
 * - `routePath`: a BenefitHub page number from the Buzzvil admin. **`''` → no
 *   route path** (open the default hub page).
 * - `showHistory`: `true` → open the BenefitHub history/earnings page
 *   (Android `BuzzBenefitHubPage.HISTORY` / iOS `.history` query params).
 */
export interface Spec extends TurboModule {
  /**
   * Initialize the BuzzBenefit SDK with the app's Buzzvil app id.
   *
   * - iOS: `BuzzBenefit.shared.initialize(with: BuzzBenefitConfig.Builder(appId:).build())`.
   * - Android: `BuzzvilSdk.initialize(application, BuzzBenefitConfig.Builder(appId).build())`.
   *
   * NOTE (verify at native-impl time): the Android SDK initializes with the
   * `Application` instance and the docs recommend `Application.onCreate()`
   * timing. JS-driven init must pass `reactContext.applicationContext as
   * Application` and run before any `login`/`showBenefitHub` call. If the
   * Android SDK turns out to require manifest/Application-level setup (as the
   * AdPopcorn wrapper's `setAppKey` does), this becomes iOS-effective with an
   * Android no-op — confirm against the running SDK before shipping.
   */
  initialize(appId: string): void;

  /**
   * Log a user into the SDK. Resolves on success, rejects on failure.
   *
   * See the sentinel contract above for `gender` / `birthYear`.
   *
   * - iOS: `BuzzBenefit.shared.login(with:onSuccess:onFailure:)`.
   * - Android: `BuzzvilSdk.login(BuzzvilSdkUser(...), BuzzvilSdkLoginListener)`.
   *
   * @param userId Non-identifiable, persistent user id. ASCII, max 255 chars.
   * @param gender `'MALE'` | `'FEMALE'` | `''` (unset).
   * @param birthYear 4-digit year, or `0` (unset).
   */
  login(userId: string, gender: string, birthYear: number): Promise<void>;

  /** Log the current user out. iOS/Android: `logout()`. */
  logout(): void;

  /** Whether a user is currently logged in. iOS `isLoggedIn()` / Android `isLoggedIn`. */
  isLoggedIn(): Promise<boolean>;

  /**
   * Present the BenefitHub (offerwall) over the current screen.
   *
   * - iOS: `BuzzBenefitHub().show(on: currentViewController)`.
   * - Android: `BuzzBenefitHub.show(currentActivity, config)`.
   *
   * See the sentinel contract above for `routePath` / `showHistory`.
   */
  showBenefitHub(routePath: string, showHistory: boolean): void;

  /**
   * Load an interstitial ad for `unitId`. Resolves when the ad has loaded
   * (Android `onAdLoaded` / iOS `BuzzInterstitialDidLoadAd`), rejects on
   * load failure (`onAdLoadFailed` / `DidFail(toLoadAd:)`).
   *
   * The native side holds one `BuzzInterstitial` instance per `unitId` (see
   * design Decision 1: a `unitId`-keyed map), so a later `showInterstitial`
   * presents this loaded instance.
   *
   * @param unitId Interstitial ad unit id from the Buzzvil admin.
   * @param type `'dialog'` or `'bottomSheet'` — selects the native build
   *   variant (`buildDialog()` / `buildBottomSheet()`). Carried as a plain
   *   string (no codegen enums); the friendly `InterstitialType` union and the
   *   `'dialog'` default live in the JS wrapper (`./interstitial.native.tsx`).
   */
  loadInterstitial(unitId: string, type: string): Promise<void>;

  /**
   * Present the interstitial instance previously loaded for `unitId`. No-op if
   * nothing is loaded. UI work — runs on the main thread (parity with
   * `showBenefitHub`).
   */
  showInterstitial(unitId: string): void;

  /**
   * Fires when an interstitial is dismissed (Android `onAdClosed` / iOS
   * `BuzzInterstitialDidDismiss`). The payload's `unitId` identifies which
   * placement closed; the JS wrapper filters by it so each
   * `addInterstitialClosedListener(unitId, …)` only fires for its own unit.
   *
   * Uses a codegen typed `EventEmitter` (RN New-Architecture event member):
   * codegen generates a concrete `emitOnInterstitialClosed` on the native spec
   * base class, so the native impl emits via that — no manual
   * `addListener`/`removeListeners` plumbing. Imported as
   * `CodegenTypes.EventEmitter` (the runtime `EventEmitter` exported from
   * `react-native` is a class, not this type); codegen matches by the bare
   * type name `EventEmitter`, so the `CodegenTypes.`-qualified form is
   * recognized identically.
   */
  readonly onInterstitialClosed: CodegenTypes.EventEmitter<InterstitialClosedEvent>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Buzzvil');
