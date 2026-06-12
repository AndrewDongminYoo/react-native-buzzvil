import { View } from 'react-native';
import { sizeForLayout } from './layout';
import type { BuzzvilNativeAdViewProps } from './types';

export function BuzzvilNativeAdView({
  layout,
  style,
}: BuzzvilNativeAdViewProps) {
  // Buzzvil native ads are not available on web; render nothing visible, but
  // reserve the same box as native (consumer `style` overrides the default).
  return <View style={[sizeForLayout(layout), style]} />;
}
