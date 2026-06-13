import {
  codegenNativeComponent,
  type ColorValue,
  type ViewProps,
} from 'react-native';
import type { CodegenTypes } from 'react-native';

// Flat primitive payloads — codegen events cannot carry nested objects/enums.
type FailedEvent = Readonly<{ code: string; message: string }>;

export interface NativeProps extends ViewProps {
  unitId: string;
  primaryColor?: ColorValue;
  onLoaded?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onFailed?: CodegenTypes.DirectEventHandler<FailedEvent>;
  onClicked?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>('BuzzFlexAdView');
