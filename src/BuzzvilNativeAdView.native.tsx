import NativeComponent from './BuzzvilNativeAdViewNativeComponent';
import type { BuzzvilNativeAdViewProps } from './types';

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
  return <NativeComponent {...(toNativeProps(props) as any)} />;
}
