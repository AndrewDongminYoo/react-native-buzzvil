import { codegenNativeComponent, type ViewProps } from 'react-native';
import type { CodegenTypes } from 'react-native';

// Flat primitive payloads — codegen events cannot carry nested objects/enums.
type AdLoadedEvent = Readonly<{
  width: CodegenTypes.Double;
  height: CodegenTypes.Double;
}>;
type AdFailedEvent = Readonly<{ code: string; message: string }>;
type RewardedEvent = Readonly<{ success: boolean }>;

export interface NativeProps extends ViewProps {
  unitId: string;
  layout?: string; // friendly union + default live in the JS wrapper; codegen sees a plain string
  onAdLoaded?: CodegenTypes.DirectEventHandler<AdLoadedEvent>;
  onAdFailed?: CodegenTypes.DirectEventHandler<AdFailedEvent>;
  onAdClicked?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onImpressed?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onRewarded?: CodegenTypes.DirectEventHandler<RewardedEvent>;
}

export default codegenNativeComponent<NativeProps>('BuzzvilNativeAdView');
