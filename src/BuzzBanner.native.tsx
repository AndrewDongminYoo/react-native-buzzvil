import NativeComponent from './BuzzBannerViewNativeComponent';
import type { BuzzBannerProps } from './types';

export function toNativeBannerProps(props: BuzzBannerProps) {
  const { onLoaded, onFailed, onClicked, ...rest } = props;
  return {
    ...rest,
    // No payload — pass the friendly handlers straight through (they ignore the
    // native event arg). Only onFailed carries a payload worth unwrapping.
    onLoaded,
    onFailed: onFailed
      ? (e: { nativeEvent: { code: string; message: string } }) =>
          onFailed(e.nativeEvent)
      : undefined,
    onClicked,
  };
}

export function BuzzBanner(props: BuzzBannerProps) {
  const native = toNativeBannerProps(props);
  return <NativeComponent {...(native as any)} style={props.style} />;
}
