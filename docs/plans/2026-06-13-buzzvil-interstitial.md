# Buzzvil Interstitial Ad — Implementation Plan

> **Execution:** subagent-driven (implementer per task + spec/quality review), same as the Native ad work.
> **Spec source:** `docs/specs/2026-06-12-ad-formats-expansion-design.md` (M1 → Interstitial). This plan is the executable task breakdown.

**Goal:** Add Buzzvil BuzzBenefit v6 **Interstitial** (full-screen modal) ads to the existing `Buzzvil` TurboModule — the **imperative + events** pattern (distinct from the Fabric-view Native ad already shipped).

**Architecture:** Extend the existing `Buzzvil` TurboModule (no new native module, no Fabric component). The native side holds each `BuzzInterstitial` instance in a **map keyed by `unitId`**: `loadInterstitial(unitId, type)` creates + loads; `showInterstitial(unitId)` presents the stored instance; the close callback surfaces to JS as an `onInterstitialClosed` event. Per design-doc Decisions 1–2.

**Tech stack:** unchanged from the Native work — RN 0.85 New-Arch codegen, Kotlin/AGP (Android), Obj-C++ + direct Swift-SDK calls (iOS), `BuzzvilSDK`/`BuzzAdBenefitSDK ~> 6.7.5`.

---

## Public API (M1)

```ts
type InterstitialType = 'dialog' | 'bottomSheet';
loadInterstitial(unitId: string, type?: InterstitialType): Promise<void>; // resolves on loaded, rejects on load-fail
showInterstitial(unitId: string): void;                                   // presents the loaded instance
addInterstitialClosedListener(unitId: string, cb: () => void): { remove(): void };
```

### TurboModule spec additions (`src/NativeBuzzvil.ts`)

Primitive-only (codegen constraint), reusing the project's sentinel/string conventions:

```ts
loadInterstitial(unitId: string, type: string): Promise<void>;
showInterstitial(unitId: string): void;
readonly onInterstitialClosed: EventEmitter<{ unitId: string }>;
```

`type` carries `'dialog' | 'bottomSheet'` as a string; the JS wrapper exposes the union + default.

---

## Verification reality (same as Native)

Real TDD applies to the **JS wrapper** (jest + the mocked `NativeBuzzvil`, mirroring `src/__tests__/index.test.tsx`). Native Kotlin/Obj-C++ is verified by **codegen + compile + on-device smoke**. The Buzzvil test environment serves sample ads regardless of unit ID (bundle-gated), so on-device smoke needs only the registered example bundle + a logged-in user — not specific real unit IDs.

Gates per task: `yarn typecheck` · `yarn lint` · `yarn test` → codegen (`pod install` / Gradle) → `yarn turbo run build:android|ios` → manual on-device smoke (Task 5).

---

## Task 1 — Spec + JS wrapper (TDD) + native STUBS (green-to-green)

**Files:** modify `src/NativeBuzzvil.ts`, `src/types.ts`, `src/index.tsx`; create `src/interstitial.native.tsx`, `src/interstitial.tsx`, tests in `src/__tests__/index.test.tsx`; **stub** the new methods in `android/.../BuzzvilModule.kt` + `ios/Buzzvil.mm` so codegen-generated abstracts are satisfied and both builds stay green.

- **Spec:** add the three members above. **First, verify RN 0.85 codegen accepts `EventEmitter<T>` in a TurboModule spec** (run `pod install` / Gradle codegen). If it does → use it. If it does NOT → fall back to the classic emitter (`addListener(eventName)` / `removeListeners(count)` on the spec + `NativeEventEmitter` in JS) and document the choice. Record the outcome in `docs/specs/buzzvil-sdk-api-mapping.md`.
- **types.ts:** `export type InterstitialType = 'dialog' | 'bottomSheet';`
- **JS wrapper** (`interstitial.native.tsx`): pure-testable mapping — `loadInterstitial(unitId, type = 'dialog')` → `Native.loadInterstitial(unitId, type)`; `showInterstitial(unitId)`; `addInterstitialClosedListener(unitId, cb)` subscribes to `onInterstitialClosed`, invokes `cb` only when `event.unitId === unitId`, returns `{ remove }`. Web (`interstitial.tsx`): `loadInterstitial` rejects, `showInterstitial` throws, listener returns a no-op `{ remove }` — all with the existing `'react-native-buzzvil is not supported on web.'` message.
- **index.tsx:** export the three functions + `InterstitialType`.
- **Native stubs:** `BuzzvilModule.kt` + `Buzzvil.mm` implement the new methods as no-ops/`TODO` (load rejects-or-noops, show noop) **only enough to compile** — real behavior in Tasks 2–3. Keep both builds green.
- **TDD:** failing jest first (type default, unitId passthrough, listener filters by `unitId`, listener `remove`), then implement the wrapper. Then full green-to-green gate (typecheck/lint/test + `pod install` + `build:android` + `build:ios`).

