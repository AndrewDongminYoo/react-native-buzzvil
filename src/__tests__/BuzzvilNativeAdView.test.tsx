import { jest, describe, it, expect } from '@jest/globals';

jest.mock('../BuzzvilNativeAdViewNativeComponent', () => ({
  __esModule: true,
  default: 'BuzzvilNativeAdView',
}));

import { sizeForLayout, toNativeProps } from '../BuzzvilNativeAdView.native';

describe('sizeForLayout — layout→default inventory size', () => {
  it('returns each known layout’s pixel size', () => {
    expect(sizeForLayout('320x50')).toEqual({ width: 320, height: 50 });
    expect(sizeForLayout('320x100')).toEqual({ width: 320, height: 100 });
    expect(sizeForLayout('320x130')).toEqual({ width: 320, height: 130 });
    expect(sizeForLayout('300x250')).toEqual({ width: 300, height: 250 });
    expect(sizeForLayout('320x480')).toEqual({ width: 320, height: 480 });
  });
  it('falls back to 300x250 when layout is undefined', () => {
    expect(sizeForLayout(undefined)).toEqual({ width: 300, height: 250 });
  });
  it('falls back to 300x250 for an unknown layout', () => {
    expect(sizeForLayout('999x999')).toEqual({ width: 300, height: 250 });
  });
});

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
