# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A React Native **Turbo Module** package (`@dongminyu/react-native-buzzvil`) that wraps Buzzvil's
**BuzzBenefit v6** native SDKs so they can be used from a React Native app:

- Android: https://docs.buzzvil.com/docs/buzzbenefit-android/v6/introduction
- iOS: https://docs.buzzvil.com/docs/buzzbenefit-ios/v6/introduction

> **Current state:** the repo is still the unmodified `create-react-native-library` scaffold. The
> only surface that exists is the placeholder `multiply(a, b)` — JS spec, native impls, and the
> example app all reference it. Real Buzzvil work means *replacing* `multiply` with the actual SDK
> bridge, not adding alongside it.

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

CI (`.github/workflows/ci.yml`) runs, as separate jobs: `lint` (lint + typecheck), `test`,
`build-library` (`yarn prepare`), `build-android`, `build-ios`, `build-web`. All must pass.

## Architecture: how the Turbo Module bridge fits together

This is the New Architecture (Fabric/TurboModules) — codegen generates the native interface from the
TS spec, so the **TS spec is the source of truth**. The four pieces must stay in sync:

1. **`src/NativeBuzzvil.ts`** — the codegen spec. `interface Spec extends TurboModule` declares the
   native methods. `TurboModuleRegistry.getEnforcing<Spec>('Buzzvil')` binds to the native module
   named `Buzzvil`. Codegen only understands a restricted type subset (no rich enums/unions; numbers
   are `Double`, etc.) — design the bridge API around that constraint.
2. **`src/index.tsx`** — public JS API re-exported to consumers. Keep raw `NativeBuzzvil` calls out
   of the public surface; wrap them in friendly functions (the `multiply.tsx` / `multiply.native.tsx`
   split shows the web-vs-native pattern — `.native.tsx` calls the native module, `.tsx` is the web
   fallback).
3. **`android/src/main/java/com/buzzvil/BuzzvilModule.kt`** — extends the generated
   `NativeBuzzvilSpec`. Java package is `com.buzzvil` (set in `package.json` → `codegenConfig.android`).
   `BuzzvilPackage.kt` registers the module. Android config in `android/build.gradle`
   (minSdk 24, compileSdk/targetSdk 36, Kotlin 2.0.21). Buzzvil Android SDK Maven deps go here.
4. **`ios/Buzzvil.mm`** (Obj-C++) + `ios/Buzzvil.h` — implements the spec and returns the generated
   `NativeBuzzvilSpecJSI` from `getTurboModule:`. `+moduleName` must return `"Buzzvil"`. Buzzvil iOS
   SDK pod deps go in `Buzzvil.podspec`.

Codegen identifiers (keep consistent when renaming anything): spec/library name `BuzzvilSpec`
(`package.json` → `codegenConfig.name`), native module name `Buzzvil`, JS srcs dir `src`.

The flow when adding a method: declare it in `NativeBuzzvil.ts` → implement in `BuzzvilModule.kt`
and `Buzzvil.mm` → rebuild the example app (native changes require a rebuild; JS changes hot-reload).

## Build & packaging

- `react-native-builder-bob` builds `src/` → `lib/` as an ESM module + TypeScript declarations
  (targets in `package.json` → `react-native-builder-bob`). `tsconfig.build.json` is the build TS config.
- Only the paths in `package.json` → `files` are published (`src`, `lib`, `android`, `ios`, `cpp`,
  `*.podspec`, `react-native.config.js`). The example app and tests are excluded.
- The `example/` app consumes the library by path (`example/react-native.config.js`), so source
  changes are picked up live without publishing.

## Conventions

- TypeScript is strict; ESLint uses the flat-config (`eslint.config.mjs`) with the RN community config.
  Prettier settings live in `package.json` (single quotes, 2-space, ES5 trailing commas).
- RN: functional components + hooks only.
- `docs/notes`, `docs/plans`, `docs/specs` exist as the home for design notes, implementation plans,
  and SDK-mapping specs — put planning artifacts there rather than scattering them.
- Korean comments and user-facing strings are intentional; commit messages and identifiers in English.
