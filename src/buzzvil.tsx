import type { BuzzvilUser, BenefitHubOptions } from './types';

/**
 * Web fallback. Buzzvil's BuzzBenefit SDKs are mobile-only, so every method
 * throws **at call time** (never at import time — importing must not break the
 * web bundle). The `.native.tsx` counterpart is used on iOS/Android.
 */

const UNSUPPORTED = 'react-native-buzzvil is not supported on web.';

export function initialize(_appId: string, _appSecret?: string): void {
  throw new Error(UNSUPPORTED);
}

export function login(_user: BuzzvilUser): Promise<void> {
  return Promise.reject(new Error(UNSUPPORTED));
}

export function logout(): void {
  throw new Error(UNSUPPORTED);
}

export function isLoggedIn(): Promise<boolean> {
  return Promise.reject(new Error(UNSUPPORTED));
}

export function showBenefitHub(_options: BenefitHubOptions = {}): void {
  throw new Error(UNSUPPORTED);
}
