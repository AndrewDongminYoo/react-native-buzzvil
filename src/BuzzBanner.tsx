import { View } from 'react-native';
import type { BuzzBannerProps } from './types';

export function BuzzBanner({ style }: BuzzBannerProps) {
  // Buzzvil banners are not available on web; render an inert box that the
  // consumer's `style` can size.
  return <View style={style} />;
}
