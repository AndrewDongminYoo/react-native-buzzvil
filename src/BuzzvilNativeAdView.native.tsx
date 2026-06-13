import NativeComponent from './BuzzvilNativeAdViewNativeComponent';
import { sizeForLayout } from './layout';
import type { BuzzvilNativeAdViewProps } from './types';

export { sizeForLayout };

const DEFAULT_LAYOUT = '300x250';

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
    // No payload — pass the friendly handler straight through (it ignores the
    // native event arg). Avoids an empty wrapper that could mislead a future
    // contributor copying the pattern for a payload-carrying event.
    onAdClicked,
    onImpressed,
    onRewarded: onRewarded
      ? (e: { nativeEvent: { success: boolean } }) => onRewarded(e.nativeEvent)
      : undefined,
  };
}

export function BuzzvilNativeAdView(props: BuzzvilNativeAdViewProps) {
  const native = toNativeProps(props);
  const size = sizeForLayout(props.layout);
  // Apply the inventory size as a DEFAULT style; the consumer's `style` is
  // last in the array, so it overrides. `style` is set once here (the explicit
  // prop wins over the one carried in `native`'s spread).
  return <NativeComponent {...(native as any)} style={[size, props.style]} />;
}
