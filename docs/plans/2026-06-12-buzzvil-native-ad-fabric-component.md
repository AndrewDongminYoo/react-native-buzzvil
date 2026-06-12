# Buzzvil Native (in-feed) Ad — Fabric Component Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Canonical location on execution:** copy this file to `docs/plans/2026-06-12-buzzvil-native-ad-fabric-component.md` (plan mode restricted authoring to the scratch path). The repo also keeps design notes in `docs/specs/` — update `docs/specs/buzzvil-sdk-api-mapping.md` as part of Task 7.

**Goal:** Add a Buzzvil BuzzBenefit v6 **Native (in-feed) ad** as a React Native **Fabric Native Component** (`<BuzzvilNativeAdView unitId=… layout=… onAdLoaded=… />`), rendering real native ads on Android and iOS with load/click/impression/reward events.

**Architecture:** RN renders a host native view; the native side hosts Buzzvil's own ad view classes (`BuzzNativeAdView` + `BuzzNativeViewBinder` + `BuzzMediaView`/CTA) and binds an ad loaded via `BuzzNative(unitId).load(...)`. A "headless data-to-JS" approach is **not viable** — Buzzvil's impression/click/reward tracking is bound to its native view classes, so the views must live natively. Events surface to JS via Fabric direct events. The codegen TS spec is the source of truth and must stay in sync across all four layers (spec → Android ViewManager → iOS RCTViewComponentView → JS wrapper).

**Tech Stack:** React Native 0.85.0, React 19.2.3, TypeScript 6 (strict), Yarn 4 workspaces, New Architecture (Fabric/TurboModules) codegen, Kotlin 2.0.21 / AGP 8.7.2 (Android), Obj-C++ + Swift (iOS), Buzzvil BuzzBenefit v6 (`com.buzzvil:buzzvil-bom:6.7.+` / pods `BuzzvilSDK` + `BuzzAdBenefitSDK` `~> 6.7.5`).

---

## Context — why this change, and the exact starting state

The library already ships a working **v1 TurboModule** (`Buzzvil`: `initialize`/`login`/`logout`/`isLoggedIn`/`showBenefitHub`), committed at HEAD. `docs/specs/buzzvil-sdk-api-mapping.md` lists the ad units as **Deferred**. The user chose **Native (in-feed) ads** as the next surface (there is a `docs/BDG-Inventory 크기별 Native 광고 layout 가이드…pdf` layout guide in the repo confirming inventory-size layout variants are wanted), and **on-device smoke testing** as the verification bar (they have / will obtain real Buzzvil app + unit IDs and a device).

**The working tree is already mid-migration and must be reconciled — it does not build as-is.** Someone re-ran `create-react-native-library` (bumping it `0.62.0`→`0.62.2`, flipping the template `turbo-module`→`fabric-view`) which dropped in the **stock placeholder `BuzzvilView` color-box component** on top of the committed module. Verified uncommitted state (`git diff HEAD`, `git status`):

