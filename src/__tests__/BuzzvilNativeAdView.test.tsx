import { jest, describe, it, expect } from '@jest/globals';

jest.mock('../BuzzvilNativeAdViewNativeComponent', () => ({
  __esModule: true,
  default: 'BuzzvilNativeAdView',
}));

import { toNativeProps } from '../BuzzvilNativeAdView.native';

describe('toNativeProps — friendly→native mapping', () => {
  it('defaults layout to 300x250 when omitted', () => {
    expect(toNativeProps({ unitId: 'u1' }).layout).toBe('300x250');
  });
  it('passes through an explicit layout', () => {
    expect(toNativeProps({ unitId: 'u1', layout: '320x50' }).layout).toBe(
      '320x50'
    );
  });
  it('unwraps onAdLoaded nativeEvent to friendly args', () => {
    const onAdLoaded = jest.fn();
    toNativeProps({ unitId: 'u1', onAdLoaded }).onAdLoaded?.({
      nativeEvent: { width: 300, height: 250 },
    } as any);
    expect(onAdLoaded).toHaveBeenCalledWith({ width: 300, height: 250 });
  });
  it('unwraps onAdFailed nativeEvent', () => {
    const onAdFailed = jest.fn();
    toNativeProps({ unitId: 'u1', onAdFailed }).onAdFailed?.({
      nativeEvent: { code: 'E1', message: 'boom' },
    } as any);
    expect(onAdFailed).toHaveBeenCalledWith({ code: 'E1', message: 'boom' });
  });
  it('unwraps onRewarded nativeEvent', () => {
    const onRewarded = jest.fn();
    toNativeProps({ unitId: 'u1', onRewarded }).onRewarded?.({
      nativeEvent: { success: true },
    } as any);
    expect(onRewarded).toHaveBeenCalledWith({ success: true });
  });
  it('leaves omitted handlers undefined', () => {
    expect(toNativeProps({ unitId: 'u1' }).onAdClicked).toBeUndefined();
  });
});
