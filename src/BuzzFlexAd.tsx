import { View } from 'react-native';
import type { BuzzFlexAdProps } from './types';

export function BuzzFlexAd({ style }: BuzzFlexAdProps) {
  // Buzzvil FlexAds are not available on web; render an inert box that the
  // consumer's `style` can size.
  return <View style={style} />;
}
