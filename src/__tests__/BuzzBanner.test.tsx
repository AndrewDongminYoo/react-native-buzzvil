import { jest, describe, it, expect } from '@jest/globals';

jest.mock('../BuzzBannerViewNativeComponent', () => ({
  __esModule: true,
  default: 'BuzzBannerView',
}));

import { toNativeBannerProps } from '../BuzzBanner.native';

describe('toNativeBannerProps — friendly→native mapping', () => {
  it('passes placementId through', () => {
    expect(
      toNativeBannerProps({ placementId: 'p1', size: 'W320XH50' }).placementId
    ).toBe('p1');
  });
  it('passes size through', () => {
    expect(
      toNativeBannerProps({ placementId: 'p1', size: 'W320XH100' }).size
    ).toBe('W320XH100');
  });
  it('unwraps onFailed nativeEvent to friendly args', () => {
    const onFailed = jest.fn();
    toNativeBannerProps({
      placementId: 'p1',
      size: 'W320XH50',
      onFailed,
    }).onFailed?.({
      nativeEvent: { code: 'E1', message: 'boom' },
    } as any);
    expect(onFailed).toHaveBeenCalledWith({ code: 'E1', message: 'boom' });
  });
  it('passes onLoaded straight through (no payload)', () => {
    const onLoaded = jest.fn();
    expect(
      toNativeBannerProps({ placementId: 'p1', size: 'W320XH50', onLoaded })
        .onLoaded
    ).toBe(onLoaded);
  });
  it('passes onClicked straight through (no payload)', () => {
    const onClicked = jest.fn();
    expect(
      toNativeBannerProps({ placementId: 'p1', size: 'W320XH50', onClicked })
        .onClicked
    ).toBe(onClicked);
  });
  it('leaves omitted handlers undefined', () => {
    const native = toNativeBannerProps({ placementId: 'p1', size: 'W320XH50' });
    expect(native.onLoaded).toBeUndefined();
    expect(native.onFailed).toBeUndefined();
    expect(native.onClicked).toBeUndefined();
  });
});
