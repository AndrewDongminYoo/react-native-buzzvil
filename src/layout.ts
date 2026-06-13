/**
 * Default inventory sizes for the Native-ad layout variants, shared by the
 * native and web `BuzzvilNativeAdView` so the box matches on every platform.
 *
 * Under Fabric the component's frame comes from the JS shadow node (the
 * `style`), so the native side's per-size height is only a hint — without a
 * JS-side height iOS bounds stay 0 and `onAdLoaded` never fires. The wrapper
 * therefore applies one of these as a DEFAULT style; a consumer `style` wins.
 */
const LAYOUT_SIZE: Record<string, { width: number; height: number }> = {
  '320x50': { width: 320, height: 50 },
  '320x100': { width: 320, height: 100 },
  '320x130': { width: 320, height: 130 },
  '300x250': { width: 300, height: 250 },
  '320x480': { width: 320, height: 480 },
};

/** Resolve the default size for a layout; unknown/undefined → `300x250`. */
export function sizeForLayout(layout?: string) {
  return LAYOUT_SIZE[layout ?? '300x250'] ?? LAYOUT_SIZE['300x250'];
}
