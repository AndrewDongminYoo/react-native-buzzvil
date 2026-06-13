import { codegenNativeComponent, type ViewProps } from 'react-native';
import type { CodegenTypes } from 'react-native';

// Flat primitive payloads — codegen events cannot carry nested objects/enums.
type FailedEvent = Readonly<{ code: string; message: string }>;

export interface NativeProps extends ViewProps {
  placementId: string;
  size: string; // 'W320XH50' | 'W320XH100' — friendly union lives in the wrapper
  onLoaded?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onFailed?: CodegenTypes.DirectEventHandler<FailedEvent>;
  onClicked?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>('BuzzBannerView');
