import NativeComponent from './BuzzFlexAdViewNativeComponent';
import type { BuzzFlexAdProps } from './types';

export function toNativeFlexAdProps(props: BuzzFlexAdProps) {
  const { onLoaded, onFailed, onClicked, ...rest } = props;
  return {
    ...rest,
    // No payload — pass the friendly handlers straight through (they ignore
    // the native event arg). Only onFailed carries a payload worth unwrapping.
    onLoaded,
    onFailed: onFailed
      ? (e: { nativeEvent: { code: string; message: string } }) =>
          onFailed(e.nativeEvent)
      : undefined,
    onClicked,
  };
}

export function BuzzFlexAd(props: BuzzFlexAdProps) {
  const native = toNativeFlexAdProps(props);
  return <NativeComponent {...(native as any)} style={props.style} />;
}
