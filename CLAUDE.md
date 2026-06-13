# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A React Native (New Architecture) package (`react-native-buzzvil-ad`) that wraps Buzzvil's **BuzzBenefit v6** native SDKs so they can be used from a React Native app:

- Android: https://docs.buzzvil.com/docs/buzzbenefit-android/v6/introduction
- iOS: https://docs.buzzvil.com/docs/buzzbenefit-ios/v6/introduction

It exposes **two native surfaces** (see Architecture below):

1. A **TurboModule** `Buzzvil` — the session/offerwall API (`initialize`, `login`, `logout`, `isLoggedIn`, `showBenefitHub`).
2. A **Fabric view** `BuzzvilNativeAdView` — an in-feed native ad component (`create-react-native-library` type is `fabric-view`).

> Watch the names — four distinct identifiers that look alike: npm package `react-native-buzzvil-ad`, native module + iOS pod `Buzzvil`, codegen library `BuzzvilSpec`, git repo `react-native-buzzvil`.
> The `chore/rename-package` work renamed only the npm package; the native names are unchanged.

## Commands

Yarn 4 (Berry) workspaces; **do not use npm**. Node version is pinned in `.nvmrc` (v24.13.0).

```sh
yarn                      # install all workspaces
yarn typecheck            # tsc (no emit)
yarn lint                 # eslint; add --fix to autofix
yarn test                 # jest (run a single file: yarn test src/__tests__/index.test.tsx)
yarn prepare              # bob build → produces lib/ (ESM module + TS declarations)
yarn clean                # remove all build output

yarn example start        # Metro for the example app
yarn example android      # run example on Android
yarn example ios          # run example on iOS (pods auto-install)
yarn example web          # run example on web (react-native-web + vite)
```

Native builds are driven through Turbo (mirrors CI):

```sh
yarn turbo run build:android   # builds the example Android app
yarn turbo run build:ios       # builds the example iOS app (needs `bundle exec pod install` in example/ios first)
```

CI (`.github/workflows/ci.yml`) runs, as separate jobs: `lint` (lint + typecheck), `test`, `build-library` (`yarn prepare`), `build-android`, `build-ios`, `build-web`. All must pass.

## Architecture: how the bridges fit together

This is the New Architecture (Fabric/TurboModules) — codegen generates the native interface from the TS spec, so the **TS spec is the source of truth**.
There are two independent bridges; each has a JS spec, a Kotlin impl, an Obj-C++/Swift impl, and a `.tsx`/`.native.tsx` web-vs-native wrapper split (`.native.tsx` calls native, `.tsx` is the web fallback).
Both are registered by `BuzzvilPackage.kt` on Android (`getModule` for the TurboModule, `createViewManagers` for the Fabric view).

### 1. TurboModule `Buzzvil` — session / offerwall API

- **`src/NativeBuzzvil.ts`** — the codegen spec. `TurboModuleRegistry.getEnforcing<Spec>('Buzzvil')` binds to the native module named `Buzzvil`.
- **`src/buzzvil.native.tsx`** (+ `buzzvil.tsx` web fallback) — friendly JS wrapper; re-exported from `src/index.tsx`. Keep raw `NativeBuzzvil` calls out of the public surface.
- **`android/.../com/buzzvil/BuzzvilModule.kt`** extends the generated `NativeBuzzvilSpec`.
- **`ios/Buzzvil.mm`** + `ios/Buzzvil.h` implement the spec, return `NativeBuzzvilSpecJSI` from `getTurboModule:`; `+moduleName` returns `"Buzzvil"`.

**Sentinel contract** (the key gotcha): codegen understands only a restricted type subset — no optionals, no enums/unions, numbers are `Double`.
So the spec is **primitives-only**, and the JS wrapper encodes "not provided" as sentinels (`gender: ''`, `birthYear: 0`, `routePath: ''`) that **both** native impls must interpret identically.
The full contract is documented at the top of `src/NativeBuzzvil.ts` — read it before touching either native impl; don't duplicate it elsewhere.

### 2. Fabric view `BuzzvilNativeAdView` — in-feed native ad

- **`src/BuzzvilNativeAdViewNativeComponent.ts`** — `codegenNativeComponent('BuzzvilNativeAdView')`. Event payloads are flat primitives (codegen events can't carry nested objects/enums).
- **`src/BuzzvilNativeAdView.native.tsx`** (+ `.tsx` web fallback) — wrapper that maps friendly props and unwraps `e.nativeEvent` for handlers.
- **`android/.../BuzzvilNativeAdView.kt`** (the view) + **`BuzzvilNativeAdViewManager.kt`** (the `SimpleViewManager`). The manager's `getExportedCustomDirectEventTypeConstants` maps native event names to JS prop handlers (`topAdLoaded` → `onAdLoaded`, etc.) — these names must match the spec.
- **`ios/BuzzvilNativeAdView.mm`** + `.h`. Registered in `package.json` → `codegenConfig.ios.components`.

**Sizing gotcha**: under Fabric the view's frame comes from the JS shadow node (`style`), so `src/layout.ts` sizes are applied only as a **default** style.
Without a JS-side height, iOS bounds stay 0 and `onAdLoaded` never fires — a consumer `style` always wins over the default.

### Shared

Codegen identifiers (keep consistent when renaming anything): library name `BuzzvilSpec` (`package.json` → `codegenConfig.name`), native module name `Buzzvil`, Fabric component `BuzzvilNativeAdView`, Java package `com.buzzvil`, JS srcs dir `src`.

Native SDK deps: **iOS** `Buzzvil.podspec` pins `BuzzvilSDK` + `BuzzAdBenefitSDK` `~> 6.7.5`.
**Android** `android/build.gradle` uses `com.buzzvil:buzzvil-bom:6.7.+` + `buzzvil-sdk`; the Buzzvil Maven repo (`dl.buzzvil.com/public/maven`) must be declared in the **consumer's** `settings.gradle` (RNGP runs `FAIL_ON_PROJECT_REPOS`, which rejects module-level `repositories {}`).
Android config: minSdk 24, compile/target SDK 36, Kotlin 2.0.21, Java 17.

The flow when adding a method/prop: declare it in the JS spec → implement in the Kotlin + Obj-C++ impls → rebuild the example app (native changes require a rebuild; JS changes hot-reload).

## Build & packaging

- `react-native-builder-bob` builds `src/` → `lib/` as an ESM module + TypeScript declarations (targets in `package.json` → `react-native-builder-bob`). `tsconfig.build.json` is the build TS config.
- Only the paths in `package.json` → `files` are published (`src`, `lib`, `android`, `ios`, `cpp`, `*.podspec`, `react-native.config.js`). The example app and tests are excluded.
- The `example/` app consumes the library by path (`example/react-native.config.js`), so source changes are picked up live without publishing.

## Conventions

- TypeScript is strict; ESLint uses the flat-config (`eslint.config.mjs`) with the RN community config. Prettier settings live in `package.json` (single quotes, 2-space, ES5 trailing commas).
- RN: functional components + hooks only.
- `docs/notes`, `docs/plans`, `docs/specs` exist as the home for design notes, implementation plans, and SDK-mapping specs — put planning artifacts there rather than scattering them.
- Korean comments and user-facing strings are intentional; commit messages and identifiers in English.
