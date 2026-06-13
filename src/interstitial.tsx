import type { InterstitialType } from './types';

/**
 * Web fallback. Buzzvil's interstitial is mobile-only, so the imperative
 * methods fail **at call time** (never at import time). `.native.tsx` is used
 * on iOS/Android.
 */

const UNSUPPORTED = 'react-native-buzzvil is not supported on web.';

export function loadInterstitial(
  _unitId: string,
  _type: InterstitialType = 'dialog'
): Promise<void> {
  return Promise.reject(new Error(UNSUPPORTED));
}

export function showInterstitial(_unitId: string): void {
  throw new Error(UNSUPPORTED);
}

/** No-op on web: the close event never fires, so `remove()` does nothing. */
export function addInterstitialClosedListener(
  _unitId: string,
  _cb: () => void
): { remove(): void } {
  return {
    remove() {},
  };
}
