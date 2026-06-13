import { jest, describe, it, expect } from '@jest/globals';

jest.mock('../BuzzFlexAdViewNativeComponent', () => ({
  __esModule: true,
  default: 'BuzzFlexAdView',
}));

import { toNativeFlexAdProps } from '../BuzzFlexAd.native';

describe('toNativeFlexAdProps — friendly→native mapping', () => {
  it('passes unitId through', () => {
    expect(toNativeFlexAdProps({ unitId: 'u1' }).unitId).toBe('u1');
  });
  it('passes primaryColor through', () => {
    expect(
      toNativeFlexAdProps({ unitId: 'u1', primaryColor: '#FF0000' })
        .primaryColor
    ).toBe('#FF0000');
  });
  it('unwraps onFailed nativeEvent to friendly args', () => {
    const onFailed = jest.fn();
    toNativeFlexAdProps({
      unitId: 'u1',
      onFailed,
    }).onFailed?.({
      nativeEvent: { code: 'E1', message: 'boom' },
    } as any);
    expect(onFailed).toHaveBeenCalledWith({ code: 'E1', message: 'boom' });
  });
  it('passes onLoaded straight through (no payload)', () => {
    const onLoaded = jest.fn();
    expect(toNativeFlexAdProps({ unitId: 'u1', onLoaded }).onLoaded).toBe(
      onLoaded
    );
  });
  it('passes onClicked straight through (no payload)', () => {
    const onClicked = jest.fn();
    expect(toNativeFlexAdProps({ unitId: 'u1', onClicked }).onClicked).toBe(
      onClicked
    );
  });
  it('leaves omitted handlers undefined', () => {
    const native = toNativeFlexAdProps({ unitId: 'u1' });
    expect(native.onLoaded).toBeUndefined();
    expect(native.onFailed).toBeUndefined();
    expect(native.onClicked).toBeUndefined();
  });
});
