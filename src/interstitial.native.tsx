import Buzzvil from './NativeBuzzvil';
import type { InterstitialType } from './types';

/**
 * Native (iOS/Android) implementation of the public Interstitial API. Wraps the
 * primitive-only native spec (`./NativeBuzzvil`) in friendly functions; raw
 * `NativeBuzzvil` calls stay out of the public surface.
 *
 * The native side holds one interstitial instance per `unitId` (design
 * Decision 1), so `loadInterstitial` then `showInterstitial` operate on the
 * same placement.
 */

/**
 * Load an interstitial for `unitId`. Resolves once loaded, rejects on
 * load failure.
 *
 * @param type `'dialog'` (default) or `'bottomSheet'`.
 */
export function loadInterstitial(
  unitId: string,
  type: InterstitialType = 'dialog'
): Promise<void> {
  return Buzzvil.loadInterstitial(unitId, type);
}

/** Present the interstitial previously loaded for `unitId`. */
export function showInterstitial(unitId: string): void {
  Buzzvil.showInterstitial(unitId);
}

/**
 * Subscribe to the "interstitial closed" event for a specific `unitId`. The
 * native emitter is module-wide (one event for all placements), so the
 * callback is gated on `event.unitId === unitId` — listeners for other units
 * never fire. Returns a handle whose `remove()` unsubscribes.
 */
export function addInterstitialClosedListener(
  unitId: string,
  cb: () => void
): { remove(): void } {
  const subscription = Buzzvil.onInterstitialClosed((event) => {
    if (event.unitId === unitId) {
      cb();
    }
  });
  return {
    remove() {
      subscription.remove();
    },
  };
}