---

## Task 2 — Android Interstitial implementation (`BuzzvilModule.kt`)

Fill the stubs. Per design-doc native notes:

- Hold instances: `private val interstitials = mutableMapOf<String, BuzzInterstitial>()`.
- `loadInterstitial(unitId, type, promise)`: build `BuzzInterstitial.Builder(unitId).buildDialog()` or `.buildBottomSheet()` per `type`; store in the map; `.load(listener)` where `onAdLoaded → promise.resolve(null)`, `onAdLoadFailed(error) → promise.reject(...)`, `onAdClosed → emit onInterstitialClosed { unitId }`.
- `showInterstitial(unitId)`: on the UI thread (`UiThreadUtil.runOnUiThread`), `interstitials[unitId]?.show(currentActivity)` (parity with the BenefitHub threading).
- Emit via the codegen event-emitter API decided in Task 1.
- **Verify exact API against the resolved AAR** (`javap` / compiler) — confirm `BuzzInterstitial.Builder`, `buildDialog`/`buildBottomSheet`, `BuzzInterstitialListener` method names, and `show(...)`'s context arg. Adjust to reality.
- Gate: `yarn turbo run build:android` compiles. Lifecycle: drop instance from the map after close to avoid leaks.

---

## Task 3 — iOS Interstitial implementation (`Buzzvil.mm`, DIRECT)

Fill the stubs, calling the Swift SDK directly via `<BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h>` (no shim — same as the Native ad; verify exact Obj-C selectors in that header first).

- Hold instances: an `NSMutableDictionary<NSString *, BuzzInterstitial *>` keyed by `unitId`.
- `loadInterstitial:type:resolve:reject:`: construct `BuzzInterstitial` (with `unitId` + `type`), set its delegate (or closures), store, `load`. Delegate: `DidLoadAd → resolve`, `DidFail(toLoadAd:withError:) → reject`, `DidDismiss → emit onInterstitialClosed`.
- `showInterstitial:`: on the main queue, `present(on: RCTPresentedViewController())` for the stored instance.
- Emit via the generated event-emitter API from Task 1.
- **Verify** the exact `BuzzInterstitial` initializer + delegate protocol selectors in the generated `-Swift.h`. Gate: `pod install` + `build:ios` compiles.

---

## Task 4 — Example smoke screen + docs

- **`example/src/App.tsx`:** add an Interstitial section — `type` picker (`dialog`/`bottomSheet`), a **Load** button (`loadInterstitial(UNIT_ID, type)`, log resolve/reject), a **Show** button (`showInterstitial(UNIT_ID)`), and an `addInterstitialClosedListener` wired into the event log. Keep the existing Native ad section. **Keep `BUZZVIL_APP_ID`/`BUZZVIL_UNIT_ID` placeholders** (do not commit real keys); reuse the committed UUID `userId`.
- **`docs/specs/buzzvil-sdk-api-mapping.md`:** move Interstitial out of Deferred; document the API + the Task-1 event-emitter decision.
- Gate: `yarn typecheck && yarn lint && yarn test` (add wrapper tests already in Task 1) + both native builds.

---

## Task 5 — Final verification + PR

- Full gates green (typecheck/lint/test/prepare/build:android/build:ios).
- Comprehensive review (Android↔iOS parity: same resolve/reject semantics, same `onInterstitialClosed` payload, instance cleanup on both).
- **On-device smoke** (example app, registered bundle, logged-in user): Load → resolves; Show → modal appears; dismiss → `onInterstitialClosed` fires; load-fail path rejects.
- Push `feat/interstitial` + open PR.

---

## Risks

1. **`EventEmitter<T>` codegen support** in RN 0.85 (Task 1 gates this; fallback = `NativeEventEmitter`). Highest unknown — front-loaded.
2. **Instance-map lifecycle** — leak/stale if not removed after close; both platforms must drop the entry.
3. **`show` before `load`** (or after close) — `showInterstitial` must no-op safely if the `unitId` isn't in the map.
4. Exact SDK selectors differ from the design-doc sketch — verify against AAR / `-Swift.h` per task (as in the Native work).