| Path                                                 | State     | Note                                                                                                                                                                                                                  |
| ---------------------------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `package.json`                                       | modified  | `codegenConfig.type` `modules`→`all`; added `ios.components.BuzzvilView`→`className BuzzvilView`; **kept** `name: "BuzzvilSpec"` and `javaPackageName: "com.buzzvil"`; CRL `type`→`fabric-view`; several devDep bumps |
| `src/BuzzvilViewNativeComponent.ts`                  | untracked | `codegenNativeComponent<{color?: ColorValue}>('BuzzvilView')`                                                                                                                                                         |
| `src/BuzzvilView.tsx` / `src/BuzzvilView.native.tsx` | untracked | web fallback colored `<View>` / re-export of the codegen component                                                                                                                                                    |
| `src/index.tsx`                                      | modified  | adds `export { BuzzvilView } from './BuzzvilView';`                                                                                                                                                                   |
| `android/.../com/buzzvil/BuzzvilView.kt`             | untracked | plain `android.view.View` subclass                                                                                                                                                                                    |
| `android/.../com/buzzvil/BuzzvilViewManager.kt`      | untracked | `SimpleViewManager`, `color` prop, `NAME="BuzzvilView"`, uses generated `com.facebook.react.viewmanagers.BuzzvilViewManagerInterface/Delegate`                                                                        |
| `android/.../com/buzzvil/BuzzvilPackage.kt`          | modified  | added `createViewManagers` → `listOf(BuzzvilViewManager())` — **but missing `import com.facebook.react.uimanager.ViewManager`** (won't compile)                                                                       |
| `ios/BuzzvilView.h` / `ios/BuzzvilView.mm`           | untracked | `RCTViewComponentView`, `color` prop — **but imports `<react/renderer/components/BuzzvilViewSpec/…>` while the codegen library is `BuzzvilSpec`** (won't compile)                                                     |
| `example/package.json`, `yarn.lock`                  | modified  | devDep bumps only                                                                                                                                                                                                     |

**Known-broken points to fix during reconciliation:** (1) `BuzzvilPackage.kt` missing `ViewManager` import; (2) iOS `.mm` generated-header path is `BuzzvilViewSpec` but must be `BuzzvilSpec` (the library `name`; the committed `ios/Buzzvil.h` proves the umbrella is `<BuzzvilSpec/BuzzvilSpec.h>`).

**Naming decision (assumption — overridable at plan review):** rename the placeholder component `BuzzvilView` → **`BuzzvilNativeAdView`** for a clear domain model (`Buzzvil` module + `BuzzvilNativeAdView` component). Keep the codegen library `name: "BuzzvilSpec"` (shared with the module; renaming it would break `ios/Buzzvil.h`). Keep `javaPackageName: "com.buzzvil"`. The scaffold is uncommitted, so this is shaping new code, not churning committed code.

**Intended outcome:** a published-surface `BuzzvilNativeAdView` React component that renders a real Buzzvil native ad in a chosen inventory-size layout and emits load/click/impression/reward events, verified by on-device smoke test on both platforms.

### Codegen identity (target end state)

```jsonc
"codegenConfig": {
  "name": "BuzzvilSpec",            // unchanged — single library emits BOTH the module and the component
  "type": "all",
  "jsSrcsDir": "src",
  "android": { "javaPackageName": "com.buzzvil" },
  "ios": { "components": { "BuzzvilNativeAdView": { "className": "BuzzvilNativeAdView" } } }
}
```

- Generated iOS component headers live under `<react/renderer/components/BuzzvilSpec/…>`.
- Generated Android view-manager interfaces are `com.facebook.react.viewmanagers.BuzzvilNativeAdViewManagerInterface` / `…Delegate`.
- The native module (`Buzzvil` / `NativeBuzzvilSpec`) is untouched and coexists under the same library.

---

## File Structure

**Created (final names):**

- `src/BuzzvilNativeAdViewNativeComponent.ts` — codegen component spec (props + events). Source of truth.
- `src/BuzzvilNativeAdView.native.tsx` — native JS wrapper (friendly prop types, event-payload unwrapping, `layout` default).
- `src/BuzzvilNativeAdView.tsx` — web fallback (renders an inert `<View>`; never throws at import).
- `src/__tests__/BuzzvilNativeAdView.test.tsx` — jest for the wrapper mapping (the only unit-testable JS logic).
- `android/src/main/java/com/buzzvil/BuzzvilNativeAdView.kt` — host `FrameLayout` that inflates a layout, loads `BuzzNative`, binds, emits events.
- `android/src/main/java/com/buzzvil/BuzzvilNativeAdViewManager.kt` — `SimpleViewManager` + generated delegate; registers props + event constants.
- `android/src/main/res/layout/buzzvil_native_ad_card.xml` — vertical card layout (media on top).
- `android/src/main/res/layout/buzzvil_native_ad_banner.xml` — horizontal banner layout (no media).
- `ios/BuzzvilNativeAdView.h` / `ios/BuzzvilNativeAdView.mm` — `RCTViewComponentView` host.
- `ios/BuzzvilNativeAdShim.swift` — `@objc` Swift facade over Buzzvil's Swift-only builder/closure ad API (only if Task 3 spike requires it).

**Modified:**

- `package.json` — codegenConfig component entry (`BuzzvilView`→`BuzzvilNativeAdView`).
- `src/index.tsx` — export `BuzzvilNativeAdView` + ad types.
- `src/types.ts` — friendly ad types (`BuzzvilNativeAdLayout`, prop/event types).
- `android/.../BuzzvilPackage.kt` — register `BuzzvilNativeAdViewManager`; fix missing `ViewManager` import.
- `Buzzvil.podspec` — add the native-ad pod dep only if Task 3 shows it isn't already pulled in.
- `example/src/App.tsx` — add a smoke-test screen rendering the component.
- `docs/specs/buzzvil-sdk-api-mapping.md` — move Native ad from "Deferred" to "implemented"; document the layout-variant mapping.

**Deleted (renamed away):** the 7 `BuzzvilView*` scaffold files are renamed to `BuzzvilNativeAdView*`, not left alongside.

---

## A note on TDD scope (read before starting)

Real failing-test-first TDD applies cleanly only to the **JS wrapper** layer (jest with a mocked codegen component — mirrors the existing `src/__tests__/index.test.tsx`). Native Kotlin / Obj-C++ / Swift bridge code is **not** unit-testable here; its verification loop is **write → codegen → compile → manual on-device smoke**. The plan is honest about which loop each step uses. Do not invent "run X, see the ad" automated steps — actual ad rendering is only confirmable by the on-device smoke checklist (Tasks 4–6).

Verifiable layers, cheapest → most expensive: `yarn typecheck` / `yarn lint` / `yarn test` → codegen (`pod install` on iOS, the Gradle codegen task on Android) → native compile (`yarn turbo run build:android` / `build:ios`) → manual on-device smoke.

---

## Task 1: Reconcile the scaffold into a consistent, building **empty** `BuzzvilNativeAdView`

**Goal:** rename the placeholder `BuzzvilView` → `BuzzvilNativeAdView`, fix the two known-broken points, and get an empty/placeholder component (still just a colored box) to codegen + compile + render end-to-end on both platforms. No Buzzvil SDK yet. This de-risks the codegen/registration plumbing before any ad wiring.

**Files:**

- Create (by renaming): `src/BuzzvilNativeAdViewNativeComponent.ts`, `src/BuzzvilNativeAdView.tsx`, `src/BuzzvilNativeAdView.native.tsx`, `android/.../BuzzvilNativeAdView.kt`, `android/.../BuzzvilNativeAdViewManager.kt`, `ios/BuzzvilNativeAdView.h`, `ios/BuzzvilNativeAdView.mm`
- Modify: `package.json`, `src/index.tsx`, `android/.../BuzzvilPackage.kt`
- Delete: the 7 original `BuzzvilView*` files

- [ ] **Step 1: Create a feature branch**

```bash
cd /Users/dongminyu/Development/01_personal/react-native-buzzvil
git checkout -b feat/native-ad-fabric-component
```

- [ ] **Step 2: Rename the scaffold files (git mv where tracked; plain mv for untracked)**

```bash
# JS (untracked → plain move)
mv src/BuzzvilViewNativeComponent.ts src/BuzzvilNativeAdViewNativeComponent.ts
mv src/BuzzvilView.tsx               src/BuzzvilNativeAdView.tsx
mv src/BuzzvilView.native.tsx        src/BuzzvilNativeAdView.native.tsx
# Android
mv android/src/main/java/com/buzzvil/BuzzvilView.kt        android/src/main/java/com/buzzvil/BuzzvilNativeAdView.kt
mv android/src/main/java/com/buzzvil/BuzzvilViewManager.kt android/src/main/java/com/buzzvil/BuzzvilNativeAdViewManager.kt
# iOS
mv ios/BuzzvilView.h  ios/BuzzvilNativeAdView.h
mv ios/BuzzvilView.mm ios/BuzzvilNativeAdView.mm
```

- [ ] **Step 3: Update `codegenConfig` in `package.json`**

Replace the `ios.components` block so the component key + className become `BuzzvilNativeAdView` (leave `name`, `type`, `jsSrcsDir`, `android.javaPackageName` exactly as-is):

```jsonc
"ios": {
  "components": {
    "BuzzvilNativeAdView": { "className": "BuzzvilNativeAdView" }
  }
}
```

- [ ] **Step 4: Rewrite `src/BuzzvilNativeAdViewNativeComponent.ts` (still the placeholder `color` prop for now)**

Keep the spec minimal and building in this task; the real ad props land in Task 2. Only the component name string changes:

```ts
import {
  codegenNativeComponent,
  type ColorValue,
  type ViewProps,
} from 'react-native';

interface NativeProps extends ViewProps {
  color?: ColorValue;
}

export default codegenNativeComponent<NativeProps>('BuzzvilNativeAdView');
```

- [ ] **Step 5: Rewrite `src/BuzzvilNativeAdView.native.tsx` and `src/BuzzvilNativeAdView.tsx`**

`src/BuzzvilNativeAdView.native.tsx`:

```tsx
export { default as BuzzvilNativeAdView } from './BuzzvilNativeAdViewNativeComponent';
export * from './BuzzvilNativeAdViewNativeComponent';
```

`src/BuzzvilNativeAdView.tsx` (web fallback — inert, never throws at import; mirrors the "no-op render" analog of `buzzvil.tsx`):

```tsx
import { View, type ColorValue, type ViewProps } from 'react-native';

type Props = ViewProps & { color?: ColorValue };

export function BuzzvilNativeAdView({ color, style, ...rest }: Props) {
  return <View {...rest} style={[style, { backgroundColor: color }]} />;
}
```

- [ ] **Step 6: Update `src/index.tsx` export**

Change the added line to:

```tsx
export { BuzzvilNativeAdView } from './BuzzvilNativeAdView';
```

- [ ] **Step 7: Rewrite the Android view + manager with the new names**

`android/src/main/java/com/buzzvil/BuzzvilNativeAdView.kt`:

```kotlin
package com.buzzvil

import android.content.Context
import android.util.AttributeSet
import android.view.View

class BuzzvilNativeAdView : View {
  constructor(context: Context?) : super(context)
  constructor(context: Context?, attrs: AttributeSet?) : super(context, attrs)
  constructor(context: Context?, attrs: AttributeSet?, defStyleAttr: Int) :
    super(context, attrs, defStyleAttr)
}
```

`android/src/main/java/com/buzzvil/BuzzvilNativeAdViewManager.kt`:

```kotlin
package com.buzzvil

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.BuzzvilNativeAdViewManagerInterface
import com.facebook.react.viewmanagers.BuzzvilNativeAdViewManagerDelegate

@ReactModule(name = BuzzvilNativeAdViewManager.NAME)
class BuzzvilNativeAdViewManager : SimpleViewManager<BuzzvilNativeAdView>(),
  BuzzvilNativeAdViewManagerInterface<BuzzvilNativeAdView> {
  private val mDelegate: ViewManagerDelegate<BuzzvilNativeAdView> =
    BuzzvilNativeAdViewManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<BuzzvilNativeAdView> = mDelegate

  override fun getName(): String = NAME

  public override fun createViewInstance(context: ThemedReactContext): BuzzvilNativeAdView =
    BuzzvilNativeAdView(context)

  @ReactProp(name = "color")
  override fun setColor(view: BuzzvilNativeAdView?, color: Int?) {
    view?.setBackgroundColor(color ?: Color.TRANSPARENT)
  }

  companion object {
    const val NAME = "BuzzvilNativeAdView"
  }
}
```

- [ ] **Step 8: Fix `BuzzvilPackage.kt` — add the missing import and the new manager**

```kotlin
package com.buzzvil

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class BuzzvilPackage : BaseReactPackage() {
  override fun createViewManagers(
    reactContext: ReactApplicationContext,
  ): List<ViewManager<*, *>> = listOf(BuzzvilNativeAdViewManager())

  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == BuzzvilModule.NAME) BuzzvilModule(reactContext) else null
  }

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      BuzzvilModule.NAME to ReactModuleInfo(
        name = BuzzvilModule.NAME,
        className = BuzzvilModule.NAME,
        canOverrideExistingModule = false,
        needsEagerInit = false,
        isCxxModule = false,
        isTurboModule = true,
      )
    )
  }
}
```

- [ ] **Step 9: Rewrite iOS `.h`/`.mm` with new names AND fix the generated-header path to `BuzzvilSpec`**

`ios/BuzzvilNativeAdView.h`:

```objc
#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BuzzvilNativeAdView : RCTViewComponentView
@end

NS_ASSUME_NONNULL_END
```

`ios/BuzzvilNativeAdView.mm` (note `components/BuzzvilSpec/`, not `BuzzvilViewSpec`):

```objc
#import "BuzzvilNativeAdView.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/BuzzvilSpec/ComponentDescriptors.h>
#import <react/renderer/components/BuzzvilSpec/Props.h>
#import <react/renderer/components/BuzzvilSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

@implementation BuzzvilNativeAdView {
  UIView *_view;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<BuzzvilNativeAdViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const BuzzvilNativeAdViewProps>();
    _props = defaultProps;
    _view = [[UIView alloc] init];
    self.contentView = _view;
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<BuzzvilNativeAdViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<BuzzvilNativeAdViewProps const>(props);
  if (oldViewProps.color != newViewProps.color) {
    [_view setBackgroundColor:RCTUIColorFromSharedColor(newViewProps.color)];
  }
  [super updateProps:props oldProps:oldProps];
}

@end

Class<RCTComponentViewProtocol> BuzzvilNativeAdViewCls(void)
{
  return BuzzvilNativeAdView.class;
}
```

> Note: the `…Cls(void)` function + `RCTFabricComponentsPlugins.h` import is how the generated `RCTThirdPartyComponentsProvider` finds the class. If the stock scaffold did not include it and the component still registered via the codegenConfig entry, that's fine — keep whichever the working scaffold proved out in Step 12. Prefer the codegenConfig-driven auto-registration; only keep the explicit `…Cls` if registration fails.

- [ ] **Step 10: Verify JS layers (cheap gates)**

Run: `yarn typecheck && yarn lint && yarn test`
Expected: PASS. `tsc` resolves the renamed files; the existing module tests are untouched and green.

- [ ] **Step 11: Verify Android codegen + compile**

Run: `yarn turbo run build:android`
Expected: PASS. Codegen emits `BuzzvilNativeAdViewManagerInterface`/`Delegate`; `BuzzvilNativeAdViewManager` implements them; package compiles (the `ViewManager` import fix from Step 8 resolves the prior break).

- [ ] **Step 12: Verify iOS codegen + compile**

Run: `cd example/ios && bundle exec pod install && cd ../..` then `yarn turbo run build:ios`
Expected: PASS. `pod install` regenerates `components/BuzzvilSpec/*` headers; the `.mm` compiles against the corrected path; the component registers.

- [ ] **Step 13: Render the placeholder end-to-end in the example app (manual)**

Temporarily add to `example/src/App.tsx`: `<BuzzvilNativeAdView style={{ width: 200, height: 80 }} color="#FF0000" />`.
Run `yarn example ios` (and `yarn example android`). Expected: a red box renders. This proves the full Fabric pipeline (spec → codegen → native view → RN tree) before any SDK work. Revert the temporary edit after confirming.

- [ ] **Step 14: Commit**

```bash
git add -A
git commit -m "refactor: reconcile fabric-view scaffold into empty BuzzvilNativeAdView component"
```

---

## Task 2: Replace the placeholder spec with the real Native-ad props + events (TDD the JS wrapper)

**Goal:** swap the `color` prop for the ad API (`unitId`, `layout`, lifecycle events) and build the friendly JS wrapper. This is the one task with real failing-test-first TDD (jest on the wrapper). Codegen must accept the event payload types (validated at the end of this task).

**Files:**

- Modify: `src/BuzzvilNativeAdViewNativeComponent.ts`, `src/BuzzvilNativeAdView.native.tsx`, `src/BuzzvilNativeAdView.tsx`, `src/types.ts`, `src/index.tsx`
- Create: `src/__tests__/BuzzvilNativeAdView.test.tsx`

- [ ] **Step 1: Rewrite the codegen spec with ad props + direct events**

`src/BuzzvilNativeAdViewNativeComponent.ts`:

```ts
import { codegenNativeComponent, type ViewProps } from 'react-native';
import type {
  Double,
  DirectEventHandler,
} from 'react-native/Libraries/Types/CodegenTypes';

// Flat primitive payloads — codegen events cannot carry nested objects/enums.
type AdLoadedEvent = Readonly<{ width: Double; height: Double }>;
type AdFailedEvent = Readonly<{ code: string; message: string }>;
type RewardedEvent = Readonly<{ success: boolean }>;

export interface NativeProps extends ViewProps {
  unitId: string;
  // String-union default is legal for view props (unlike TurboModule method
  // params). Values are the inventory sizes from the layout-guide PDF.
  layout?: string; // WithDefault handled in the JS wrapper; codegen-validated string.
  onAdLoaded?: DirectEventHandler<AdLoadedEvent>;
  onAdFailed?: DirectEventHandler<AdFailedEvent>;
  onAdClicked?: DirectEventHandler<Readonly<{}>>;
  onImpressed?: DirectEventHandler<Readonly<{}>>;
  onRewarded?: DirectEventHandler<RewardedEvent>;
}

export default codegenNativeComponent<NativeProps>('BuzzvilNativeAdView');
```

> Codegen caveats to confirm at Step 6: (a) the `CodegenTypes` import path under RN 0.85 strict types — if `react-native/Libraries/Types/CodegenTypes` errors, use `import type { CodegenTypes } from 'react-native'` and `CodegenTypes.Double` / `CodegenTypes.DirectEventHandler`. (b) If codegen rejects empty `Readonly<{}>` event payloads, give `onAdClicked`/`onImpressed` a trivial field (e.g. `Readonly<{ ok: boolean }>`). (c) `layout` stays a plain `string` in the codegen spec to avoid enum-union friction; the friendly union + default live in the wrapper.

- [ ] **Step 2: Add friendly types to `src/types.ts`**

Append:

```ts
export type BuzzvilNativeAdLayout =
  | '320x50'
  | '320x100'
  | '320x130'
  | '300x250'
  | '320x480';

export interface BuzzvilNativeAdViewProps {
  unitId: string;
  layout?: BuzzvilNativeAdLayout;
  style?: import('react-native').StyleProp<import('react-native').ViewStyle>;
  onAdLoaded?: (e: { width: number; height: number }) => void;
  onAdFailed?: (e: { code: string; message: string }) => void;
  onAdClicked?: () => void;
  onImpressed?: () => void;
  onRewarded?: (e: { success: boolean }) => void;
}
```

- [ ] **Step 3: Write the failing wrapper test (pure-function, no renderer)**

This repo has **no** `react-test-renderer` / `@testing-library/react-native` dependency, and the existing `src/__tests__/index.test.tsx` tests wrapper _functions_ directly (not via rendering). Match that convention: the wrapper's logic (layout default + `nativeEvent` unwrapping) is extracted into a pure `toNativeProps()` function and tested directly — no renderer, no new dependency (respects the CLAUDE.md "justify new deps" rule).

`src/__tests__/BuzzvilNativeAdView.test.tsx`:

```tsx
import { jest, describe, it, expect } from '@jest/globals';

// The codegen component is a native-only import; mock it so the wrapper module
// loads under jest (mirrors the existing index.test.tsx NativeBuzzvil mock).
jest.mock('../BuzzvilNativeAdViewNativeComponent', () => ({
  __esModule: true,
  default: 'BuzzvilNativeAdView',
}));

import { toNativeProps } from '../BuzzvilNativeAdView.native';

describe('toNativeProps — friendly→native mapping', () => {
  it('defaults layout to 300x250 when omitted', () => {
    expect(toNativeProps({ unitId: 'u1' }).layout).toBe('300x250');
  });

  it('passes through an explicit layout', () => {
    expect(toNativeProps({ unitId: 'u1', layout: '320x50' }).layout).toBe(
      '320x50'
    );
  });

  it('unwraps onAdLoaded nativeEvent to friendly args', () => {
    const onAdLoaded = jest.fn();
    toNativeProps({ unitId: 'u1', onAdLoaded }).onAdLoaded?.({
      nativeEvent: { width: 300, height: 250 },
    } as any);
    expect(onAdLoaded).toHaveBeenCalledWith({ width: 300, height: 250 });
  });

  it('unwraps onRewarded nativeEvent', () => {
    const onRewarded = jest.fn();
    toNativeProps({ unitId: 'u1', onRewarded }).onRewarded?.({
      nativeEvent: { success: true },
    } as any);
    expect(onRewarded).toHaveBeenCalledWith({ success: true });
  });

  it('leaves omitted handlers undefined', () => {
    expect(toNativeProps({ unitId: 'u1' }).onAdClicked).toBeUndefined();
  });
});
```

- [ ] **Step 4: Run the test to confirm it fails**

Run: `yarn test src/__tests__/BuzzvilNativeAdView.test.tsx`
Expected: FAIL — `toNativeProps` is not exported yet (the wrapper still just re-exports the raw codegen component from Task 1).

- [ ] **Step 5: Implement the wrapper (pure `toNativeProps` + component) to pass**

`src/BuzzvilNativeAdView.native.tsx`:

```tsx
import NativeComponent from './BuzzvilNativeAdViewNativeComponent';
import type { BuzzvilNativeAdViewProps } from './types';

const DEFAULT_LAYOUT = '300x250';

// Pure, unit-testable: friendly props → raw native-component props
// (applies the layout default and unwraps `e.nativeEvent`).
export function toNativeProps(props: BuzzvilNativeAdViewProps) {
  const {
    layout,
    onAdLoaded,
    onAdFailed,
    onAdClicked,
    onImpressed,
    onRewarded,
    ...rest
  } = props;
  return {
    ...rest,
    layout: layout ?? DEFAULT_LAYOUT,
    onAdLoaded: onAdLoaded
      ? (e: { nativeEvent: { width: number; height: number } }) =>
          onAdLoaded(e.nativeEvent)
      : undefined,
    onAdFailed: onAdFailed
      ? (e: { nativeEvent: { code: string; message: string } }) =>
          onAdFailed(e.nativeEvent)
      : undefined,
    onAdClicked: onAdClicked ? () => onAdClicked() : undefined,
    onImpressed: onImpressed ? () => onImpressed() : undefined,
    onRewarded: onRewarded
      ? (e: { nativeEvent: { success: boolean } }) => onRewarded(e.nativeEvent)
      : undefined,
  };
}

export function BuzzvilNativeAdView(props: BuzzvilNativeAdViewProps) {
  return <NativeComponent {...(toNativeProps(props) as any)} />;
}
```

Update `src/BuzzvilNativeAdView.tsx` (web) to accept the new props shape and render an inert `<View>` (drop the `color` prop):

```tsx
import { View } from 'react-native';
import type { BuzzvilNativeAdViewProps } from './types';

export function BuzzvilNativeAdView({ style }: BuzzvilNativeAdViewProps) {
  // Buzzvil native ads are not available on web; render nothing visible.
  return <View style={style} />;
}
```

- [ ] **Step 6: Run the test to confirm it passes; then run JS gates**

Run: `yarn test src/__tests__/BuzzvilNativeAdView.test.tsx` → PASS.
Then: `yarn typecheck && yarn lint && yarn test` → PASS.

- [ ] **Step 7: Update the Android view + manager to ad-prop STUBS (keep `build:android` green)**

The regenerated `BuzzvilNativeAdViewManagerInterface` now requires `setUnitId`/`setLayout` and no longer has `setColor` — so the Task 1 manager won't compile. Replace the prop-setters with **store-only stubs** (no SDK calls yet; Task 4 fills the behavior). Convert the view to a `FrameLayout` that just stores the props.

`android/.../BuzzvilNativeAdView.kt`:

```kotlin
package com.buzzvil

import android.widget.FrameLayout
import com.facebook.react.uimanager.ThemedReactContext

class BuzzvilNativeAdView(context: ThemedReactContext) : FrameLayout(context) {
  // Plain private fields + explicit setters. Do NOT use `var x; private set` —
  // its generated `setX(String)` would clash with the `fun setX(String)` below
  // (same JVM signature → "platform declaration clash").
  private var unitId: String? = null
  private var layoutVariant: String = "300x250"

  fun setUnitId(id: String) { unitId = id }            // Task 4: trigger load
  fun setLayoutVariant(v: String) { layoutVariant = v } // Task 4/6: pick layout
}
```

`android/.../BuzzvilNativeAdViewManager.kt` — replace the `setColor` prop with the two ad props (keep the delegate/`getName`/`createViewInstance` from Task 1):

```kotlin
@ReactProp(name = "unitId")
override fun setUnitId(view: BuzzvilNativeAdView, value: String?) {
  view.setUnitId(value ?: "")
}

@ReactProp(name = "layout")
override fun setLayout(view: BuzzvilNativeAdView, value: String?) {
  view.setLayoutVariant(value ?: "300x250")
}
```

> Match `setUnitId`/`setLayout` signatures to what codegen emits in `BuzzvilNativeAdViewManagerInterface` (build errors will state the expected types). Event-constant registration + `onDropViewInstance` come in Task 4.

- [ ] **Step 8: Update the iOS `.mm` to an ad-prop STUB (keep `build:ios` green)**

Replace the `color` logic in `BuzzvilNativeAdView.mm`'s `updateProps` with reading `unitId`/`layout` into ivars (no rendering yet; Task 5 adds the shim + SDK):

```objc
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newP = *std::static_pointer_cast<BuzzvilNativeAdViewProps const>(props);
  _unitId = newP.unitId;     // std::string ivar; Task 5 acts on change
  _layout = newP.layout;     // std::string ivar
  [super updateProps:props oldProps:oldProps];
}
```

Drop the now-unused `RCTUIColorFromSharedColor`/`<React/RCTConversions.h>` color usage from Task 1 (Task 5 re-adds `RCTConversions.h` for `RCTNSStringFromString`). Keep the empty `_view` container so the component still renders a (blank) box.

- [ ] **Step 9: Update `src/index.tsx` to export ad types**

```tsx
export { BuzzvilNativeAdView } from './BuzzvilNativeAdView';
export type { BuzzvilNativeAdLayout, BuzzvilNativeAdViewProps } from './types';
```

- [ ] **Step 10: Validate codegen + compile on BOTH platforms (green-to-green gate)**

Run: `cd example/ios && bundle exec pod install && cd ../..` then `yarn turbo run build:android build:ios`
Expected: BOTH compile. Codegen emits the iOS `BuzzvilNativeAdViewEventEmitter` (`onAdLoaded`/`onAdFailed`/`onRewarded` structs) and the Android manager interface with `setUnitId`/`setLayout`; the stub setters satisfy them. If an event payload type is rejected at codegen, apply the Step-1 caveats and re-run. **This task ends fully green — no orphaned `color` references remain.**

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: define BuzzvilNativeAdView ad props/events with native prop stubs"
```

---

## Task 3: iOS Swift-interop spike (gates all iOS SDK wiring)

**Goal:** determine whether Buzzvil's Native-ad classes are usable directly from Obj-C++ (like the existing `BuzzBenefit*` classes in `Buzzvil.mm`) or whether a thin `@objc` Swift shim is required. Decide before writing iOS ad code.

**Files:** none yet (investigation; produces a decision recorded in `docs/specs/buzzvil-sdk-api-mapping.md`).

- [ ] **Step 1: Ensure pods are installed so the generated Swift headers exist**

Run: `cd example/ios && bundle exec pod install && cd ../..`

- [ ] **Step 2: Grep the generated `-Swift.h` for the ad classes**

```bash
find example/ios/Pods -name '*-Swift.h' \( -path '*BuzzAdBenefit*' -o -path '*BuzzvilSDK*' \) -exec \
  grep -nE 'BuzzNative|BuzzNativeAd|BuzzNativeAdView|BuzzNativeViewBinder|BuzzMediaView|BuzzDefaultCtaView' {} +
```

Expected: lists `@interface`/`@objc` declarations if the classes are Obj-C-exposed.

- [ ] **Step 3: Identify which pod vends `BuzzNative`**

```bash
find example/ios/Pods -path '*BuzzAdBenefit*' -name '*.h' | head -50
grep -rEl 'class BuzzNative\b|@objc.*BuzzNative' example/ios/Pods 2>/dev/null | head
```

Confirm whether `BuzzNative` is in `BuzzAdBenefitSDK` (already a podspec dep) or a separate pod/subspec.

- [ ] **Step 4: Record the decision**

- **Outcome A — classes appear in `-Swift.h` with usable initializers/setters:** implement directly in `BuzzvilNativeAdView.mm` (no shim). Cheapest. Risk: the Swift `BuzzNativeViewBinder.Builder` fluent chain and the trailing-closure `subscribeAdEvents`/`load` may not bridge cleanly to Obj-C — if any one doesn't, fall back to the shim for just that part.
- **Outcome B — classes absent or builder/closure APIs unusable from Obj-C (the likely case):** add `ios/BuzzvilNativeAdShim.swift` (Task 5) as the `@objc` facade.

Write the chosen outcome + the confirmed pod name into `docs/specs/buzzvil-sdk-api-mapping.md` (a short "iOS native-ad interop" subsection). No commit needed if only investigation; commit the doc note with Task 5.

---

## Task 4: Wire the Android Native ad (card layout first)

**Goal:** make `BuzzvilNativeAdView` load and render a real Buzzvil native ad on Android using the `300x250` card layout, emitting events. Verification loop: compile → on-device smoke.

**Verified Android SDK shape (from the resolved `buzzad-benefit-base` 6.7.x AAR; transitive via `buzzvil-sdk` — no new Gradle dep):**

- `com.buzzvil.buzzbenefit.buzznative.BuzzNative(unitId: String)` with `load(onSuccess: (BuzzNativeAd) -> Unit, onFailure: (BuzzAdError) -> Unit)`; `setAdEventsListener(BuzzNativeAdEventsListener)` and `setRefreshEventsListener(...)` are **setters**.
- `BuzzNativeViewBinder.Builder().buzzNativeAdView(BuzzNativeAdView).buzzMediaView(BuzzMediaView).titleTextView(TextView).descriptionTextView(TextView).iconImageView(ImageView).buzzCtaView(BuzzCtaView).build()` then `binder.bind(buzzNativeAd)`.
- View classes for XML: `com.buzzvil.buzzbenefit.buzznative.BuzzNativeAdView`, `com.buzzvil.buzzbenefit.buzznative.BuzzMediaView`, `com.buzzvil.buzzbenefit.DefaultBuzzCtaView` (extends `BuzzCtaView`).
- `BuzzNativeAdEventsListener`: `onImpressed`, `onClicked`, `onRewardRequested`, `onParticipated`, `onRewarded(ad, BuzzRewardResult)`.

**Files:**

- Rewrite: `android/.../BuzzvilNativeAdView.kt`, `android/.../BuzzvilNativeAdViewManager.kt`
- Create: `android/src/main/res/layout/buzzvil_native_ad_card.xml`

- [ ] **Step 1: Create the card layout XML**

`android/src/main/res/layout/buzzvil_native_ad_card.xml` (IDs must match the `findViewById` calls in Step 2):

```xml
<?xml version="1.0" encoding="utf-8"?>
<com.buzzvil.buzzbenefit.buzznative.BuzzNativeAdView
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/buzz_ad_view"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical">

  <com.buzzvil.buzzbenefit.buzznative.BuzzMediaView
      android:id="@+id/buzz_media"
      android:layout_width="match_parent"
      android:layout_height="0dp" />
  <ImageView android:id="@+id/buzz_icon"
      android:layout_width="36dp" android:layout_height="36dp" />
  <TextView android:id="@+id/buzz_title"
      android:layout_width="wrap_content" android:layout_height="wrap_content" />
  <TextView android:id="@+id/buzz_desc"
      android:layout_width="wrap_content" android:layout_height="wrap_content" />
  <com.buzzvil.buzzbenefit.DefaultBuzzCtaView
      android:id="@+id/buzz_cta"
      android:layout_width="wrap_content" android:layout_height="wrap_content" />
</com.buzzvil.buzzbenefit.buzznative.BuzzNativeAdView>
```

> The exact root/child arrangement should follow the layout-guide PDF; the structure above is the minimal valid binder set. Adjust paddings/sizes to the PDF in Task 6.

- [ ] **Step 2: Rewrite `BuzzvilNativeAdView.kt` as the host FrameLayout**

```kotlin
package com.buzzvil

import android.view.LayoutInflater
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.buzzvil.buzzbenefit.DefaultBuzzCtaView
import com.buzzvil.buzzbenefit.buzznative.BuzzMediaView
import com.buzzvil.buzzbenefit.buzznative.BuzzNative
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeAd
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeAdEventsListener
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeAdView as SdkNativeAdView
import com.buzzvil.buzzbenefit.buzznative.BuzzNativeViewBinder
import com.buzzvil.buzzbenefit.buzznative.BuzzRewardResult

class BuzzvilNativeAdView(context: ThemedReactContext) : FrameLayout(context) {
  private var unitId: String? = null
  private var layoutVariant: String = "300x250"
  private var buzzNative: BuzzNative? = null
  private var binder: BuzzNativeViewBinder? = null
  private var loaded = false

  fun setUnitId(id: String) { unitId = id; loadIfReady() }
  fun setLayoutVariant(v: String) { layoutVariant = v }

  override fun onAttachedToWindow() { super.onAttachedToWindow(); loadIfReady() }

  private fun layoutResFor(variant: String): Int = when (variant) {
    "320x50", "320x100", "320x130" -> R.layout.buzzvil_native_ad_banner
    else -> R.layout.buzzvil_native_ad_card // 300x250, 320x480
  }

  private fun loadIfReady() {
    val id = unitId ?: return
    if (loaded || !isAttachedToWindow) return
    loaded = true

    LayoutInflater.from(context).inflate(layoutResFor(layoutVariant), this, true)
    val adView = findViewById<SdkNativeAdView>(R.id.buzz_ad_view)
    val media = findViewById<BuzzMediaView>(R.id.buzz_media)
    val icon = findViewById<ImageView>(R.id.buzz_icon)
    val title = findViewById<TextView>(R.id.buzz_title)
    val desc = findViewById<TextView>(R.id.buzz_desc)
    val cta = findViewById<DefaultBuzzCtaView>(R.id.buzz_cta)

    val native = BuzzNative(id)
    buzzNative = native
    native.setAdEventsListener(object : BuzzNativeAdEventsListener {
      override fun onImpressed(ad: BuzzNativeAd) = emit("topImpressed", Arguments.createMap())
      override fun onClicked(ad: BuzzNativeAd) = emit("topAdClicked", Arguments.createMap())
      override fun onRewardRequested(ad: BuzzNativeAd) {}
      override fun onParticipated(ad: BuzzNativeAd) {}
      override fun onRewarded(ad: BuzzNativeAd, result: BuzzRewardResult) =
        emit("topRewarded", Arguments.createMap().apply {
          putBoolean("success", result == BuzzRewardResult.SUCCESS)
        })
    })
    native.load(
      onSuccess = { ad ->
        binder = BuzzNativeViewBinder.Builder()
          .buzzNativeAdView(adView)
          .buzzMediaView(media)
          .titleTextView(title)
          .descriptionTextView(desc)
          .iconImageView(icon)
          .buzzCtaView(cta)
          .build()
        binder?.bind(ad)
        emit("topAdLoaded", Arguments.createMap().apply {
          putDouble("width", width.toDouble())
          putDouble("height", height.toDouble())
        })
      },
      onFailure = { err ->
        emit("topAdFailed", Arguments.createMap().apply {
          putString("code", err.toString())
          putString("message", err.toString())
        })
      },
    )
  }

  private fun emit(eventName: String, payload: WritableMap) {
    val reactContext = context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id) ?: return
    dispatcher.dispatchEvent(BuzzvilAdEvent(surfaceId, id, eventName, payload))
  }

  // Named event subclass (cleaner than an anonymous `Event<Event<*>>`; the
  // self-referential generic bound `Event<T : Event<T>>` is satisfied by name).
  private class BuzzvilAdEvent(
    surfaceId: Int,
    viewTag: Int,
    private val name: String,
    private val payload: WritableMap,
  ) : Event<BuzzvilAdEvent>(surfaceId, viewTag) {
    override fun getEventName() = name
    override fun getEventData() = payload
  }

  fun cleanup() {
    binder = null // see Step 3: confirm a BuzzNativeViewBinder unbind/destroy method via javap
    buzzNative = null
    loaded = false
    removeAllViews()
  }
}
```

> Impl-time checks: confirm `BuzzNative.load` lambda threads (marshal `bind` to UI thread with `UiThreadUtil.runOnUiThread {}` if callbacks are off-main); confirm whether `BuzzNativeViewBinder` exposes an `unbind()`/`destroy()` (iOS has one) and call it in `cleanup()` if present; confirm `BuzzAdError` accessor for a stable code (`err.toString()` is a placeholder).

- [ ] **Step 3: Add the manager props + event constants + cleanup**

Replace `BuzzvilNativeAdViewManager.kt`'s body so it sets the real props, registers event names, and cleans up on drop:

```kotlin
@ReactProp(name = "unitId")
override fun setUnitId(view: BuzzvilNativeAdView, value: String?) {
  view.setUnitId(value ?: "")
}

@ReactProp(name = "layout")
override fun setLayout(view: BuzzvilNativeAdView, value: String?) {
  view.setLayoutVariant(value ?: "300x250")
}

override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> = mutableMapOf(
  "topAdLoaded" to mapOf("registrationName" to "onAdLoaded"),
  "topAdFailed" to mapOf("registrationName" to "onAdFailed"),
  "topAdClicked" to mapOf("registrationName" to "onAdClicked"),
  "topImpressed" to mapOf("registrationName" to "onImpressed"),
  "topRewarded" to mapOf("registrationName" to "onRewarded"),
)

override fun onDropViewInstance(view: BuzzvilNativeAdView) {
  view.cleanup()
  super.onDropViewInstance(view)
}
```

> The generated `BuzzvilNativeAdViewManagerInterface` declares `setUnitId`/`setLayout` from the spec props — match those signatures exactly (codegen will tell you the expected types).

- [ ] **Step 4: Compile**

Run: `yarn turbo run build:android`
Expected: PASS (Kotlin compiles against the resolved Buzzvil AAR).

- [ ] **Step 5: On-device smoke test (manual — requires real unit ID + logged-in user)**

Add a real `unitId` to the example screen (Task 6 builds the screen; for now hardcode one). With a logged-in user (call `login(...)` first), run `yarn example android` on a device/emulator. Smoke checklist:

- the `300x250` card fills its box;
- `onAdLoaded` fires with a sane size;
- tapping the ad fires `onAdClicked` and opens the landing;
- `onImpressed` fires when visible.

Record results in the PR description. Not CI-verifiable.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(android): render Buzzvil native ad via Fabric component (card layout)"
```

---

## Task 5: Wire the iOS Native ad (shim per Task 3 decision)

**Goal:** render the real Buzzvil native ad on iOS, hosting Buzzvil's Swift `BuzzNativeAdView` inside the `RCTViewComponentView`, emitting events via the generated C++ event emitter. Verification loop: compile → on-device smoke.

**Verified iOS SDK shape (docs):** `BuzzNative(unitId:)`, `.load(onSuccess: (BuzzNativeAd)->Void, onFailure: (NSError)->Void)`; binder `BuzzNativeViewBinder.Builder().nativeAdView(_).mediaView(_).iconImageView(_).titleLabel(_).descriptionLabel(_).ctaView(_).build()` then `.bind(native)` / `.unbind()`; `native.subscribeAdEvents(onImpressed:onClicked:onRewardRequested:onRewarded:onParticipated:)`. View classes (`UIView`): `BuzzNativeAdView`, `BuzzMediaView`, `BuzzDefaultCtaView`.

**Files:**

- Create (if Task 3 = Outcome B): `ios/BuzzvilNativeAdShim.swift`
- Rewrite: `ios/BuzzvilNativeAdView.mm`
- Maybe modify: `Buzzvil.podspec`

- [ ] **Step 1 (Outcome B): Create the `@objc` Swift shim**

`ios/BuzzvilNativeAdShim.swift` — hides the Swift builder/closure API behind an `@objc` facade. The shim builds the SDK subviews and reports them so the `.mm` only deals with `UIView*` and blocks:

```swift
import UIKit
import BuzzAdBenefitSDK // confirm the module from Task 3 Step 3

@objc(BuzzvilNativeAdShim)
public final class BuzzvilNativeAdShim: NSObject {
  private var native: BuzzNative?
  private var binder: BuzzNativeViewBinder?

  @objc public let container = BuzzNativeAdView()
  @objc public var onAdLoaded: ((CGFloat, CGFloat) -> Void)?
  @objc public var onAdFailed: ((String, String) -> Void)?
  @objc public var onAdClicked: (() -> Void)?
  @objc public var onImpressed: (() -> Void)?
  @objc public var onRewarded: ((Bool) -> Void)?

  @objc public func load(unitId: String) {
    let media = BuzzMediaView()
    let icon = UIImageView()
    let title = UILabel()
    let desc = UILabel()
    let cta = BuzzDefaultCtaView()
    // Lay out media/icon/title/desc/cta inside `container` per the layout variant
    // (programmatic Auto Layout; Task 6 refines per inventory size).

    let n = BuzzNative(unitId: unitId)
    native = n
    n.subscribeAdEvents(
      onImpressed: { [weak self] _ in self?.onImpressed?() },
      onClicked: { [weak self] _ in self?.onAdClicked?() },
      onRewardRequested: { _ in },
      onRewarded: { [weak self] _, _ in self?.onRewarded?(true) },
      onParticipated: { _ in })
    n.load(onSuccess: { [weak self] ad in
      guard let self else { return }
      let b = BuzzNativeViewBinder.Builder()
        .nativeAdView(self.container).mediaView(media).iconImageView(icon)
        .titleLabel(title).descriptionLabel(desc).ctaView(cta).build()
      self.binder = b
      b.bind(ad)
      self.onAdLoaded?(self.container.bounds.width, self.container.bounds.height)
    }, onFailure: { [weak self] err in
      let ns = err as NSError
      self?.onAdFailed?("\(ns.code)", ns.localizedDescription)
    })
  }

  @objc public func unbind() { binder?.unbind(); binder = nil; native = nil }
}
```

> If Task 3 = Outcome A, skip the shim and inline these calls in the `.mm` (only viable if the Swift builder chain + closures bridge to Obj-C). Confirm the exact builder method names against the generated `-Swift.h`; doc names (`nativeAdView`/`mediaView`/…) may differ slightly when bridged.

- [ ] **Step 2: Rewrite `BuzzvilNativeAdView.mm` to host the shim + emit events**

```objc
#import "BuzzvilNativeAdView.h"
#import <React/RCTConversions.h> // RCTNSStringFromString
#import <react/renderer/components/BuzzvilSpec/ComponentDescriptors.h>
#import <react/renderer/components/BuzzvilSpec/EventEmitters.h>
#import <react/renderer/components/BuzzvilSpec/Props.h>
#import <react/renderer/components/BuzzvilSpec/RCTComponentViewHelpers.h>
#import "RCTFabricComponentsPlugins.h"
#import <Buzzvil/Buzzvil-Swift.h> // generated header for BuzzvilNativeAdShim

using namespace facebook::react;

@implementation BuzzvilNativeAdView {
  BuzzvilNativeAdShim *_shim;
  std::string _loadedUnitId;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<BuzzvilNativeAdViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const BuzzvilNativeAdViewProps>();
    _props = defaultProps;
    _shim = [BuzzvilNativeAdShim new];
    self.contentView = _shim.container;
    __weak __typeof(self) weakSelf = self;
    _shim.onAdLoaded = ^(CGFloat w, CGFloat h) { [weakSelf emitLoaded:w height:h]; };
    _shim.onAdFailed = ^(NSString *c, NSString *m) { [weakSelf emitFailed:c message:m]; };
    _shim.onAdClicked = ^{ [weakSelf emitClicked]; };
    _shim.onImpressed = ^{ [weakSelf emitImpressed]; };
    _shim.onRewarded = ^(BOOL s) { [weakSelf emitRewarded:s]; };
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &newP = *std::static_pointer_cast<BuzzvilNativeAdViewProps const>(props);
  if (!newP.unitId.empty() && newP.unitId != _loadedUnitId) {
    _loadedUnitId = newP.unitId;
    [_shim load:RCTNSStringFromString(newP.unitId)];
  }
  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle { [_shim unbind]; _loadedUnitId.clear(); [super prepareForRecycle]; }

- (const BuzzvilNativeAdViewEventEmitter &)emitter {
  return static_cast<const BuzzvilNativeAdViewEventEmitter &>(*_eventEmitter);
}
- (void)emitLoaded:(CGFloat)w height:(CGFloat)h {
  if (_eventEmitter) [self emitter].onAdLoaded({(double)w, (double)h});
}
- (void)emitFailed:(NSString *)c message:(NSString *)m {
  if (_eventEmitter) [self emitter].onAdFailed({std::string(c.UTF8String), std::string(m.UTF8String)});
}
- (void)emitClicked { if (_eventEmitter) [self emitter].onAdClicked({}); }
- (void)emitImpressed { if (_eventEmitter) [self emitter].onImpressed({}); }
- (void)emitRewarded:(BOOL)s { if (_eventEmitter) [self emitter].onRewarded({(bool)s}); }

@end

Class<RCTComponentViewProtocol> BuzzvilNativeAdViewCls(void) { return BuzzvilNativeAdView.class; }
```

> The generated emitter struct/field names (`onAdLoaded`, `OnAdLoaded{width,height}`, etc.) come from the Task 2 spec — match them exactly to what codegen produced under `EventEmitters.h`.

- [ ] **Step 3: Confirm the podspec dep + Swift module setup**

If Task 3 showed `BuzzNative` lives in a pod not already declared, add it to `Buzzvil.podspec` (`s.dependency "…", "~> 6.7.5"`). The podspec already globs `ios/**/*.{h,m,mm,swift,cpp}`, so the `.swift` shim compiles into the `Buzzvil` pod and its `@objc` facade is exposed via the generated `<Buzzvil/Buzzvil-Swift.h>`.

- [ ] **Step 4: Codegen + compile**

Run: `cd example/ios && bundle exec pod install && cd ../..` then `yarn turbo run build:ios`
Expected: PASS — the `.mm` finds `EventEmitters.h`, the shim header resolves, the SDK links.

- [ ] **Step 5: On-device smoke test (manual)**

Same checklist as Task 4 Step 5, on an iOS device/simulator (`yarn example ios`) with a logged-in user and a real `unitId`. Confirm ad fills the box, events fire, tap opens the landing.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(ios): render Buzzvil native ad via Fabric component + Swift shim"
```

---

## Task 6: Layout variants, example smoke screen, and docs

**Goal:** support the inventory-size layout variants from the PDF (back the 5 sizes with 2 native families: banner / card), wire a proper example screen for smoke testing, and update the spec doc.

**Files:**

- Create: `android/src/main/res/layout/buzzvil_native_ad_banner.xml`
- Modify: `android/.../BuzzvilNativeAdView.kt` (banner already mapped in `layoutResFor`), `ios/BuzzvilNativeAdShim.swift` (per-variant layout), `example/src/App.tsx`, `docs/specs/buzzvil-sdk-api-mapping.md`

- [ ] **Step 1: Add the Android banner layout XML**

`android/src/main/res/layout/buzzvil_native_ad_banner.xml` — horizontal `icon + title/desc + CTA`, no media view; fixed heights per `320x50/100/130`. Same SDK view tags + IDs as the card (omit `buzz_media` or keep it `gone`). Confirm against the PDF arrangement.

- [ ] **Step 2: Map each size to a family + fixed height (both platforms)**

Android `layoutResFor` already routes `320x50/100/130` → banner, else card. Add a fixed-height application per exact size (e.g. set `layoutParams.height` from a `dp(size)` lookup). iOS shim: pick the programmatic layout (banner vs card) from a `layout` string passed via a new `@objc func setLayout(_:)` and apply the matching Auto Layout + intrinsic size.

> Pass the `layout` prop into the iOS shim: add `setLayoutVariant` handling in `updateProps` (read `newP.layout`) before `load`.

- [ ] **Step 3: Build the example smoke screen**

Rewrite `example/src/App.tsx` to: `initialize(APP_ID)` → `login({ userId: 'smoke-test' })` → render a `<BuzzvilNativeAdView unitId={UNIT_ID} layout={selected} onAdLoaded={…} onAdFailed={…} onAdClicked={…} onRewarded={…} />` with a size picker and an on-screen event log. Use real `APP_ID`/`UNIT_ID` constants (the user supplies them; leave clearly-marked placeholders).

- [ ] **Step 4: Verify all JS gates + both native builds**

Run: `yarn typecheck && yarn lint && yarn test && yarn turbo run build:android build:ios`
Expected: all PASS.

- [ ] **Step 5: On-device smoke for each variant**

Run `yarn example ios` and `yarn example android`; for each `layout` value, confirm the ad fits the inventory size and visually matches the PDF guide. Record results.

- [ ] **Step 6: Update the spec doc**

In `docs/specs/buzzvil-sdk-api-mapping.md`: move Native ad out of "Deferred", add a "Native ad (Fabric component)" section documenting the `BuzzvilNativeAdView` props/events, the size→family layout mapping, and the iOS interop decision from Task 3.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: layout variants, example smoke screen, and native-ad spec docs"
```

---

## Task 7: Final verification & integration

- [ ] **Step 1: Full gate run**

Run: `yarn typecheck && yarn lint && yarn test && yarn turbo run build:android build:ios`
Expected: all PASS. Confirm the existing module tests (`src/__tests__/index.test.tsx`) and the new component test both green.

- [ ] **Step 2: Confirm the published surface**

Verify `src/index.tsx` exports `BuzzvilNativeAdView` + types, and `yarn prepare` (bob build) produces `lib/` without errors: `yarn prepare`.

- [ ] **Step 3: Final on-device smoke pass**

Run the example on both platforms one more time end-to-end (init → login → render each layout → tap → reward). Capture screenshots for the PR.

- [ ] **Step 4: Open the PR**

```bash
git push -u origin feat/native-ad-fabric-component
gh pr create --fill
```

Include in the PR body: the smoke-test checklist results, the Task 3 interop decision, and the size→layout mapping.

---

## Verification Summary (end-to-end)

| Layer                       | Command                                               | Confirms                                                                                                        |
| --------------------------- | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Types                       | `yarn typecheck`                                      | spec + wrappers compile under strict TS                                                                         |
| Lint                        | `yarn lint`                                           | flat-config style                                                                                               |
| JS unit                     | `yarn test`                                           | wrapper layout-default + event unwrapping (Task 2)                                                              |
| Codegen (iOS)               | `cd example/ios && bundle exec pod install`           | spec is codegen-valid; event payload types accepted                                                             |
| Codegen + compile (Android) | `yarn turbo run build:android`                        | ViewManager/delegate + Kotlin against the AAR                                                                   |
| Compile (iOS)               | `yarn turbo run build:ios`                            | `.mm` + Swift shim link against the SDK                                                                         |
| Package                     | `yarn prepare`                                        | `lib/` builds for publish                                                                                       |
| **Ad rendering**            | **manual on-device** (`yarn example ios` / `android`) | **the only way to confirm a real ad renders + events fire** — needs device + real app/unit IDs + logged-in user |

## Risks (ranked)

1. **iOS Swift interop** — gating unknown; resolved by the Task 3 spike. Shim is the safe default (~1 file).
2. **Fabric prop-settling / load timing** — load guarded by `loadIfReady()` (Android, attach-triggered) / unitId-change detection (iOS) to avoid double-loads or stale-unitId loads.
3. **View recycling cleanup** — missing `unbind()` on `onDropViewInstance`/`prepareForRecycle` leaks the binder and corrupts impression tracking in reused list cells.
4. **Event payload codegen constraints** — must stay flat primitives; caught at Task 2 Step 8.
5. **Layout fidelity vs the PDF** — visual-only; iterate on device in Task 6.
