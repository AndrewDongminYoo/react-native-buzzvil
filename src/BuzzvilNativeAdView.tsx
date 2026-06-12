import { View } from 'react-native';
import type { BuzzvilNativeAdViewProps } from './types';

export function BuzzvilNativeAdView({ style }: BuzzvilNativeAdViewProps) {
  // Buzzvil native ads are not available on web; render nothing visible.
  return <View style={style} />;
}
